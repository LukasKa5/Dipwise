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
      case .watch: return String(localized: "Big move alert fired at \(price)")
      }
    }
    switch entry.kind {
    case .buyZone: return String(localized: "Set a buy zone at \(format(rule.lower))–\(format(rule.upper))")
    case .sellZone: return String(localized: "Set a sell zone at \(format(rule.lower))–\(format(rule.upper))")
    case .priceBelow: return String(localized: "Waiting to buy below \(format(rule.lower))")
    case .priceAbove: return String(localized: "Plans to sell above \(format(rule.lower))")
    case .dropFromHigh: return String(localized: "Watching for a \(percent) dip from the high")
    case .dailyMove: return String(localized: "Watching for \(percent) daily moves")
    case .trailingStop: return String(localized: "Protecting gains with a \(percent) trailing stop")
    case .belowAverage, .aboveAverage: return String(localized: "Watching the long-term average")
    default: return String(localized: "Set a \(entry.kind.title.lowercased()) alert")
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

// MARK: - Daily check-ins

/// What a member says they're doing with their money this week, from the daily brief. Five distinct moves an investor
/// actually makes, so the flock's answers say something real. (Raw values stay as they were, for stored check-ins.)
enum FlockAction: String, CaseIterable, Identifiable, Codable {
  case buying
  case holding
  case waiting
  case trimming
  case selling

  var id: Self { self }

  var title: String {
    switch self {
    case .buying: String(localized: "Adding money")
    case .holding: String(localized: "Holding steady")
    case .waiting: String(localized: "Building cash")
    case .trimming: String(localized: "Rebalancing")
    case .selling: String(localized: "Reducing risk")
    }
  }

  var systemImage: String {
    switch self {
    case .buying: "plus.circle.fill"
    case .holding: "pause.circle.fill"
    case .waiting: "banknote.fill"
    case .trimming: "arrow.left.arrow.right.circle.fill"
    case .selling: "shield.lefthalf.filled"
    }
  }
}

/// Where a member thinks the market is heading, from very bearish to very bullish: the scale investor sentiment surveys
/// use. Together the answers make the flock's fear and greed index.
enum FlockFeeling: Int, CaseIterable, Identifiable, Codable {
  case fearful = 0
  case worried = 25
  case calm = 50
  case confident = 75
  case greedy = 100

  var id: Self { self }

  var title: String {
    switch self {
    case .fearful: String(localized: "Very bearish")
    case .worried: String(localized: "Bearish")
    case .calm: String(localized: "Neutral")
    case .confident: String(localized: "Bullish")
    case .greedy: String(localized: "Very bullish")
    }
  }

  var systemImage: String {
    switch self {
    case .fearful: "chart.line.downtrend.xyaxis.circle.fill"
    case .worried: "arrow.down.right.circle.fill"
    case .calm: "equal.circle.fill"
    case .confident: "arrow.up.right.circle.fill"
    case .greedy: "chart.line.uptrend.xyaxis.circle.fill"
    }
  }
}

/// One member's anonymous daily check-in.
struct FlockCheckIn: Codable, Hashable {
  var day: String
  var feeling: FlockFeeling
  var action: FlockAction
}

/// The flock's own fear and greed: the average of every check-in, today and over the last month,
/// and what members say they're doing. Brokers see this about their clients; Dipwise shows it to everyone.
struct FlockSentiment: Equatable {
  struct Day: Identifiable, Equatable {
    var day: String
    var score: Double
    var count: Int
    var id: String { day }
  }

  var days: [Day]
  /// Share of today's check-ins by action.
  var actions: [FlockAction: Double]

  var today: Day? { days.last }
  var score: Double { today?.score ?? 50 }
  /// The change from a week ago, in points.
  var weekChange: Double? {
    guard days.count > 7 else { return nil }
    return score - days[days.count - 8].score
  }

  var label: String { Self.label(for: score) }

  static func label(for score: Double) -> String {
    switch score {
    case ..<20: String(localized: "Extreme fear")
    case ..<40: String(localized: "Fear")
    case ..<60: String(localized: "Neutral")
    case ..<80: String(localized: "Greed")
    default: String(localized: "Extreme greed")
    }
  }

  static func make(from checkIns: [FlockCheckIn]) -> FlockSentiment? {
    guard !checkIns.isEmpty else { return nil }
    let byDay = Dictionary(grouping: checkIns, by: \.day)
    let days = byDay.keys.sorted().map { key in
      let items = byDay[key] ?? []
      return Day(day: key, score: Double(items.map(\.feeling.rawValue).reduce(0, +)) / Double(max(items.count, 1)), count: items.count)
    }
    let latest = byDay[days.last?.day ?? ""] ?? []
    var actions: [FlockAction: Double] = [:]
    for action in FlockAction.allCases {
      actions[action] = Double(latest.filter { $0.action == action }.count) / Double(max(latest.count, 1))
    }
    return FlockSentiment(days: days, actions: actions)
  }
}

extension FlockCalendar {
  /// Today in New York, like "2026-10-26", so everyone's check-ins land on the same market day.
  static func dayKey(for date: Date = .now) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
  }
}
