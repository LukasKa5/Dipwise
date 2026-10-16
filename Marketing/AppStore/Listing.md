# Dipwise — App Store listing (English, U.S.)

Copy each field into App Store Connect → your app → the version page. Every field is within Apple's limits.

## App name (27/30)
Dipwise: Buy the Dip Alerts

## Subtitle (27/30)
Stock price zones & widgets

## Keywords (97/100)
stock,price,portfolio,tracker,watchlist,dividend,rsi,invest,market,etf,crypto,signal,widget,trade

Words already in the name and subtitle (dip, alerts, buy, zones, widgets) are indexed automatically, so they aren't repeated here.

## Promotional text (143/170)
Buy the dip with a plan. Draw your buy zone and Dippy taps you the second a stock gets there. Widgets, Apple Watch, and broker import included.

## Description
Buy the dip. Calmly.

Dipwise turns "I'd buy it if it dropped" into a plan that watches itself. Draw the price range where you'd happily buy, and the range where you'd take profit. Dippy, your stock-watching owl, keeps an eye on the market day and night and taps you the moment a stock gets there.

DRAW YOUR ZONES
• Drag two handles on a real chart to set a buy zone or a sell zone
• See where the crowd plans to buy, right on the same chart
• Know your odds: how likely each plan is to trigger in the next 30 or 90 days

NEVER MISS YOUR MOMENT
• An alert the second a stock enters your zone, with your plan inside
• A gentle heads-up when a stock gets close
• Every plan in one place: buy zone, sell zone, and smart alerts set together

27 SMART ALERTS, IN PLAIN ENGLISH
• Sharp drops, new 52-week lows, and big daily moves
• Moving averages, golden crosses, and death crosses
• RSI, MACD, and Bollinger Bands
• Trailing stops, stop losses, profit targets, and back-to-break-even
• Dividend alerts
Every alert comes with a one-line explanation from Dippy, so you always know what it does.

YOUR PORTFOLIO, IN ONE CALM PLACE
• Import positions from Robinhood, Fidelity, Charles Schwab, Vanguard, E*TRADE, Interactive Brokers, Trading 212, DEGIRO, or any spreadsheet
• Value, today's move, total return, and dividend income in your own currency
• A watchlist with prices, trends, and how close each plan is

LIVING WIDGETS AND APPLE WATCH
• Home Screen widgets for your plans, a stock's chart and zones, today's movers, and your streak
• A Portfolio widget with your value, today's move, and your closest buy zone in plain words
• On Apple Watch: your portfolio, closest plans, and charts you scrub with the Digital Crown, plus complications for your portfolio and market hours

A ONE-MINUTE DAILY HABIT
• A short daily brief, streaks, and achievements that reward calm, steady investing

DIPWISE PRO
Free includes 3 price alerts. Pro unlocks unlimited alerts, all 27 smart alerts, odds for every plan, live signals on all your stocks, heads-up alerts before a zone, and the dividend calendar.

Payment is charged to your Apple Account at confirmation of purchase. Subscriptions renew automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel any time in your App Store account settings.

Terms of Use: https://www.apple.com/legal/internet-services/itunes/dev/stdeula/
Privacy Policy: [add your privacy policy URL]

Dipwise is not a broker, doesn't execute trades, and doesn't give investment advice. Market data may be delayed and is for information only.

## Screenshots

Every image shares one seamless navy night sky in the app's own colors, so the set reads as a single scene as people swipe. Dippy is the main character: he perches on top of each device and reacts to what's on it. He keeps watch, peers down at the buy zone, flaps his wings when the alert lands, checks the odds, and in the last image falls asleep in the crescent moon.

Each image still works on its own, with one short headline, one real screen, and at most one moment from it enlarged. The first three carry the promise (buy the dip, draw your zone, get the alert), because they're the only ones people see in search results. All captures match the App Store build: Flock hidden, U.S. English, dollars, and the same prices everywhere.

`preview-iphone.png` and `preview-ipad.png` show each whole set side by side; `preview-watch.png` shows the watch set.

### iPhone 6.9-inch (1320 × 2868), from `iPhone-6.9/`

| # | File | Headline |
|---|------|----------|
| 1 | 01-buy-the-dip.png | Buy the dip. Never miss it. |
| 2 | 02-buy-zone.png | Draw your buy zone |
| 3 | 03-alert.png | It dips. Dippy taps you. |
| 4 | 04-odds.png | Know your odds before you buy |
| 5 | 05-smart-alerts.png | 27 smart alerts, plain English |
| 6 | 06-widgets.png | Your plans, always in sight |
| 7 | 07-apple-watch.png | Your portfolio, on your wrist |
| 8 | 08-import.png | Your portfolio in seconds |
| 9 | 09-portfolio.png | Watch it grow |
| 10 | 10-start-free.png | Sleep well. Dippy's on watch. |

Upload them in this order so the panorama lines up. Apple scales the 6.9-inch set down for every smaller iPhone, so it's the only iPhone set you need. `iPhone-6.5/` (1284 × 2778) has the same images in case you'd rather supply the 6.5-inch size yourself.

### iPad 13-inch (2064 × 2752), from `iPad-13/`

Required, because Dipwise runs on iPad. Apple scales this set down for smaller iPads.

| # | File | Headline |
|---|------|----------|
| 1 | 01-buy-the-dip.png | Buy the dip. Never miss it. |
| 2 | 02-buy-zone.png | Draw your buy zone |
| 3 | 03-alert.png | It dips. Dippy taps you. |
| 4 | 04-watchlist.png | Every stock, one calm list |
| 5 | 05-start-free.png | Sleep well. Dippy's on watch. |

### Apple Watch Ultra (422 × 514), from `AppleWatch-Ultra/`

01-today, 02-plans, 03-stock, 04-watchlist. Each page is rendered from the watch app's own components at 6× and scaled down, so text and charts stay sharp.

The Flock isn't in the screenshots or description yet, because App Store builds hide it until its iCloud backend is live. Add it back once it is.

### Regenerating

1. Capture iPhone screens on the iPhone 6.9-inch simulator and iPad screens on the iPad Pro 13-inch simulator, launching the debug build with `-hideFlock -AppleLanguages "(en)" -AppleLocale en_US -marketingDate 2026-10-13`. The date freezes every quote at that day's close, so all screens show the same prices. Save them into `ScreenshotStudio/Raw/` with the same names (`iphone-*.png`, `ipad-*.png`).
2. Launch with `-marketingScene watch` to render `watch-*.png` and Dippy's `owl-*.png` poses into the app's Documents folder, and copy them into `Raw/` (trim the owls to their visible edges).
3. Run `python3 Marketing/ScreenshotStudio/compose.py Marketing/ScreenshotStudio/Raw Marketing/AppStore`.
