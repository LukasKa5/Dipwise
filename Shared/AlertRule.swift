import Foundation

/// Whether an alert is about buying, selling, or just watching.
enum TradeSide: String, Codable {
  case buy
  case sell
  case watch
}

/// Groups of smart alerts in the editor.
enum AlertCategory: String, CaseIterable, Identifiable {
  case zones
  case moves
  case trend
  case momentum
  case position
  case income
  case crowd

  var id: Self { self }

  var title: String {
    switch self {
    case .zones: String(localized: "Buy & sell")
    case .moves: String(localized: "Price moves")
    case .trend: String(localized: "Trend")
    case .momentum: String(localized: "Momentum")
    case .position: String(localized: "Your position")
    case .income: String(localized: "Income")
    case .crowd: String(localized: "The Flock")
    }
  }
}

enum AlertKind: String, Codable, CaseIterable, Identifiable {
  case buyZone, sellZone, priceBelow, priceAbove
  case dropFromHigh, weeklyDrop, losingStreak, dailyMove, gapMove, newLow, newHigh, reboundFromLow
  case belowAverage, aboveAverage, goldenCross, deathCross, beatsMarket, lagsMarket
  case rsiOversold, rsiOverbought, macdBullish, macdBearish, bollingerLow, bollingerHigh, volumeSpike
  case trailingStop, stopLoss, profitTarget, breakEven
  case dividendSoon, yieldAbove
  case crowdBuyZone, crowdBuying, topInvestorBuys

  var id: Self { self }

  var category: AlertCategory {
    switch self {
    case .buyZone, .sellZone, .priceBelow, .priceAbove: .zones
    case .dropFromHigh, .weeklyDrop, .losingStreak, .dailyMove, .gapMove, .newLow, .newHigh, .reboundFromLow: .moves
    case .belowAverage, .aboveAverage, .goldenCross, .deathCross, .beatsMarket, .lagsMarket: .trend
    case .rsiOversold, .rsiOverbought, .macdBullish, .macdBearish, .bollingerLow, .bollingerHigh, .volumeSpike: .momentum
    case .trailingStop, .stopLoss, .profitTarget, .breakEven: .position
    case .dividendSoon, .yieldAbove: .income
    case .crowdBuyZone, .crowdBuying, .topInvestorBuys: .crowd
    }
  }

  var title: String {
    switch self {
    case .buyZone: String(localized: "Buy zone")
    case .sellZone: String(localized: "Sell zone")
    case .priceBelow: String(localized: "Price below")
    case .priceAbove: String(localized: "Price above")
    case .dropFromHigh: String(localized: "Dip from high")
    case .weeklyDrop: String(localized: "Fast drop")
    case .losingStreak: String(localized: "Losing streak")
    case .beatsMarket: String(localized: "Beats the market")
    case .lagsMarket: String(localized: "Lags the market")
    case .yieldAbove: String(localized: "Dividend yield")
    case .dailyMove: String(localized: "Big daily move")
    case .gapMove: String(localized: "Opening gap")
    case .newLow: String(localized: "New 52-week low")
    case .newHigh: String(localized: "New 52-week high")
    case .reboundFromLow: String(localized: "Rebound from low")
    case .bollingerLow: String(localized: "Lower band touch")
    case .bollingerHigh: String(localized: "Upper band touch")
    case .belowAverage: String(localized: "Falls below average")
    case .aboveAverage: String(localized: "Rises above average")
    case .goldenCross: String(localized: "Golden cross")
    case .deathCross: String(localized: "Death cross")
    case .rsiOversold: String(localized: "Oversold (RSI)")
    case .rsiOverbought: String(localized: "Overbought (RSI)")
    case .macdBullish: String(localized: "MACD turns up")
    case .macdBearish: String(localized: "MACD turns down")
    case .volumeSpike: String(localized: "Volume spike")
    case .trailingStop: String(localized: "Trailing stop")
    case .stopLoss: String(localized: "Stop loss")
    case .profitTarget: String(localized: "Profit target")
    case .breakEven: String(localized: "Back to break-even")
    case .dividendSoon: String(localized: "Dividend coming")
    case .crowdBuyZone: String(localized: "Enters the crowd's buy zone")
    case .crowdBuying: String(localized: "Flock buying surge")
    case .topInvestorBuys: String(localized: "A top investor buys")
    }
  }

