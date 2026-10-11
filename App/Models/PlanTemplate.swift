import Foundation

/// A ready-made plan the builder can apply in one tap.
enum PlanTemplate: String, CaseIterable, Identifiable {
  case dipHunter
  case balanced
  case protectGains
  case dividendBuilder

  var id: Self { self }

  var title: String {
    switch self {
    case .dipHunter: "Dip hunter"
    case .balanced: "Balanced"
    case .protectGains: "Protect gains"
    case .dividendBuilder: "Income builder"
    }
  }

  var subtitle: String {
    switch self {
    case .dipHunter: "Buy zone, oversold and fast-drop alerts"
    case .balanced: "Buy and sell zones with a trailing stop"
    case .protectGains: "Sell zone, stop loss, trend warnings"
    case .dividendBuilder: "Patient buys plus dividend reminders"
    }
  }

  var systemImage: String {
    switch self {
    case .dipHunter: "scope"
    case .balanced: "scalemass.fill"
    case .protectGains: "shield.lefthalf.filled"
    case .dividendBuilder: "leaf.fill"
    }
  }
}

/// The choices in the plan builder, turned into alert rules.
struct PlanDraft: Equatable {
  enum Depth: String, CaseIterable, Identifiable {
    case shallow, standard, deep
    var id: Self { self }
    var title: String {
      switch self {
      case .shallow: "−3 to −7%"
      case .standard: "−5 to −10%"
      case .deep: "−10 to −18%"
      }
    }
    var range: ClosedRange<Double> {
      switch self {
      case .shallow: 0.03...0.07
      case .standard: 0.05...0.10
      case .deep: 0.10...0.18
      }
    }
  }

  enum SellTarget: String, CaseIterable, Identifiable {
    case near, medium, far
    var id: Self { self }
    var range: ClosedRange<Double> {
      switch self {
      case .near: 0.08...0.15
      case .medium: 0.15...0.25
      case .far: 0.25...0.40
      }
    }
    var title: String { "+\(Int(range.lowerBound * 100))–\(Int(range.upperBound * 100))%" }
  }

  var buyZone = true
  var depth: Depth = .standard
  var budget: Double = 0
  var sellZone = true
  var sellTarget: SellTarget = .medium
  var smart: Set<AlertKind> = []

  init() {}

  init(template: PlanTemplate) {
    switch template {
    case .dipHunter:
      buyZone = true; depth = .standard; sellZone = false; smart = [.rsiOversold, .weeklyDrop]
    case .balanced:
      buyZone = true; sellZone = true; smart = [.trailingStop]
    case .protectGains:
      buyZone = false; sellZone = true; sellTarget = .near; smart = [.stopLoss, .belowAverage, .deathCross]
    case .dividendBuilder:
      buyZone = true; depth = .deep; sellZone = false; smart = [.dropFromHigh, .dividendSoon]
    }
  }

  func rules(price: Double, cost: Double, round: (Double) -> Double) -> [(rule: AlertRule, budget: Double)] {
    var rules: [(AlertRule, Double)] = []
    if buyZone {
      rules.append((AlertRule(kind: .buyZone, lower: round(price * (1 - depth.range.upperBound)), upper: round(price * (1 - depth.range.lowerBound))), budget))
    }
    if sellZone {
      rules.append((AlertRule(kind: .sellZone, lower: round(price * (1 + sellTarget.range.lowerBound)), upper: round(price * (1 + sellTarget.range.upperBound))), 0))
    }
    for kind in AlertKind.smart where smart.contains(kind) {
      rules.append((AlertRule.defaults(for: kind, price: price, cost: cost), 0))
    }
    return rules
  }
}
