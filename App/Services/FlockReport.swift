import Foundation

/// Everything the flock is doing on one stock, computed from anonymous alerts.
struct FlockReport {
  struct Bin: Identifiable, Equatable {
    var lowerOffset: Double
    var buyCount: Int
    var sellCount: Int

    var id: Double { lowerOffset }
    var midOffset: Double { lowerOffset + FlockReport.binWidth / 2 }
    var total: Int { buyCount + sellCount }
  }

  static let binWidth = 0.025
  static let offsetRange = -0.30...0.30
  /// Below this many alerts, statistics would be misleading and could identify individuals.
  static let minimumSample = 5

  var symbol: String
  var currentPrice: Double
  var entries: [FlockEntry]
  var votes: FlockVotes
  var related: [RelatedSymbol]
  var isSample: Bool
  var now: Date = .now

  var active: [FlockEntry] { entries.filter(\.isActive) }
  var hasEnoughData: Bool { active.count >= Self.minimumSample }
  var watcherCount: Int { Set(active.map(\.installID)).count }

  var buyLevels: [Double] { active.filter { $0.kind.side == .buy }.compactMap(\.referencePrice) }
  var sellLevels: [Double] { active.filter { $0.kind.side == .sell }.compactMap(\.referencePrice) }

  var buyShare: Double {
    let sides = active.map(\.kind.side).filter { $0 != .watch }
    guard !sides.isEmpty else { return 0.5 }
    return Double(sides.filter { $0 == .buy }.count) / Double(sides.count)
  }

  var medianBuy: Double? { Self.quantile(buyLevels, 0.5) }
  var medianSell: Double? { Self.quantile(sellLevels, 0.5) }
  var averageBuy: Double? { buyLevels.isEmpty ? nil : buyLevels.reduce(0, +) / Double(buyLevels.count) }
  var averageSell: Double? { sellLevels.isEmpty ? nil : sellLevels.reduce(0, +) / Double(sellLevels.count) }

  /// The middle half of buy targets: where the crowd plans to buy.
  var buyZone: ClosedRange<Double>? {
    guard buyLevels.count >= 4, let low = Self.quantile(buyLevels, 0.25), let high = Self.quantile(buyLevels, 0.75) else { return nil }
    return low...max(low, high)
  }

  var sellZone: ClosedRange<Double>? {
    guard sellLevels.count >= 4, let low = Self.quantile(sellLevels, 0.25), let high = Self.quantile(sellLevels, 0.75) else { return nil }
    return low...max(low, high)
  }

  var isInBuyZone: Bool { buyZone?.contains(currentPrice) ?? false }

  var bins: [Bin] {
    let lower = Self.offsetRange.lowerBound
    let count = Int(((Self.offsetRange.upperBound - lower) / Self.binWidth).rounded())
    var bins = (0..<count).map { Bin(lowerOffset: lower + Double($0) * Self.binWidth, buyCount: 0, sellCount: 0) }
    func index(for level: Double) -> Int? {
      guard currentPrice > 0 else { return nil }
      let offset = level / currentPrice - 1
      guard Self.offsetRange.contains(offset) else { return nil }
      return min(count - 1, Int((offset - lower) / Self.binWidth))
    }
    for level in buyLevels { if let i = index(for: level) { bins[i].buyCount += 1 } }
    for level in sellLevels { if let i = index(for: level) { bins[i].sellCount += 1 } }
    return bins
  }

  /// The price level where the most alerts cluster.
  var crowdedLevel: Double? {
    guard let bin = bins.max(by: { $0.total < $1.total }), bin.total > 0 else { return nil }
    return currentPrice * (1 + bin.midOffset)
  }

  var nearPriceCount: Int {
    (buyLevels + sellLevels).filter { abs($0 / currentPrice - 1) <= 0.05 }.count
  }

  // MARK: Momentum

  var alertsThisWeek: Int { entries.filter { now.timeIntervalSince($0.createdAt) < FlockCalendar.week }.count }

  var alertsLastWeek: Int {
    entries.filter {
      let age = now.timeIntervalSince($0.createdAt)
      return age >= FlockCalendar.week && age < 2 * FlockCalendar.week
    }.count
  }