  var explanation: String {
    switch self {
    case .buyZone: String(localized: "The range where you'd happily buy.")
    case .sellZone: String(localized: "The range where you'd take profit.")
    case .priceBelow: String(localized: "One exact price to buy at.")
    case .priceAbove: String(localized: "One exact price to sell at.")
    case .dropFromHigh: String(localized: "The stock falls a set amount below its 52-week high.")
    case .weeklyDrop: String(localized: "The stock falls sharply over a few days.")
    case .losingStreak: String(localized: "The stock closes lower several days in a row. Long streaks often end with a bounce.")
    case .beatsMarket: String(localized: "The stock outperforms the S&P 500 by a set amount. Leaders often keep leading.")
    case .lagsMarket: String(localized: "The stock trails the S&P 500 by a set amount. A sign something may be wrong.")
    case .yieldAbove: String(localized: "The dividend yield rises above your target, so you buy more income for your money.")
    case .dailyMove: String(localized: "The stock jumps or slides a lot in one day.")
    case .gapMove: String(localized: "The stock opens far above or below yesterday's close.")
    case .newLow: String(localized: "The price hits its lowest level in a year.")
    case .newHigh: String(localized: "The price hits its highest level in a year.")
    case .reboundFromLow: String(localized: "The stock bounces a set amount off its 52-week low. A sign the bottom may be in.")
    case .bollingerLow: String(localized: "The price drops to the bottom of its normal range (Bollinger Band). Often a short-term dip.")
    case .bollingerHigh: String(localized: "The price stretches to the top of its normal range (Bollinger Band). Often a short-term peak.")
    case .belowAverage: String(localized: "The price drops under its long-term average, a common warning sign.")
    case .aboveAverage: String(localized: "The price climbs back over its long-term average.")
    case .goldenCross: String(localized: "The 50-day average crosses above the 200-day, a classic bullish signal.")
    case .deathCross: String(localized: "The 50-day average crosses below the 200-day, a classic bearish signal.")
    case .rsiOversold: String(localized: "Selling looks overdone. Popular with dip buyers.")
    case .rsiOverbought: String(localized: "Buying looks overheated. A moment to consider profits.")
    case .macdBullish: String(localized: "Momentum turns positive.")
    case .macdBearish: String(localized: "Momentum turns negative.")
    case .volumeSpike: String(localized: "Far more shares trade than usual. Something is happening.")
    case .trailingStop: String(localized: "Follows the price up and alerts you if it falls from the peak.")
    case .stopLoss: String(localized: "Your position falls a set amount below what you paid.")
    case .profitTarget: String(localized: "Your position rises a set amount above what you paid.")
    case .breakEven: String(localized: "The price climbs back to what you paid.")
    case .dividendSoon: String(localized: "A dividend is expected within a week.")
    case .crowdBuyZone: String(localized: "The price drops into the range where most Dipwise investors plan to buy.")
    case .crowdBuying: String(localized: "Most members who moved this week are buying it, not selling.")
    case .topInvestorBuys: String(localized: "One of the flock's top 50 investors adds it to their portfolio.")
    }
  }

