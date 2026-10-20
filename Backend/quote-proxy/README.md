# Dipwise quote proxy

A Cloudflare Worker between the app and the market data vendor. It keeps the vendor key off devices and caches every stock once for all users, so data costs scale with the number of distinct stocks, not with users. Free members get prices 15 minutes late (served from the same cached bars at no extra cost); Pro members get real-time.

## Set up (about 15 minutes)

1. **Data vendor.** Create a [Twelve Data](https://twelvedata.com/pricing) account. Pick a plan that allows **external display** (showing data to your app's users). The free and personal tiers don't. Ask them for a quote for "15-minute delayed display to a consumer app, real-time for subscribers". Copy your API key.
2. **Cloudflare.** Create a free account at [dash.cloudflare.com](https://dash.cloudflare.com), then in Terminal:
   ```
   cd Backend/quote-proxy
   npx wrangler login
   npx wrangler secret put TWELVE_DATA_KEY   # paste the key
   npx wrangler deploy
   ```
   Wrangler prints your URL, such as `https://dipwise-quotes.yourname.workers.dev`.
3. **App.** Set `MarketData.proxyURL` in `Shared/MarketData.swift` to that URL and rebuild. Every quote, chart, search, and exchange rate then goes through the proxy.

Check it in a browser: `https://…workers.dev/quote?symbol=AAPL&delay=900`.

## What it costs

| Piece | Cost |
|---|---|
| Cloudflare Workers | Free up to 100,000 requests a day; $5 a month beyond that (10 million requests) |
| Twelve Data | Depends on the display license; budget roughly $150–500 a month at launch, confirmed in writing |
| Real-time for Pro | Exchanges charge display fees per real-time user. Delayed data has no per-user fee, which is why free users stay delayed |

Vendor calls per stock: daily history once an hour, 5-minute bars once every 5 minutes while the market is open, names and dividends once a day, and a 30-second live price only when a Pro member asks. Five hundred popular stocks is about 40,000 vendor calls a trading day, whatever the number of users.

## Notes

- The app sends the delay it wants. A determined user could ask for real-time without paying; once revenue justifies it, verify the StoreKit signed transaction here before serving `delay=0`.
- Symbols follow Yahoo style in the app (`^GSPC`, `BTC-USD`, `SAP.DE`); `toVendor` maps the common ones. Add suffixes there if you support more exchanges.
- Development builds without a proxy read Yahoo Finance directly. That's fine for testing but not licensed for an App Store app, so set the proxy before release.
