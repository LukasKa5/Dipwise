# Dipwise: market and pricing analysis

_October 2026. Sources are listed at the end; most are vendor blogs, so treat exact figures as estimates._

## The goal in numbers

10,000 paying users at about €5 a month is roughly **€50,000 a month (€600,000 a year) before Apple's cut**. Apple takes 15% under the Small Business Program, so about €42,500 lands with you.

Typical funnel for a well-made finance utility:

| Step | Typical rate | Needed for 10,000 payers |
|---|---|---|
| Install → finishes onboarding | 60–75% | |
| Onboarded → starts trial or buys | 4–8% | |
| Trial → paid | 35–55% | |
| **Install → paid** | **≈2–4%** | **250,000–500,000 installs** |

So the target is realistic only with sustained installs: about 15,000–30,000 a month for 18–24 months, plus churn replacement. Indie trackers have done it (Stock Events, Delta, Snowball, Parqet, getquin all passed this scale), but none did it on organic search alone.

## Competitors and prices

| App | Price | Strength | Weakness users mention |
|---|---|---|---|
| Delta (eToro) | ~$54 / yr Pro, ~$108 PRO+ | Multi-asset, broker sync | Free tier cut to 10 assets in 2026 |
| getquin | ~€90 / yr | Community, EU brokers, AI | Data accuracy, sync bugs, paywall creep, noisy social feed |
| Snowball Analytics | from $80 / yr | Dividends | No tax lots, weak EU broker coverage |
| Sharesight | from ~$110 / yr | Tax reports | Spreadsheet feel, expensive |
| Stock Events | ~$5 / mo | Calendar of events | Not plan-oriented |
| Broker apps (eToro, Trade Republic, Robinhood) | free | Price alerts | Single-broker, single price, no plan |

**What people clearly pay for:** an accurate portfolio across brokers, dividends (calendar and income), alerts that are smarter than a single price, beating-the-market comparisons, and, on eToro, seeing what other investors do (CopyTrader and Popular Investors are its core product).

**Where nobody is good:** calm, plan-based buying (zones instead of single prices), probability of a plan triggering, and crowd data without the noise of a social feed. Those are exactly Dipwise's differentiators.

## Why Dipwise can win

1. **A clear promise.** "Buy the dip with a plan" is easier to understand than "portfolio tracker #47".
2. **The Flock is eToro's best idea without the casino.** eToro shows who owns what and lets you follow people. Dipwise now does the same across any broker, anonymously: top investors with 12-month results and risk scores, what the crowd owns, what it's buying and selling this week, what it does when a stock dips, and notifications when an investor you follow makes a move. No other independent tracker has this.
3. **Dippy.** A memorable mascot drives word of mouth and retention (Duolingo is the model), and the streak and daily brief create a habit.
4. **Apple-native depth.** Widgets, Apple Watch, and complications are things getquin and Delta do poorly.

## What's in Pro (≈€5 a month)

| Feature | Why people pay |
|---|---|
| Unlimited buy and sell zones (free: 3) | The core habit; the limit is felt in week one |
| 27 smart alerts (RSI, MACD, golden cross, trailing stops…) | Replaces paid tools like TradingView alerts |
| Odds for every plan | Unique; nobody else shows the chance a level is reached |
| Top investors, their portfolios and moves, follow with notifications | eToro's most valuable feature, broker-independent |
| What the flock owns, buys, and sells; what it does on dips | Crowd data people currently pay $50–60 a year for (insider and Congress trackers) |
| Your portfolio vs the S&P 500 | The question every investor asks; Pro in Delta and Parqet |
| Heads-up before a zone, dividend calendar | Strong for dividend investors, a huge segment |

## Pricing

- **Monthly €4.99**, **yearly €39.99** with a 7-day free trial (shown first, as "save 33%"), and **lifetime €119.99** as a price anchor.
- Expect about 70% of payers to choose yearly. At that mix, 10,000 payers ≈ €40,000 MRR equivalent.
- Don't go lower: €2.99 tiers attract churn-prone users, and finance users read price as quality.

## The biggest risks

1. **The Flock's cold start.** Crowd views need members, so they stay hidden until at least 20 people share (50 for Top Investors). Ask users to share their mix during onboarding and in the Flock tab, and launch in one or two markets first (Germany and the U.S.) so the crowd forms faster.
2. **Market data licensing.** Yahoo Finance's unofficial API isn't licensed for commercial use. Budget $20–80 a month for a licensed feed before marketing spend scales.
3. **Broker sync.** Users expect automatic sync, but CSV import is the honest v1. Adding read-only sync for Trade Republic, Scalable, and Robinhood later would be the biggest conversion lever.
4. **Regulation.** Keep "not investment advice" everywhere (already in the app), and never rank investors as "best to copy". Dipwise shows statistics, not recommendations.

## Go-to-market (where installs come from)

1. **ASO in eight languages** (done in the app; store text is in Listing.md). German-speaking markets are the strongest for paid portfolio trackers.
2. **TikTok, Instagram Reels, and YouTube Shorts with Dippy.** Short "Dippy caught the dip" clips. A mascot makes faceless content possible.
3. **Finance creators and communities** (r/eupersonalfinance, r/dividends, Finanzfluss-style creators): give them free Pro codes.
4. **Apple features**: widgets, Watch, and localization are what Apple editors feature. Pitch through the App Store "Get featured" form.
5. **Referral**: "Give a month, get a month" via offer codes once you have 1,000 users.

## Sources

- [AppFollow: ASO screenshots 2026](https://appfollow.io/blog/aso-screenshots-best-practices)
- [Delta Portfolio Tracker review 2026](https://www.euinvestinghub.com/articles/delta-portfolio-tracker-review/)
- [getquin review 2026](https://www.euinvestinghub.com/articles/getquin-portfolio-tracker-review/)
- [getquin vs Capitally](https://www.mycapitally.com/blog/getquin-review)
- [Sharesight vs Snowball Analytics](https://www.portfolioglance.com/investing-apps/sharesight-vs-snowball-analytics)
- [Snowball Analytics alternatives](https://stockunlock.com/snowball-analytics-alternatives.html)
- [eToro copy trading (Finder)](https://www.finder.com/investments/etoro-copy-trading)
- [eToro Popular Investor marketplace (Sacra)](https://sacra.com/chat/h/d9dcbcc5-e54d-4699-b54a-c12461eb1977/)
- [Mimic (insider and Congress trades) pricing](https://trustmrr.com/startup/mimic-app?metric=mrr)
- [Capitol Gains pricing](https://marlvel.ai/apps/capitol-gains-stock-tracker)