  var systemImage: String {
    switch self {
    case .buyZone: "arrow.down.to.line.compact"
    case .sellZone: "arrow.up.to.line.compact"
    case .priceBelow: "arrow.down.to.line"
    case .priceAbove: "arrow.up.to.line"
    case .dropFromHigh: "chart.line.downtrend.xyaxis"
    case .weeklyDrop: "arrow.down.right.circle"
    case .losingStreak: "calendar.badge.minus"
    case .beatsMarket: "trophy.fill"
    case .lagsMarket: "tortoise.fill"
    case .yieldAbove: "percent"
    case .dailyMove: "bolt.fill"
    case .gapMove: "arrow.up.and.down.circle"
    case .newLow: "arrow.down.to.line.circle"
    case .newHigh: "crown.fill"
    case .reboundFromLow: "arrow.uturn.up"
    case .bollingerLow: "arrow.down.to.line.compact"
    case .bollingerHigh: "arrow.up.to.line.compact"
    case .belowAverage: "waveform.path.ecg"
    case .aboveAverage: "waveform.path.ecg.rectangle"
    case .goldenCross: "sparkles"
    case .deathCross: "xmark.octagon"
    case .rsiOversold: "gauge.with.dots.needle.0percent"
    case .rsiOverbought: "gauge.with.dots.needle.100percent"
    case .macdBullish: "chart.line.uptrend.xyaxis"
    case .macdBearish: "chart.line.downtrend.xyaxis.circle"
    case .volumeSpike: "chart.bar.fill"
    case .trailingStop: "shield.lefthalf.filled"
    case .stopLoss: "hand.raised.fill"
    case .profitTarget: "flag.checkered"
    case .breakEven: "equal.circle"
    case .dividendSoon: "leaf.fill"
    case .crowdBuyZone: "person.3.fill"
    case .crowdBuying: "arrow.left.arrow.right.circle.fill"
    case .topInvestorBuys: "trophy.circle.fill"
    }
  }

  var side: TradeSide {
    switch self {
    case .buyZone, .priceBelow, .dropFromHigh, .weeklyDrop, .losingStreak, .newLow, .goldenCross, .rsiOversold, .macdBullish, .bollingerLow, .reboundFromLow, .beatsMarket, .yieldAbove: .buy
    case .crowdBuyZone, .crowdBuying, .topInvestorBuys: .buy
    case .sellZone, .priceAbove, .newHigh, .deathCross, .rsiOverbought, .macdBearish, .bollingerHigh, .trailingStop, .stopLoss, .profitTarget, .breakEven, .lagsMarket: .sell
    case .dailyMove, .gapMove, .belowAverage, .aboveAverage, .volumeSpike, .dividendSoon: .watch
    }
  }

  var isZone: Bool { self == .buyZone || self == .sellZone }
  var usesPercent: Bool { [.dropFromHigh, .weeklyDrop, .dailyMove, .gapMove, .trailingStop, .stopLoss, .profitTarget, .reboundFromLow, .beatsMarket, .lagsMarket, .yieldAbove].contains(self) }
  /// Alerts measured over a number of trading days.
  var usesDays: Bool { [.weeklyDrop, .losingStreak, .beatsMarket, .lagsMarket].contains(self) }
  var usesAverage: Bool { self == .belowAverage || self == .aboveAverage }
  var usesLevel: Bool { [.rsiOversold, .rsiOverbought, .volumeSpike, .crowdBuying].contains(self) }
  /// Alerts that need the flock's data, not just prices.
  var needsCrowd: Bool { category == .crowd }
  /// Alerts measured from what the user paid.
  var needsCost: Bool { [.stopLoss, .profitTarget, .breakEven].contains(self) }
  /// Conditions that describe a state, so they should only fire when they newly become true.
  var firesOnChangeOnly: Bool {
    ![.buyZone, .sellZone, .priceBelow, .priceAbove, .dropFromHigh, .trailingStop, .stopLoss, .profitTarget, .breakEven].contains(self)
  }

  /// Smart alerts are part of Dipwise Pro.
  var requiresPro: Bool { category != .zones }

  static var smart: [AlertKind] { allCases.filter { $0.category != .zones } }
  /// Smart alerts that work from prices alone, which is what widgets, the watch, and counts in copy refer to.
  static var priceSmart: [AlertKind] { smart.filter { !$0.needsCrowd } }
}

