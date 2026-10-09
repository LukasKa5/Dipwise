import Foundation

struct Holding: Identifiable {
  enum TargetKind: String {
    case buyBelow
    case sellAbove
  }

  var id: String { symbol }
  var symbol: String
  var name: String
  var shares: Double
  var target: Double
  var targetKind: TargetKind
  /// Daily closing prices, oldest first. The last value is the current price.
  var history: [Double]

  var price: Double { history.last ?? 0 }
  var value: Double { shares * price }

  var dayChange: Double {
    guard history.count >= 2, history[history.count - 2] != 0 else { return 0 }
    return price / history[history.count - 2] - 1
  }

  /// Fractional distance from the current price to the target (0 means the target is hit).
  var distanceToTarget: Double {
    guard price > 0 else { return 0 }
    switch targetKind {
    case .buyBelow: return max(0, (price - target) / price)
    case .sellAbove: return max(0, (target - price) / price)
    }
  }

  /// Progress toward the target on a 0–1 scale, treating 20% away as the starting point.
  var targetProgress: Double {
    1 - min(distanceToTarget / 0.2, 1)
  }

  var isNearTarget: Bool { distanceToTarget < 0.035 }

  var targetDescription: String {
    let formatted = target.formatted(.currency(code: "USD"))
    switch targetKind {
    case .buyBelow: return "Buy below \(formatted)"
    case .sellAbove: return "Sell above \(formatted)"
    }
  }
}
