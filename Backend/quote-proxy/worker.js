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
//   POST /devices   a device's push token and its price-level alerts, checked every minute by the cron below
//
// Instant alerts: a cron trigger runs every minute while the market is open. It reads every device's alerts from
// KV, prices each symbol once (15 minutes delayed, from the same cached bars), and sends an APNs push the moment a
// price crosses an alert's level, so nobody waits for iOS to wake the app.

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
  async scheduled(event, env, ctx) {
    ctx.waitUntil(checkAlerts(env, ctx));
  },

  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    try {
      if (url.pathname === "/devices" && request.method === "POST") return json(await registerDevice(request, env));
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

// MARK: - Instant alerts

const DELAY = 15 * 60;

/// Stores a device's alerts, keeping when each one last fired so a re-sync doesn't fire it again.
async function registerDevice(request, env) {
  const body = await request.json();
  if (!body.token || !Array.isArray(body.alerts)) throw new Error("token and alerts required");
  const key = `device:${body.token}`;
  const previous = JSON.parse((await env.DEVICES.get(key)) || "{}");
  const fired = previous.fired || {};
  const ids = new Set(body.alerts.map((alert) => alert.id));
  for (const id of Object.keys(fired)) if (!ids.has(id)) delete fired[id];
  if (body.alerts.length === 0) {
    await env.DEVICES.delete(key);
    return { ok: true, alerts: 0 };
  }
  await env.DEVICES.put(key, JSON.stringify({
    token: body.token,
    environment: body.environment === "production" ? "production" : "sandbox",
    locale: body.locale || "en-US",
    alerts: body.alerts.slice(0, 200),
    fired,
  }));
  return { ok: true, alerts: body.alerts.length };
}

/// Every minute while US prices (15 minutes late) are moving: price each symbol once, push every crossed alert.
async function checkAlerts(env, ctx) {
  if (!marketIsLive(new Date(Date.now() - DELAY * 1000))) return;
  const devices = [];
  let cursor;
  do {
    const page = await env.DEVICES.list({ prefix: "device:", cursor });
    for (const entry of page.keys) {
      const device = JSON.parse((await env.DEVICES.get(entry.name)) || "null");
      if (device) devices.push(device);
    }
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);

  const symbols = [...new Set(devices.flatMap((device) => device.alerts.map((alert) => alert.symbol)))];
  const prices = {};
  await Promise.all(symbols.map(async (symbol) => {
    const bars = await intradayBars(toVendor(symbol), env, ctx).catch(() => []);
    const cutoff = Date.now() / 1000 - DELAY;
    const older = bars.filter((bar) => bar.date <= cutoff);
    if (older.length) prices[symbol] = older[older.length - 1].close;
  }));

  const day = 20 * 60 * 60 * 1000;
  for (const device of devices) {
    let changed = false;
    for (const alert of device.alerts) {
      const price = prices[alert.symbol];
      if (price === undefined) continue;
      const crossed = alert.below ? price <= alert.level : price >= alert.level;
      const last = device.fired[alert.id] || 0;
      if (!crossed || Date.now() - last < day) continue;
      const formatted = new Intl.NumberFormat(device.locale.replace("_", "-"), { style: "currency", currency: alert.currency || "USD" }).format(price);
      const status = await sendPush(env, device, {
        aps: { alert: { title: alert.title, body: alert.body.replace("{price}", formatted) }, sound: "default", "thread-id": alert.symbol },
        symbol: alert.symbol,
        alertID: alert.id,
      });
      if (status === 410) {
        await env.DEVICES.delete(`device:${device.token}`);
        changed = false;
        break;
      }
      if (status === 200) {
        device.fired[alert.id] = Date.now();
        changed = true;
      }
    }
    if (changed) await env.DEVICES.put(`device:${device.token}`, JSON.stringify(device));
  }
}

/// Regular US hours, Monday to Friday, in New York time.
function marketIsLive(date) {
  const parts = Object.fromEntries(new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York", weekday: "short", hour: "numeric", minute: "numeric", hour12: false,
  }).formatToParts(date).map((part) => [part.type, part.value]));
  if (parts.weekday === "Sat" || parts.weekday === "Sun") return false;
  const minutes = Number(parts.hour) * 60 + Number(parts.minute);
  return minutes >= 9 * 60 + 30 && minutes <= 16 * 60;
}

// MARK: - APNs

let cachedToken = null;

/// An ES256 provider token, reused for 50 minutes as Apple asks.
async function providerToken(env) {
  if (cachedToken && Date.now() - cachedToken.issued < 50 * 60 * 1000) return cachedToken.value;
  const pem = env.APNS_KEY.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));
  const key = await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const issued = Math.floor(Date.now() / 1000);
  const encode = (object) => base64url(new TextEncoder().encode(JSON.stringify(object)));
  const unsigned = `${encode({ alg: "ES256", kid: env.APNS_KEY_ID })}.${encode({ iss: env.APNS_TEAM_ID, iat: issued })}`;
  const signature = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(unsigned));
  cachedToken = { value: `${unsigned}.${base64url(new Uint8Array(signature))}`, issued: Date.now() };
  return cachedToken.value;
}

async function sendPush(env, device, payload) {
  const host = device.environment === "production" ? "https://api.push.apple.com" : "https://api.sandbox.push.apple.com";
  const response = await fetch(`${host}/3/device/${device.token}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerToken(env)}`,
      "apns-topic": env.BUNDLE_ID,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload),
  });
  return response.status;
}

function base64url(bytes) {
  let text = "";
  for (const byte of bytes) text += String.fromCharCode(byte);
  return btoa(text).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
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