  var weekChange: Double {
    alertsLastWeek == 0 ? (alertsThisWeek > 0 ? 1 : 0) : Double(alertsThisWeek) / Double(alertsLastWeek) - 1
  }

  /// New alerts per week for the last eight weeks, oldest first.
  var weeklyActivity: [Int] {
    (0..<8).reversed().map { weeksAgo in
      entries.filter {
        let age = now.timeIntervalSince($0.createdAt)
        return age >= Double(weeksAgo) * FlockCalendar.week && age < Double(weeksAgo + 1) * FlockCalendar.week
      }.count
    }
  }

  var triggeredLast24h: Int {
    entries.filter { $0.triggeredAt.map { now.timeIntervalSince($0) < 24 * 3600 } ?? false }.count
  }

  var mix: [(kind: AlertKind, count: Int)] {
    let counts = Dictionary(grouping: active, by: \.kind).mapValues(\.count)
    return AlertKind.allCases.compactMap { kind in counts[kind].map { (kind, $0) } }.sorted { $0.count > $1.count }
  }

  var feed: [FlockEvent] {
    let created = entries.map { FlockEvent(symbol: symbol, entry: $0, isTrigger: false, date: $0.createdAt) }
    let triggered = entries.compactMap { entry in entry.triggeredAt.map { FlockEvent(symbol: symbol, entry: entry, isTrigger: true, date: $0) } }
    return (created + triggered).sorted { $0.date > $1.date }.prefix(15).map { $0 }
  }

  /// How the flock's buy alerts have done since they fired.
  var trackRecord: FlockTrackRecord? {
    let cutoff = now.addingTimeInterval(-180 * 24 * 3600)
    let returns = entries
      .filter { $0.kind.side == .buy && ($0.triggeredAt ?? .distantPast) > cutoff }
      .compactMap { entry in entry.triggeredPrice.map { currentPrice / $0 - 1 } }
    guard returns.count >= 3 else { return nil }
    return FlockTrackRecord(
      count: returns.count,
      averageReturn: returns.reduce(0, +) / Double(returns.count),
      winRate: Double(returns.filter { $0 > 0 }.count) / Double(returns.count)
    )
  }

  // MARK: Conviction

  /// 0–100 blend of buy-side lean, weekly momentum, and how many alerts sit near the price.
  var conviction: Int {
    let momentum = min(max(weekChange, -1), 1)
    let levels = max(1, buyLevels.count + sellLevels.count)
    let proximity = min(1, Double(nearPriceCount) / Double(levels) * 2)
    let score = 100 * (0.5 * buyShare + 0.25 * (momentum + 1) / 2 + 0.25 * proximity)
    return Int(score.rounded())
  }

  var convictionLabel: String {
    switch conviction {
    case 70...: String(localized: "Strong dip demand")
    case 55..<70: String(localized: "Leaning buy")
    case 45..<55: String(localized: "Balanced")
    case 30..<45: String(localized: "Leaning sell")
    default: String(localized: "Taking profit")
    }
  }

  var convictionBlurb: String {
    let lean = buyShare.formatted(.percent.precision(.fractionLength(0)))
    let momentum = abs(weekChange).formatted(.percent.precision(.fractionLength(0)))
    return "\(lean) of alerts are buy-side, activity is \(weekChange >= 0 ? "up" : "down") \(momentum) this week, and \(nearPriceCount) alerts sit within 5% of the price."
  }

  /// Share of same-side levels that are less extreme than `level` (how patient the user is).
  func patience(of level: Double, side: TradeSide) -> Double? {
    let peers = side == .buy ? buyLevels : sellLevels
    guard peers.count >= Self.minimumSample, side != .watch else { return nil }
    let lessPatient = side == .buy ? peers.filter { $0 > level }.count : peers.filter { $0 < level }.count
    return Double(lessPatient) / Double(peers.count)
  }

  static func quantile(_ values: [Double], _ q: Double) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let position = q * Double(sorted.count - 1)
    let lower = Int(position.rounded(.down))
    let upper = Int(position.rounded(.up))
    let fraction = position - Double(lower)
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction
  }
}
