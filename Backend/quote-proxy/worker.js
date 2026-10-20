// Dipwise quote proxy: a Cloudflare Worker between the app and the market data vendor (Twelve Data).
//
// Why it keeps costs low:
// - The vendor key lives here, never in the app.
// - Every answer is cached at Cloudflare's edge per symbol, so 10 or 10,000 users watching NVDA cost the same
//   vendor calls. Vendor usage grows with the number of distinct stocks, not with users.
// - Free members get prices 15 minutes late, computed from the same cached 5-minute bars, so they add no vendor
//   calls at all. Only Pro members ever trigger the short-lived real-time price request.
//
// Endpoints (all GET, JSON, dates in seconds since 1970, matching the app's Quote type):
//   /quote?symbol=NVDA&delay=900&fiveYears=0
//   /intraday?symbol=NVDA&delay=900
//   /search?q=nvidia
//   /fx?from=EUR&to=USD

const VENDOR = "https://api.twelvedata.com";

// How long each kind of answer stays cached, in seconds.
const TTL = {
  daily: 60 * 60,       // daily closes: hourly is plenty
  weekly: 6 * 60 * 60,  // five-year weekly history
  intraday: 5 * 60,     // 5-minute bars: one refresh per bar
  live: 30,             // the real-time price, Pro only
  meta: 24 * 60 * 60,   // name, currency, exchange
  dividends: 24 * 60 * 60,
  search: 24 * 60 * 60,
  fx: 60 * 60,
};

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    try {
      switch (url.pathname) {
        case "/quote": return json(await quote(url.searchParams, env, ctx));
        case "/intraday": return json(await intraday(url.searchParams, env, ctx));
        case "/search": return json(await search(url.searchParams, env, ctx), TTL.search);
        case "/fx": return json(await fx(url.searchParams, env, ctx), TTL.fx);
        default: return new Response("Not found", { status: 404 });
      }
    } catch (error) {
      return new Response(JSON.stringify({ error: String(error.message || error) }), { status: 502, headers: { "content-type": "application/json" } });
    }
  },
};

// MARK: - Endpoints

async function quote(params, env, ctx) {
  const symbol = params.get("symbol");
  if (!symbol) throw new Error("symbol required");
  const vendorSymbol = toVendor(symbol);
  const fiveYears = params.get("fiveYears") === "1";
  const delay = Math.max(0, Number(params.get("delay") || 0));

  const [series, meta, dividends] = await Promise.all([
    vendor("time_series", { symbol: vendorSymbol, interval: fiveYears ? "1week" : "1day", outputsize: fiveYears ? 262 : 260, timezone: "UTC" },
           fiveYears ? TTL.weekly : TTL.daily, env, ctx),
    vendor("quote", { symbol: vendorSymbol }, TTL.meta, env, ctx).catch(() => ({})),
    vendor("dividends", { symbol: vendorSymbol, range: "1y" }, TTL.dividends, env, ctx).catch(() => ({ dividends: [] })),
  ]);
  const bars = (series.values || []).slice().reverse();
  if (bars.length === 0) throw new Error("no data");

  const closes = bars.map((bar) => Number(bar.close));
  const dates = bars.map((bar) => seconds(bar.datetime));
  const opens = bars.map((bar) => Number(bar.open));
  const volumes = bars.map((bar) => Number(bar.volume || 0));

  // Today's price: real-time for Pro, the bar from `delay` ago for everyone else.
  let price = closes[closes.length - 1];
  let appliedDelay = null;
  if (!fiveYears) {
    if (delay === 0) {
      const live = await vendor("price", { symbol: vendorSymbol }, TTL.live, env, ctx).catch(() => null);
      if (live && live.price) price = Number(live.price);
    } else {
      const intra = await intradayBars(vendorSymbol, env, ctx).catch(() => []);
      const cutoff = Date.now() / 1000 - delay;
      const older = intra.filter((bar) => bar.date <= cutoff);
      if (older.length) {
        price = older[older.length - 1].close;
        appliedDelay = delay;
      }
    }
    closes[closes.length - 1] = price;
  }

  const previousClose = closes.length >= 2 ? closes[closes.length - 2] : Number(meta.previous_close || price);
  return {
    symbol,
    name: meta.name || symbol,
    currency: series.meta?.currency || meta.currency || "USD",
    exchange: series.meta?.exchange || meta.exchange || "",
    assetType: assetType(series.meta?.type || meta.type || ""),
    price,
    previousClose,
    closes,
    dates,
    dividends: (dividends.dividends || []).map((d) => ({ date: seconds(d.ex_date || d.payment_date), amount: Number(d.amount) })),
    opens,
    volumes,
    updatedAt: Math.floor(Date.now() / 1000),
    delay: appliedDelay,
  };
}

