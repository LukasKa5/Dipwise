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

  func rules(price: Double, cost: Double) -> [(rule: AlertRule, budget: Double)] {
    var rules: [(AlertRule, Double)] = []
    if buyZone, buyUpper > buyLower, buyLower > 0 {
      rules.append((AlertRule(kind: .buyZone, lower: buyLower, upper: buyUpper), budget))
    }
    if sellZone, sellUpper > sellLower, sellLower > 0 {
      rules.append((AlertRule(kind: .sellZone, lower: sellLower, upper: sellUpper), 0))
    }
    for kind in AlertKind.smart where smart.contains(kind) {
      rules.append((AlertRule.defaults(for: kind, price: price, cost: cost), 0))
    }
    return rules
  }
}
