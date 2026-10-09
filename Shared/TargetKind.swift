import Foundation

/// Which side of the market an alert watches.
enum TargetKind: String, Codable, CaseIterable, Identifiable {
  case buyBelow
  case sellAbove

  var id: Self { self }

  var title: String {
    switch self {
    case .buyBelow: "Buy below"
    case .sellAbove: "Sell above"
    }
  }

  var shortTitle: String {
    switch self {
    case .buyBelow: "Buy"
    case .sellAbove: "Sell"
    }
  }

  var systemImage: String {
    switch self {
    case .buyBelow: "arrow.down.to.line"
    case .sellAbove: "arrow.up.to.line"
    }
  }

  /// Fractional distance from `price` to `target` (0 means the target is reached).
  func distance(from price: Double, to target: Double) -> Double {
    guard price > 0 else { return 0 }
    switch self {
    case .buyBelow: return max(0, (price - target) / price)
    case .sellAbove: return max(0, (target - price) / price)
    }
  }

  func isReached(price: Double, target: Double) -> Bool {
    switch self {
    case .buyBelow: price <= target
    case .sellAbove: price >= target
    }
  }

  /// Progress toward the target on a 0–1 scale, treating `span` away as the starting point.
  func progress(from price: Double, to target: Double, span: Double = 0.2) -> Double {
    1 - min(distance(from: price, to: target) / span, 1)
  }
}
