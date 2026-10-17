import Foundation

/// When the US stock market is open, so Dippy can sleep while it's closed.
enum MarketClock {
  private static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
    return calendar
  }

  /// When the market next opens, or closes if it's open now.
  static func nextChange(after date: Date = .now) -> Date {
    let calendar = Self.calendar
    if isOpen(at: date) {
      return calendar.date(bySettingHour: 16, minute: 0, second: 0, of: date) ?? date
    }
    for day in 0..<8 {
      guard let candidateDay = calendar.date(byAdding: .day, value: day, to: date),
            let open = calendar.date(bySettingHour: 9, minute: 30, second: 0, of: candidateDay) else { continue }
      let weekday = calendar.component(.weekday, from: open)
      if (2...6).contains(weekday) && open > date { return open }
    }
    return date.addingTimeInterval(86_400)
  }

  static func isOpen(at date: Date = .now) -> Bool {
    let calendar = Self.calendar
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
    case .sleeping: String(localized: "Markets are closed. Dippy is resting, but your alerts aren't.")
    case _ where !MarketClock.isOpen(): String(localized: "Markets are closed. Dippy is awake and keeping watch.")
    case .celebrating: String(localized: "A green day. Dippy is watching your zones.")
    case .reassuring: String(localized: "A red day. Dips are where good plans pay off.")
    case .calm: String(localized: "All quiet. Dippy is watching your zones.")
    }
  }
}