async function intraday(params, env, ctx) {
  const symbol = params.get("symbol");
  if (!symbol) throw new Error("symbol required");
  const delay = Math.max(0, Number(params.get("delay") || 0));
  let bars = await intradayBars(toVendor(symbol), env, ctx);
  if (delay > 0) {
    const cutoff = Date.now() / 1000 - delay;
    bars = bars.filter((bar) => bar.date <= cutoff);
  }
  return { values: bars.map((bar) => bar.close), dates: bars.map((bar) => bar.date) };
}

async function search(params, env, ctx) {
  const text = (params.get("q") || "").trim();
  if (!text) return [];
  const result = await vendor("symbol_search", { symbol: text, outputsize: 12 }, TTL.search, env, ctx);
  const supported = new Set(["Common Stock", "ETF", "Digital Currency", "Index", "Mutual Fund"]);
  return (result.data || [])
    .filter((item) => supported.has(item.instrument_type))
    .map((item) => ({ symbol: fromVendor(item.symbol, item.exchange), name: item.instrument_name, exchange: item.exchange, type: item.instrument_type }));
}

async function fx(params, env, ctx) {
  const from = params.get("from"), to = params.get("to");
  if (!from || !to) throw new Error("from and to required");
  const result = await vendor("exchange_rate", { symbol: `${from}/${to}` }, TTL.fx, env, ctx);
  return { rate: Number(result.rate) };
}

// MARK: - Vendor access with edge caching

async function intradayBars(vendorSymbol, env, ctx) {
  const series = await vendor("time_series", { symbol: vendorSymbol, interval: "5min", outputsize: 100, timezone: "UTC" }, TTL.intraday, env, ctx);
  return (series.values || []).slice().reverse().map((bar) => ({ date: seconds(bar.datetime), close: Number(bar.close) }));
}

/// One vendor call, cached at the edge for `ttl` seconds. The key is never part of the cache key.
async function vendor(path, query, ttl, env, ctx) {
  const cacheURL = new URL(`https://cache.dipwise/${path}`);
  for (const [key, value] of Object.entries(query)) cacheURL.searchParams.set(key, value);
  const cacheKey = new Request(cacheURL.toString());
  const cache = caches.default;
  const hit = await cache.match(cacheKey);
  if (hit) return hit.json();

  const vendorURL = new URL(`${VENDOR}/${path}`);
  for (const [key, value] of Object.entries(query)) vendorURL.searchParams.set(key, value);
  vendorURL.searchParams.set("apikey", env.TWELVE_DATA_KEY);
  const response = await fetch(vendorURL);
  const body = await response.json();
  if (!response.ok || body.status === "error") throw new Error(body.message || `vendor ${response.status}`);

  ctx.waitUntil(cache.put(cacheKey, new Response(JSON.stringify(body), { headers: { "cache-control": `public, max-age=${ttl}` } })));
  return body;
}

// MARK: - Helpers

/// The app uses Yahoo-style symbols; Twelve Data has its own.
function toVendor(symbol) {
  if (symbol === "^GSPC") return "SPX";
  if (symbol === "^IXIC") return "IXIC";
  if (/^[A-Z]+-USD$/.test(symbol)) return symbol.replace("-", "/");
  const suffixes = { ".L": ":LSE", ".DE": ":XETR", ".PA": ":XPAR", ".AS": ":XAMS", ".MI": ":XMIL", ".MC": ":XMAD", ".SW": ":XSWX", ".T": ":XTKS", ".KS": ":XKRX", ".TO": ":XTSE" };
  for (const [suffix, mic] of Object.entries(suffixes)) {
    if (symbol.endsWith(suffix)) return symbol.slice(0, -suffix.length) + mic;
  }
  return symbol;
}

function fromVendor(symbol, exchange) {
  const suffixes = { LSE: ".L", XETR: ".DE", Euronext: ".PA", MTA: ".MI", BME: ".MC", SIX: ".SW", TSE: ".T", KRX: ".KS", TSX: ".TO" };
  if (symbol.includes("/")) return symbol.replace("/", "-");
  const suffix = suffixes[exchange];
  return suffix ? symbol + suffix : symbol;
}

function assetType(type) {
  if (/ETF/i.test(type)) return "ETF";
  if (/Digital Currency|Crypto/i.test(type)) return "CRYPTOCURRENCY";
  if (/Index/i.test(type)) return "INDEX";
  if (/Fund/i.test(type)) return "MUTUALFUND";
  return "EQUITY";
}

/// "2026-10-13" or "2026-10-13 15:45:00" (UTC) → seconds since 1970.
function seconds(text) {
  if (!text) return Math.floor(Date.now() / 1000);
  const iso = text.length <= 10 ? `${text}T20:00:00Z` : `${text.replace(" ", "T")}Z`;
  return Math.floor(Date.parse(iso) / 1000);
}

function json(body, maxAge = 0) {
  return new Response(JSON.stringify(body), {
    headers: { "content-type": "application/json", "cache-control": maxAge ? `public, max-age=${maxAge}` : "no-store" },
  });
}