/// A condition the user wants to be told about.
struct AlertRule: Codable, Hashable {
  var kind: AlertKind
  /// Zone low, the single price level, or the user's cost for position alerts.
  var lower: Double = 0
  /// Zone high.
  var upper: Double = 0
  /// Fraction for percentage rules, e.g. 0.1 for 10%.
  var percent: Double = 0
  var averageDays: Int = 200
  /// Highest price seen since a trailing stop was set.
  var peak: Double = 0
  /// RSI threshold or volume multiple.
  var level: Double = 0
  /// Look-back window for multi-day moves.
  var days: Int = 5

  /// The price that sets the alert off, when the rule has one.
  func triggerLevel(for quote: Quote) -> Double? {
    switch kind {
    case .buyZone: upper
    case .sellZone, .priceBelow, .priceAbove, .breakEven: lower
    case .dropFromHigh: quote.high52 * (1 - percent)
    case .trailingStop: max(peak, quote.price) * (1 - percent)
    case .belowAverage, .aboveAverage: quote.movingAverage(days: averageDays)
    case .stopLoss: lower * (1 - percent)
    case .profitTarget: lower * (1 + percent)
    case .newLow: quote.previousLow
    case .newHigh: quote.previousHigh
    case .reboundFromLow: quote.low52 * (1 + percent)
    case .bollingerLow: quote.bollinger?.lower
    case .bollingerHigh: quote.bollinger?.upper
    default: nil
    }
  }

  /// Level-based rules fire when the price falls to (true) or rises to (false) the level.
  private var triggersBelow: Bool {
    switch kind {
    case .buyZone, .priceBelow, .dropFromHigh, .trailingStop, .belowAverage, .stopLoss, .newLow, .bollingerLow: true
    default: false
    }
  }

  func isMet(by quote: Quote) -> Bool {
    switch kind {
    case .dailyMove: return abs(quote.change) >= percent
    case .gapMove: return abs(quote.gap) >= percent
    case .weeklyDrop: return quote.change(over: days) <= -percent
    case .losingStreak: return quote.losingStreak >= days
    case .beatsMarket: return quote.relativeToMarket(over: days).map { $0 >= percent } ?? false
    case .lagsMarket: return quote.relativeToMarket(over: days).map { $0 <= -percent } ?? false
    case .yieldAbove: return quote.dividendYield >= percent && percent > 0
    case .goldenCross, .deathCross:
      guard let fast = quote.movingAverage(days: 50), let slow = quote.movingAverage(days: 200) else { return false }
      return kind == .goldenCross ? fast > slow : fast < slow
    case .rsiOversold: return quote.rsi().map { $0 <= level } ?? false
    case .rsiOverbought: return quote.rsi().map { $0 >= level } ?? false
    case .macdBullish, .macdBearish:
      guard let macd = quote.macd else { return false }
      return kind == .macdBullish ? macd.line > macd.signal : macd.line < macd.signal
    case .volumeSpike: return (quote.volumeRatio ?? 0) >= level
    case .dividendSoon: return quote.daysToNextDividend.map { $0 <= 7 } ?? false
    default:
      guard let trigger = triggerLevel(for: quote) else { return false }
      return triggersBelow ? quote.price <= trigger : quote.price >= trigger
    }
  }

  /// For alerts built on the flock's data: whether they're met, or nil when there's no crowd data to judge by.
  func isMet(by quote: Quote, crowd: CrowdFacts?) -> Bool? {
    guard kind.needsCrowd else { return isMet(by: quote) }
    guard let crowd else { return nil }
    switch kind {
    case .crowdBuyZone: return crowd.buyZone.map { quote.price <= $0.upperBound } ?? false
    case .crowdBuying: return crowd.movers >= 5 && crowd.buyShare >= level
    case .topInvestorBuys: return crowd.topInvestorBuysToday > 0
    default: return false
    }
  }

