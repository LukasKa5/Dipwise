import Foundation

/// A ready-made set of alerts the plan builder can apply in one tap.
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
    case .dipHunter: "Three buy tiers and big-move alerts"
    case .balanced: "Buy tiers, a sell zone, and a trailing stop"
    case .protectGains: "Sell zone, trailing stop, trend break"
    case .dividendBuilder: "Patient deep buys for long-term income"
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
    case gentle, standard, deep
    var id: Self { self }
    var title: String { rawValue.capitalized }
    /// Distance between buy tiers.
    var step: Double {
      switch self {
      case .gentle: 0.03
      case .standard: 0.05
      case .deep: 0.08
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
    var title: String {
      "+\(Int(range.lowerBound * 100))–\(Int(range.upperBound * 100))%"
    }
  }

  var buyTiers = 2
  var depth: Depth = .standard
  var budget: Double = 0
  var sellZone = true
  var sellTarget: SellTarget = .medium
  var trailingStop = false
  var dropFromHigh = false
  var dailyMove = false
  var belowAverage = false

  init() {}

  init(template: PlanTemplate) {
    switch template {
    case .dipHunter:
      buyTiers = 3; depth = .standard; sellZone = false; dailyMove = true
    case .balanced:
      buyTiers = 2; depth = .standard; sellZone = true; sellTarget = .medium; trailingStop = true
    case .protectGains:
      buyTiers = 0; sellZone = true; sellTarget = .near; trailingStop = true; belowAverage = true
    case .dividendBuilder:
      buyTiers = 2; depth = .deep; sellZone = false; dropFromHigh = true
    }
  }

  func rules(price: Double, round: (Double) -> Double) -> [(rule: AlertRule, budget: Double)] {
    var rules: [(AlertRule, Double)] = []
    let width = 0.03
    for tier in 0..<buyTiers {
      let top = 1 - depth.step * Double(tier + 1)
      rules.append((AlertRule(kind: .buyZone, lower: round(price * (top - width)), upper: round(price * top)), buyTiers > 0 ? budget / Double(buyTiers) : 0))
    }
    if sellZone {
      rules.append((AlertRule(kind: .sellZone, lower: round(price * (1 + sellTarget.range.lowerBound)), upper: round(price * (1 + sellTarget.range.upperBound))), 0))
    }
    if trailingStop { rules.append((AlertRule(kind: .trailingStop, percent: 0.08, peak: price), 0)) }
    if dropFromHigh { rules.append((AlertRule(kind: .dropFromHigh, percent: 0.2), 0)) }
    if dailyMove { rules.append((AlertRule(kind: .dailyMove, percent: 0.05), 0)) }
    if belowAverage { rules.append((AlertRule(kind: .belowAverage, averageDays: 200), 0)) }
    return rules
  }
}
