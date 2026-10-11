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

  /// The one buy plan for this stock: a buy zone or an exact buy price.
  var buyZone: PriceAlert? { activeAlerts.first { $0.kind == .buyZone || $0.kind == .priceBelow } }
  /// The one sell plan for this stock: a sell zone or an exact sell price.
  var sellZone: PriceAlert? { activeAlerts.first { $0.kind == .sellZone || $0.kind == .priceAbove } }
  /// Smart alerts beyond the buy and sell plan.
  var smartAlerts: [PriceAlert] { activeAlerts.filter { $0.kind.requiresPro } }

  var isOwned: Bool { shares > 0 }

  func value(at price: Double) -> Double { shares * price }

  var costBasis: Double { shares * averageCost }

  /// Unrealized gain as a fraction of cost, when the cost is known.
  func gain(at price: Double) -> Double? {
    guard averageCost > 0, shares > 0 else { return nil }
    return price / averageCost - 1
  }
}
