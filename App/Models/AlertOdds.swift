import Foundation

/// How likely an alert is to fire, estimated from the stock's own price history.
struct AlertOdds {
  /// Chance of triggering within about a month (21 trading days).
  var monthChance: Double
  /// Chance of triggering within about three months (63 trading days).
  var quarterChance: Double
  /// The most recent session that would have triggered the alert.
  var lastTriggered: Date?
  /// Sessions in the past year that met the condition.
  var sessionsMet: Int
  /// Typical daily move, as a fraction.
  var dailyVolatility: Double

  init?(rule: AlertRule, quote: Quote) {
    let closes = quote.closes
    guard closes.count > 30 else { return nil }
    let returns = zip(closes.dropFirst(), closes).map { log($0 / $1) }
    let mean = returns.reduce(0, +) / Double(returns.count)
    let variance = returns.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(max(returns.count - 1, 1))
    let sigma = sqrt(variance)
    guard sigma > 0 else { return nil }
    dailyVolatility = sigma

    if rule.kind == .dailyMove {
      let hits = returns.filter { abs(exp($0) - 1) >= rule.percent }.count
      let daily = Double(hits) / Double(returns.count)
      monthChance = 1 - pow(1 - daily, 21)
      quarterChance = 1 - pow(1 - daily, 63)
      sessionsMet = hits
      let lastIndex = returns.lastIndex { abs(exp($0) - 1) >= rule.percent }
      lastTriggered = lastIndex.flatMap { quote.dates.indices.contains($0 + 1) ? quote.dates[$0 + 1] : nil }
      return
    }

    guard let level = rule.triggerLevel(for: quote), level > 0 else { return nil }
    let isSell = rule.kind.side == .sell && rule.kind != .trailingStop
    let met: (Double) -> Bool = isSell ? { $0 >= level } : { $0 <= level }
    if met(quote.price) {
      monthChance = 1
      quarterChance = 1
    } else {
      // Chance a random walk with this volatility touches the level (reflection principle).
      let distance = abs(log(level / quote.price))
      monthChance = 2 * Self.normalCDF(-distance / (sigma * sqrt(21)))
      quarterChance = 2 * Self.normalCDF(-distance / (sigma * sqrt(63)))
    }
    let inZone: (Double) -> Bool = rule.kind.isZone && rule.upper > rule.lower ? { $0 >= rule.lower && $0 <= rule.upper } : met
    sessionsMet = closes.filter(inZone).count
    let lastIndex = closes.lastIndex(where: met)
    lastTriggered = lastIndex.flatMap { quote.dates.indices.contains($0) ? quote.dates[$0] : nil }
  }

  /// A short, plain-language summary for rows.
  var headline: String {
    "\(monthChance.formatted(.percent.precision(.fractionLength(0)))) chance in 30 days"
  }

  var lastTriggeredText: String {
    guard let lastTriggered else { return String(localized: "Not reached in the past year") }
    if Calendar.current.isDateInToday(lastTriggered) { return String(localized: "Reached today") }
    return String(localized: "Last reached \(lastTriggered.formatted(.relative(presentation: .named)))")
  }

  private static func normalCDF(_ x: Double) -> Double {
    0.5 * erfc(-x / sqrt(2))
  }
}
