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
  var price: Double
  var dayChange: Double
  var target: Double
  var targetKind: TargetKind
  var history: [Double]

  var value: Double { shares * price }

  /// Fractional distance from the current price to the target (0 means the target is hit).
  var distanceToTarget: Double {
    switch targetKind {
    case .buyBelow: max(0, (price - target) / price)
    case .sellAbove: max(0, (target - price) / price)
    }
  }

  /// Progress toward the target on a 0–1 scale, treating 20% away as the starting point.
  var targetProgress: Double {
    1 - min(distanceToTarget / 0.2, 1)
  }
}
