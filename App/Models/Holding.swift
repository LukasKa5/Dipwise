import Foundation
import SwiftData

/// A stock the user owns or watches. Shares of zero means it's watch-only.
@Model
final class Holding {
  var symbol: String = ""
  var name: String = ""
  var shares: Double = 0
  /// Average purchase price per share, or zero when unknown.
  var averageCost: Double = 0
  var addedAt: Date = Date.now
  @Relationship(deleteRule: .cascade, inverse: \PriceAlert.holding)
  var alerts: [PriceAlert]? = []

  init(symbol: String, name: String, shares: Double = 0, averageCost: Double = 0) {
    self.symbol = symbol
    self.name = name
    self.shares = shares
    self.averageCost = averageCost
  }

  var activeAlerts: [PriceAlert] {
    (alerts ?? []).filter(\.isActive).sorted { $0.createdAt < $1.createdAt }
  }

  /// Buy tiers, nearest to the price first.
  var buyZones: [PriceAlert] { activeAlerts.filter { $0.kind == .buyZone }.sorted { $0.upperPrice > $1.upperPrice } }
  /// Sell tiers, nearest to the price first.
  var sellZones: [PriceAlert] { activeAlerts.filter { $0.kind == .sellZone }.sorted { $0.targetPrice < $1.targetPrice } }
  var buyZone: PriceAlert? { buyZones.first }
  var sellZone: PriceAlert? { sellZones.first }

  /// What happens if every funded buy tier fills at its midpoint.
  var ladder: (budget: Double, shares: Double, averagePrice: Double)? {
    let funded = buyZones.filter { $0.budget > 0 && ($0.rule.referencePrice ?? 0) > 0 }
    guard !funded.isEmpty else { return nil }
    let budget = funded.reduce(0) { $0 + $1.budget }
    let shares = funded.reduce(0) { $0 + $1.budget / ($1.rule.referencePrice ?? 1) }
    return (budget, shares, budget / shares)
  }

  var isOwned: Bool { shares > 0 }

  func value(at price: Double) -> Double { shares * price }

  var costBasis: Double { shares * averageCost }

  /// Unrealized gain as a fraction of cost, when the cost is known.
  func gain(at price: Double) -> Double? {
    guard averageCost > 0, shares > 0 else { return nil }
    return price / averageCost - 1
  }
}