  /// How far from firing, as a fraction (0 when met).
  func distance(for quote: Quote) -> Double? {
    guard quote.price > 0 else { return nil }
    if isMet(by: quote) { return 0 }
    switch kind {
    case .dailyMove: return max(0, percent - abs(quote.change))
    case .gapMove: return max(0, percent - abs(quote.gap))
    case .weeklyDrop: return max(0, percent + quote.change(over: days))
    case .losingStreak: return Double(max(0, days - quote.losingStreak)) / Double(max(days, 1)) * 0.2
    case .beatsMarket: return quote.relativeToMarket(over: days).map { max(0, percent - $0) }
    case .lagsMarket: return quote.relativeToMarket(over: days).map { max(0, percent + $0) }
    case .yieldAbove: return quote.dividendYield > 0 ? max(0, percent - quote.dividendYield) : nil
    case .goldenCross, .deathCross:
      guard let fast = quote.movingAverage(days: 50), let slow = quote.movingAverage(days: 200) else { return nil }
      return abs(fast - slow) / quote.price
    case .rsiOversold: return quote.rsi().map { max(0, $0 - level) / 100 }
    case .rsiOverbought: return quote.rsi().map { max(0, level - $0) / 100 }
    case .macdBullish, .macdBearish:
      guard let macd = quote.macd else { return nil }
      return abs(macd.line - macd.signal) / quote.price
    case .volumeSpike: return quote.volumeRatio.map { max(0, level - $0) / max(level, 1) }
    case .dividendSoon: return quote.daysToNextDividend.map { max(0, Double($0 - 7)) / 90 }
    default:
      guard let trigger = triggerLevel(for: quote) else { return nil }
      return max(0, triggersBelow ? (quote.price - trigger) / quote.price : (trigger - quote.price) / quote.price)
    }
  }

  /// Progress toward firing on a 0–1 scale.
  func progress(for quote: Quote) -> Double {
    guard let distance = distance(for: quote) else { return 0 }
    let span: Double = switch kind {
    case .dailyMove, .gapMove, .weeklyDrop, .beatsMarket, .lagsMarket, .yieldAbove: max(percent, 0.01)
    case .rsiOversold, .rsiOverbought: 0.4
    case .volumeSpike, .dividendSoon: 1
    case .goldenCross, .deathCross, .macdBullish, .macdBearish: 0.08
    default: 0.2
    }
    return 1 - min(distance / span, 1)
  }

  /// How deep the price is inside a zone, 0 at the entry edge and 1 at the far edge.
  func zoneDepth(for quote: Quote) -> Double? {
    guard kind.isZone, upper > lower else { return nil }
    let depth = kind == .buyZone ? (upper - quote.price) / (upper - lower) : (quote.price - lower) / (upper - lower)
    return depth < 0 ? nil : min(depth, 1)
  }

  /// A representative price for comparing with other investors.
  var referencePrice: Double? {
    switch kind {
    case .buyZone, .sellZone: (lower + upper) / 2
    case .priceBelow, .priceAbove: lower
    default: nil
    }
  }

