import Foundation

/// When the US stock market is open, so Dippy can sleep while it's closed.
enum MarketClock {
  static func isOpen(at date: Date = .now) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
    let weekday = calendar.component(.weekday, from: date)
    guard (2...6).contains(weekday) else { return false }
    let minutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    return minutes >= 9 * 60 + 30 && minutes < 16 * 60
  }
}

/// Dippy's mood, from the market and the user's day.
enum OwlMood: Equatable {
  case sleeping
  case celebrating
  case reassuring
  case calm

  static func current(dayChange: Double?, isAwake: Bool = false) -> OwlMood {
    if !MarketClock.isOpen() && !isAwake { return .sleeping }
    guard let dayChange else { return .calm }
    if dayChange >= 0.01 { return .celebrating }
    if dayChange <= -0.01 { return .reassuring }
    return .calm
  }

  func message(change: Double?) -> String {
    switch self {
    case .sleeping: "Markets are closed. Dippy is resting, but your alerts aren't."
    case .celebrating: "Great day! Up \((change ?? 0).formatted(.percent.precision(.fractionLength(1))))."
    case .reassuring: "A red day. Dips are where good plans pay off."
    case .calm: "All quiet. Dippy is watching your zones."
    }
  }
}
