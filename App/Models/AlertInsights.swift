import Foundation

/// Statistics about the user's alerts: health of their plans, what's likely to fire next, and how past alerts worked out.
struct AlertInsights {
  struct Likely: Identifiable {
    var alert: PriceAlert
    var odds: AlertOdds
    var id: UUID { alert.id }
  }

  struct Outcome: Identifiable {
    var alert: PriceAlert
    var change: Double
    var id: UUID { alert.id }
  }

  struct Gap: Identifiable {
    var holding: Holding
    var missing: String
    var id: String { holding.symbol + missing }
  }

  var holdings: [Holding]
  var quotes: [String: Quote]

  private var alerts: [PriceAlert] { holdings.flatMap { $0.alerts ?? [] } }
  var active: [PriceAlert] { alerts.filter(\.isActive) }
  var fired: [PriceAlert] { alerts.filter { $0.triggeredAt != nil } }
  var expired: [PriceAlert] { alerts.filter { !$0.isActive && $0.triggeredAt == nil } }

  var hitRate: Double? {
    let finished = fired.count + expired.count
    return finished == 0 ? nil : Double(fired.count) / Double(finished)
  }

  /// Average days between setting an alert and it firing.
  var averageDaysToFire: Double? {
    let days = fired.compactMap { alert in alert.triggeredAt.map { $0.timeIntervalSince(alert.createdAt) / 86_400 } }
    return days.isEmpty ? nil : days.reduce(0, +) / Double(days.count)
  }

  /// 0–100: does every stock have a buy zone, a sell zone, and protection?
  var planHealth: Int {
    guard !holdings.isEmpty else { return 0 }
    let scores = holdings.map { holding -> Double in
      let kinds = Set(holding.activeAlerts.map(\.kind))
      var score = 0.0
      if kinds.contains(.buyZone) || kinds.contains(.priceBelow) { score += 40 }
      if kinds.contains(.sellZone) || kinds.contains(.priceAbove) { score += 35 }
      if kinds.contains(.trailingStop) || kinds.contains(.belowAverage) || kinds.contains(.dropFromHigh) { score += 25 }
      return score
    }
    return Int((scores.reduce(0, +) / Double(scores.count)).rounded())
  }

  var healthLabel: String {
    switch planHealth {
    case 85...: "Excellent"
    case 60..<85: "Solid"
    case 35..<60: "Getting there"
    default: "Needs a plan"
    }
  }

  /// Active alerts most likely to fire within a month.
  var mostLikely: [Likely] {
    active.compactMap { alert in
      guard let quote = quotes[alert.symbol], let odds = AlertOdds(rule: alert.rule, quote: quote),
            (alert.distance(for: quote) ?? 1) > 0 else { return nil }
      return Likely(alert: alert, odds: odds)
    }
    .sorted { $0.odds.monthChance > $1.odds.monthChance }
  }

  /// Fired alerts with how the price moved since.
  private func outcomes(side: TradeSide) -> [Outcome] {
    fired.filter { $0.kind.side == side }.compactMap { alert in
      guard let price = alert.triggeredPrice, price > 0, let quote = quotes[alert.symbol] else { return nil }
      return Outcome(alert: alert, change: quote.price / price - 1)
    }
  }

  var buyOutcomes: [Outcome] { outcomes(side: .buy).sorted { $0.change > $1.change } }
  var sellOutcomes: [Outcome] { outcomes(side: .sell).sorted { $0.change < $1.change } }

  var buyAverage: Double? { average(buyOutcomes.map(\.change)) }
  var buyWinRate: Double? { rate(buyOutcomes) { $0.change > 0 } }
  /// A sell alert was a good call when the price fell afterwards.
  var sellGoodCalls: Double? { rate(sellOutcomes) { $0.change < 0 } }

  /// Buy alerts that fired, went up since, and weren't acted on.
  var missed: [Outcome] {
    buyOutcomes.filter { $0.change > 0.03 && ($0.alert.journalAction == nil || $0.alert.journalAction == .skipped) }
  }

  /// Alerts fired per week over the last twelve weeks, oldest first.
  var weeklyFired: [(week: Date, count: Int)] {
    let calendar = Calendar.current
    let start = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
    return (0..<12).reversed().map { offset in
      let week = calendar.date(byAdding: .weekOfYear, value: -offset, to: start) ?? start
      let end = calendar.date(byAdding: .weekOfYear, value: 1, to: week) ?? week
      return (week, fired.filter { ($0.triggeredAt ?? .distantPast) >= week && ($0.triggeredAt ?? .distantPast) < end }.count)
    }
  }

  /// Stocks whose plans are missing a piece.
  var gaps: [Gap] {
    holdings.flatMap { holding -> [Gap] in
      let kinds = Set(holding.activeAlerts.map(\.kind))
      var gaps: [Gap] = []
      if !kinds.contains(.buyZone) && !kinds.contains(.priceBelow) { gaps.append(Gap(holding: holding, missing: "buy zone")) }
      if holding.isOwned && !kinds.contains(.sellZone) && !kinds.contains(.priceAbove) { gaps.append(Gap(holding: holding, missing: "sell zone")) }
      if holding.isOwned && !kinds.contains(.trailingStop) && !kinds.contains(.belowAverage) { gaps.append(Gap(holding: holding, missing: "protection")) }
      return gaps
    }
  }

  private func average(_ values: [Double]) -> Double? {
    values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
  }

  private func rate(_ outcomes: [Outcome], where test: (Outcome) -> Bool) -> Double? {
    outcomes.isEmpty ? nil : Double(outcomes.filter(test).count) / Double(outcomes.count)
  }
}