  /// A plain-language description, like "Buy between $170 and $178".
  func summary(format: (Double) -> String) -> String {
    let p = percent.formatted(.percent.precision(.fractionLength(0)))
    switch kind {
    case .buyZone: return String(localized: "Buy between \(format(lower)) and \(format(upper))")
    case .sellZone: return String(localized: "Sell between \(format(lower)) and \(format(upper))")
    case .priceBelow: return String(localized: "Buy below \(format(lower))")
    case .priceAbove: return String(localized: "Sell above \(format(lower))")
    case .dropFromHigh: return String(localized: "Buy after a \(p) dip from the high")
    case .weeklyDrop: return String(localized: "Falls \(p) in \(days) days")
    case .losingStreak: return String(localized: "Down \(days) days in a row")
    case .beatsMarket: return String(localized: "Beats the S&P 500 by \(p) over \(days) days")
    case .lagsMarket: return String(localized: "Trails the S&P 500 by \(p) over \(days) days")
    case .yieldAbove: return String(localized: "Dividend yield rises above \(percent.formatted(.percent.precision(.fractionLength(1))))")
    case .dailyMove: return String(localized: "Moves \(p) in one day")
    case .gapMove: return String(localized: "Opens \(p) higher or lower")
    case .newLow: return String(localized: "Hits a new 52-week low")
    case .newHigh: return String(localized: "Hits a new 52-week high")
    case .reboundFromLow: return String(localized: "Bounces \(p) off its 52-week low")
    case .bollingerLow: return String(localized: "Touches its lower Bollinger Band")
    case .bollingerHigh: return String(localized: "Touches its upper Bollinger Band")
    case .belowAverage: return String(localized: "Falls below its \(averageDays)-day average")
    case .aboveAverage: return String(localized: "Rises above its \(averageDays)-day average")
    case .goldenCross: return "50-day crosses above 200-day"
    case .deathCross: return "50-day crosses below 200-day"
    case .rsiOversold: return String(localized: "RSI drops to \(Int(level)) (oversold)")
    case .rsiOverbought: return String(localized: "RSI climbs to \(Int(level)) (overbought)")
    case .macdBullish: return String(localized: "MACD crosses above its signal")
    case .macdBearish: return String(localized: "MACD crosses below its signal")
    case .volumeSpike: return String(localized: "Volume hits \(level.formatted(.number.precision(.fractionLength(0...1))))× normal")
    case .trailingStop: return String(localized: "Sell if it falls \(p) from its peak")
    case .stopLoss: return String(localized: "Sell if it falls \(p) below \(format(lower))")
    case .profitTarget: return String(localized: "Take profit at +\(p) (\(format(lower * (1 + percent))))")
    case .breakEven: return String(localized: "Back to your cost of \(format(lower))")
    case .dividendSoon: return String(localized: "Dividend expected within a week")
    case .crowdBuyZone: return String(localized: "Enters the crowd's buy zone")
    case .crowdBuying: return String(localized: "\(level.formatted(.percent.precision(.fractionLength(0)))) of the flock is buying")
    case .topInvestorBuys: return String(localized: "A top investor adds it")
    }
  }

  /// Sensible starting values for a new alert of this kind.
  static func defaults(for kind: AlertKind, price: Double, cost: Double) -> AlertRule {
    var rule = AlertRule(kind: kind)
    switch kind {
    case .buyZone: rule.lower = price * 0.90; rule.upper = price * 0.95
    case .sellZone: rule.lower = price * 1.10; rule.upper = price * 1.18
    case .priceBelow: rule.lower = price * 0.92
    case .priceAbove: rule.lower = price * 1.10
    case .dropFromHigh: rule.percent = 0.2
    case .weeklyDrop: rule.percent = 0.08; rule.days = 5
    case .dailyMove: rule.percent = 0.05
    case .gapMove: rule.percent = 0.04
    case .trailingStop: rule.percent = 0.08; rule.peak = price
    case .stopLoss: rule.percent = 0.1; rule.lower = cost > 0 ? cost : price
    case .profitTarget: rule.percent = 0.25; rule.lower = cost > 0 ? cost : price
    case .breakEven: rule.lower = cost > 0 ? cost : price
    case .belowAverage, .aboveAverage: rule.averageDays = 200
    case .rsiOversold: rule.level = 30
    case .rsiOverbought: rule.level = 70
    case .volumeSpike: rule.level = 2
    case .reboundFromLow: rule.percent = 0.15
    case .losingStreak: rule.days = 5
    case .beatsMarket, .lagsMarket: rule.percent = 0.05; rule.days = 21
    case .yieldAbove: rule.percent = 0.04
    case .crowdBuying: rule.level = 0.7
    default: break
    }
    return rule
  }
}

/// What the flock knows about one stock right now, for alerts built on the crowd.
struct CrowdFacts: Hashable {
  /// The middle half of everyone's buy targets.
  var buyZone: ClosedRange<Double>?
  /// Of members who added or trimmed it this week, the share who added.
  var buyShare: Double
  var movers: Int
  /// Top investors who added to it in the last day.
  var topInvestorBuysToday: Int
}
