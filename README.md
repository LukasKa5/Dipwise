# Dipwise

Stock alerts for people who buy dips with a plan. You mark the price range where you'd buy and where you'd sell, and an owl called Dippy tells you when a stock gets there. No account, no ads, and it never connects to your broker.

iPhone, iPad, Apple Watch and widgets. English, German, Spanish, French, Italian, Brazilian Portuguese, Japanese and Korean.

Not on the App Store yet.

## What works

**Plans and alerts**
- Drag buy and sell zones on a chart
- 28 smart alert types (RSI, moving averages, trailing stop and so on), with adjustable thresholds
- "Dippy's recommended set" adds a sensible group of alerts in one tap
- Odds card: how likely a stock is to reach your zone within 30 and 90 days, worked out from its past year of daily moves

**Portfolio**
- CSV import from a broker, or manual entry
- Performance chart, comparison with any ETF or index, allocation, dividend calendar
- Income goal planner
- Risk section: volatility, biggest fall, worst day, beta, a 20% crash estimate, largest position
- Your Profile: investor DNA and blind spots

**Flock (the anonymous community)**
- Crowd buy and sell zones per stock, top investors, following
- Fear & Greed index built from the daily check-in
- Runs on sample data for now, see below

**Daily habit**
- Morning brief at 8:00 by default, recapping the last session
- Streaks, levels, Dip Journal
- 13 achievements, each with an outfit for Dippy. Pro members also get a flag for one of 15 countries

**Everything else**
- Seven widgets, Apple Watch app
- Desk Mode for iPhone Duo, using the outer display while the phone stands on a desk
- Paywall with yearly, monthly and lifetime plans, plus a 10-minute Pro preview once a day
- Company logos on stock tiles

**App Store material** (in `Marketing/AppStore/`)
- Screenshots for iPhone 6.9", 6.5", 6.3", iPad 13" and Apple Watch
- Headers, header videos and search images in all 8 languages
- Listing text in `Listing.md`, including names and keywords per language
- `Marketing/ScreenshotStudio/validate_assets.swift` checks all of it against Apple's sizes

## Project layout

```
App/                    iPhone and iPad app
Shared/                 Code shared with widgets and watch
Widget Extension/       iPhone widgets
Watch/                  Apple Watch app
Watch Widget Extension/ Watch complications
Backend/quote-proxy/    Cloudflare Worker: quotes and push alerts
Marketing/AppStore/     Finished store assets and listing text
Marketing/ScreenshotStudio/  Scripts that generate those assets
```
Regenerate store images:

```
python3 Marketing/ScreenshotStudio/compose.py Marketing/ScreenshotStudio/Raw Marketing/AppStore
swift Marketing/ScreenshotStudio/validate_assets.swift Marketing/AppStore
```

Debug builds accept launch arguments for screenshots, such as `-demoPortfolio`, `-previewPro YES`, `-startTab flock`, `-openStock NVDA` and `-marketingScene lock`. There's a full list in `Marketing/AppStore/Listing.md`.
