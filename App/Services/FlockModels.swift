import Foundation

/// One anonymous alert shared by a Dipwise investor.
struct FlockEntry: Hashable, Sendable {
  var kind: AlertKind
  var lower: Double
  var upper: Double = 0
  var percent: Double = 0
  var createdAt: Date
  var triggeredAt: Date?
  var triggeredPrice: Double?
  var installID: String
  var isActive: Bool

  var rule: AlertRule { AlertRule(kind: kind, lower: lower, upper: upper, percent: percent) }
  var referencePrice: Double? { rule.referencePrice }
}

struct FlockVotes: Hashable, Sendable {
  var bullish: Int
  var bearish: Int

  var total: Int { bullish + bearish }
  var bullShare: Double { total == 0 ? 0.5 : Double(bullish) / Double(total) }
}

struct RelatedSymbol: Identifiable, Hashable, Sendable {
  var symbol: String
  /// Share of this stock's watchers who also watch `symbol`.
  var overlap: Double

  var id: String { symbol }
}

struct FlockEvent: Identifiable, Hashable {
  var id = UUID()
  var symbol: String
  var entry: FlockEntry
  var isTrigger: Bool
  var date: Date

  var systemImage: String { isTrigger ? "checkmark.seal.fill" : entry.kind.systemImage }

  func text(format: (Double) -> String) -> String {
    let rule = entry.rule
    let percent = rule.percent.formatted(.percent.precision(.fractionLength(0)))
    if isTrigger {
      let price = entry.triggeredPrice.map(format) ?? ""
      switch entry.kind.side {
      case .buy: return "\(entry.kind.title) hit at \(price)"
      case .sell: return "\(entry.kind.title) reached at \(price)"
      case .watch: return "Big move alert fired at \(price)"
      }
    }
    switch entry.kind {
    case .buyZone: return "Set a buy zone at \(format(rule.lower))–\(format(rule.upper))"
    case .sellZone: return "Set a sell zone at \(format(rule.lower))–\(format(rule.upper))"
    case .priceBelow: return "Waiting to buy below \(format(rule.lower))"
    case .priceAbove: return "Plans to sell above \(format(rule.lower))"
    case .dropFromHigh: return "Watching for a \(percent) dip from the high"
    case .dailyMove: return "Watching for \(percent) daily moves"
    case .trailingStop: return "Protecting gains with a \(percent) trailing stop"
    case .belowAverage: return "Watching the long-term average"
    }
  }
}

struct FlockTrackRecord: Hashable {
  var count: Int
  var averageReturn: Double
  var winRate: Double
}

struct TrendingSymbol: Identifiable, Hashable {
  var symbol: String
  var alertsThisWeek: Int
  var weekChange: Double
  var buyShare: Double

  var id: String { symbol }
}

/// A stock currently trading inside the flock's buy zone.
struct RadarItem: Identifiable, Hashable {
  var symbol: String
  var name: String
  var price: Double
  var currency: String
  var buyZone: ClosedRange<Double>
  var conviction: Int
  var watchers: Int

  var id: String { symbol }
}

struct FlockOverview {
  var trending: [TrendingSymbol] = []
  var feed: [FlockEvent] = []
  var mood = FlockVotes(bullish: 0, bearish: 0)
  var investors = 0
  var alertsThisWeek = 0
  var isSample = false
}

enum FlockCalendar {
  /// ISO week identifier like "2026-W41", used to group weekly votes.
  static func weekKey(for date: Date = .now) -> String {
    let calendar = Calendar(identifier: .iso8601)
    let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
    return "\(components.yearForWeekOfYear ?? 0)-W\(components.weekOfYear ?? 0)"
  }

  static let week: TimeInterval = 7 * 24 * 3600
}
