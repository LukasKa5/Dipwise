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

  var id: Self { self }

  var title: String {
    switch self {
    case .zones: "Buy & sell"
    case .moves: "Price moves"
    case .trend: "Trend"
    case .momentum: "Momentum"
    case .position: "Your position"
    case .income: "Income"
    }
  }
}

enum AlertKind: String, Codable, CaseIterable, Identifiable {
  case buyZone, sellZone, priceBelow, priceAbove
  case dropFromHigh, weeklyDrop, dailyMove, gapMove, newLow, newHigh
  case belowAverage, aboveAverage, goldenCross, deathCross
  case rsiOversold, rsiOverbought, macdBullish, macdBearish, volumeSpike
  case trailingStop, stopLoss, profitTarget, breakEven
  case dividendSoon

  var id: Self { self }

  var category: AlertCategory {
    switch self {
    case .buyZone, .sellZone, .priceBelow, .priceAbove: .zones
    case .dropFromHigh, .weeklyDrop, .dailyMove, .gapMove, .newLow, .newHigh: .moves
    case .belowAverage, .aboveAverage, .goldenCross, .deathCross: .trend
    case .rsiOversold, .rsiOverbought, .macdBullish, .macdBearish, .volumeSpike: .momentum
    case .trailingStop, .stopLoss, .profitTarget, .breakEven: .position
    case .dividendSoon: .income
    }
  }

  var title: String {
    switch self {
    case .buyZone: "Buy zone"
    case .sellZone: "Sell zone"
    case .priceBelow: "Price below"
    case .priceAbove: "Price above"
    case .dropFromHigh: "Dip from high"
    case .weeklyDrop: "Fast drop"
    case .dailyMove: "Big daily move"
    case .gapMove: "Opening gap"
    case .newLow: "New 52-week low"
    case .newHigh: "New 52-week high"
    case .belowAverage: "Falls below average"
    case .aboveAverage: "Rises above average"
    case .goldenCross: "Golden cross"
    case .deathCross: "Death cross"
    case .rsiOversold: "Oversold (RSI)"
    case .rsiOverbought: "Overbought (RSI)"
    case .macdBullish: "MACD turns up"
    case .macdBearish: "MACD turns down"
    case .volumeSpike: "Volume spike"
    case .trailingStop: "Trailing stop"
    case .stopLoss: "Stop loss"
    case .profitTarget: "Profit target"
    case .breakEven: "Back to break-even"
    case .dividendSoon: "Dividend coming"
    }
  }

  var explanation: String {
    switch self {
    case .buyZone: "The range where you'd happily buy."
    case .sellZone: "The range where you'd take profit."
    case .priceBelow: "One exact price to buy at."
    case .priceAbove: "One exact price to sell at."
    case .dropFromHigh: "The stock falls a set amount below its 52-week high."
    case .weeklyDrop: "The stock falls sharply over a few days."
    case .dailyMove: "The stock jumps or slides a lot in one day."
    case .gapMove: "The stock opens far above or below yesterday's close."
    case .newLow: "The price hits its lowest level in a year."
    case .newHigh: "The price hits its highest level in a year."
    case .belowAverage: "The price drops under its long-term average, a common warning sign."
    case .aboveAverage: "The price climbs back over its long-term average."
    case .goldenCross: "The 50-day average crosses above the 200-day, a classic bullish signal."
    case .deathCross: "The 50-day average crosses below the 200-day, a classic bearish signal."
    case .rsiOversold: "Selling looks overdone. Popular with dip buyers."
    case .rsiOverbought: "Buying looks overheated. A moment to consider profits."
    case .macdBullish: "Momentum turns positive."
    case .macdBearish: "Momentum turns negative."
    case .volumeSpike: "Far more shares trade than usual. Something is happening."
    case .trailingStop: "Follows the price up and alerts you if it falls from the peak."
    case .stopLoss: "Your position falls a set amount below what you paid."
    case .profitTarget: "Your position rises a set amount above what you paid."
    case .breakEven: "The price climbs back to what you paid."
    case .dividendSoon: "A dividend is expected within a week."
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
    case .dailyMove: "bolt.fill"
    case .gapMove: "arrow.up.and.down.circle"
    case .newLow: "arrow.down.to.line.circle"
    case .newHigh: "crown.fill"
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
    }
  }

