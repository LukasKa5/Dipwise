import Foundation

/// The choices in the multi-alert builder.
struct PlanDraft: Equatable {
  var buyZone = true
  var buyLower = 0.0
  var buyUpper = 0.0
  var budget: Double = 0
  var sellZone = true
  var sellLower = 0.0
  var sellUpper = 0.0
  var smart: Set<AlertKind> = []
  /// Thresholds people set themselves, by alert. Missing ones use Dippy's defaults.
  var thresholds: [AlertKind: Double] = [:]

  func rules(price: Double, cost: Double) -> [(rule: AlertRule, budget: Double)] {
    var rules: [(AlertRule, Double)] = []
    if buyZone, buyUpper > buyLower, buyLower > 0 {
      rules.append((AlertRule(kind: .buyZone, lower: buyLower, upper: buyUpper), budget))
    }
    if sellZone, sellUpper > sellLower, sellLower > 0 {
      rules.append((AlertRule(kind: .sellZone, lower: sellLower, upper: sellUpper), 0))
    }
    for kind in AlertKind.smart where smart.contains(kind) {
      var rule = AlertRule.defaults(for: kind, price: price, cost: cost)
      if let tuning = kind.tuning, let value = thresholds[kind] { tuning.apply(value, to: &rule) }
      rules.append((rule, 0))
    }
    return rules
  }
}

extension PlanDraft {
  /// Dippy's recommended set for a stock: a buy zone, the alerts dip buyers rely on most, and for stocks you own,
  /// a trailing stop and an average-down chance.
  static func recommendedSmart(isOwned: Bool, paysDividends: Bool) -> [AlertKind] {
    var kinds: [AlertKind] = [.dropFromHigh, .rsiOversold, .newLow, .goldenCross]
    if paysDividends { kinds.append(.dividendSoon) }
    if isOwned { kinds += [.trailingStop, .averageDown] }
    return kinds
  }
}