  var side: TradeSide {
    switch self {
    case .buyZone, .priceBelow, .dropFromHigh, .weeklyDrop, .newLow, .goldenCross, .rsiOversold, .macdBullish: .buy
    case .sellZone, .priceAbove, .newHigh, .deathCross, .rsiOverbought, .macdBearish, .trailingStop, .stopLoss, .profitTarget, .breakEven: .sell
    case .dailyMove, .gapMove, .belowAverage, .aboveAverage, .volumeSpike, .dividendSoon: .watch
    }
  }

  var isZone: Bool { self == .buyZone || self == .sellZone }
  var usesPercent: Bool { [.dropFromHigh, .weeklyDrop, .dailyMove, .gapMove, .trailingStop, .stopLoss, .profitTarget].contains(self) }
  var usesAverage: Bool { self == .belowAverage || self == .aboveAverage }
  var usesLevel: Bool { [.rsiOversold, .rsiOverbought, .volumeSpike].contains(self) }
  /// Alerts measured from what the user paid.
  var needsCost: Bool { [.stopLoss, .profitTarget, .breakEven].contains(self) }
  /// Conditions that describe a state, so they should only fire when they newly become true.
  var firesOnChangeOnly: Bool {
    ![.buyZone, .sellZone, .priceBelow, .priceAbove, .dropFromHigh, .trailingStop, .stopLoss, .profitTarget, .breakEven].contains(self)
  }

  /// Smart alerts are part of Dipwise Pro.
  var requiresPro: Bool { category != .zones }

  static var smart: [AlertKind] { allCases.filter { $0.category != .zones } }
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
    default: nil
    }
  }

  /// Level-based rules fire when the price falls to (true) or rises to (false) the level.
  private var triggersBelow: Bool {
    switch kind {
    case .buyZone, .priceBelow, .dropFromHigh, .trailingStop, .belowAverage, .stopLoss, .newLow: true
    default: false
    }
  }

  func isMet(by quote: Quote) -> Bool {
    switch kind {
    case .dailyMove: return abs(quote.change) >= percent
    case .gapMove: return abs(quote.gap) >= percent
    case .weeklyDrop: return quote.change(over: days) <= -percent
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

  /// How far from firing, as a fraction (0 when met).
  func distance(for quote: Quote) -> Double? {
    guard quote.price > 0 else { return nil }
    if isMet(by: quote) { return 0 }
    switch kind {
    case .dailyMove: return max(0, percent - abs(quote.change))
    case .gapMove: return max(0, percent - abs(quote.gap))
    case .weeklyDrop: return max(0, percent + quote.change(over: days))
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
    case .dailyMove, .gapMove, .weeklyDrop: max(percent, 0.01)
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
    case .buyZone: return "Buy between \(format(lower)) and \(format(upper))"
    case .sellZone: return "Sell between \(format(lower)) and \(format(upper))"
    case .priceBelow: return "Buy below \(format(lower))"
    case .priceAbove: return "Sell above \(format(lower))"
    case .dropFromHigh: return "Buy after a \(p) dip from the high"
    case .weeklyDrop: return "Falls \(p) in \(days) days"
    case .dailyMove: return "Moves \(p) in one day"
    case .gapMove: return "Opens \(p) higher or lower"
    case .newLow: return "Hits a new 52-week low"
    case .newHigh: return "Hits a new 52-week high"
    case .belowAverage: return "Falls below its \(averageDays)-day average"
    case .aboveAverage: return "Rises above its \(averageDays)-day average"
    case .goldenCross: return "50-day crosses above 200-day"
    case .deathCross: return "50-day crosses below 200-day"
    case .rsiOversold: return "RSI drops to \(Int(level)) (oversold)"
    case .rsiOverbought: return "RSI climbs to \(Int(level)) (overbought)"
    case .macdBullish: return "MACD crosses above its signal"
    case .macdBearish: return "MACD crosses below its signal"
    case .volumeSpike: return "Volume hits \(level.formatted(.number.precision(.fractionLength(0...1))))× normal"
    case .trailingStop: return "Sell if it falls \(p) from its peak"
    case .stopLoss: return "Sell if it falls \(p) below \(format(lower))"
    case .profitTarget: return "Take profit at +\(p) (\(format(lower * (1 + percent))))"
    case .breakEven: return "Back to your cost of \(format(lower))"
    case .dividendSoon: return "Dividend expected within a week"
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
    default: break
    }
    return rule
  }
}
