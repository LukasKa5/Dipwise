import Foundation
import WidgetKit
import Observation

/// Loads anonymous flock reports and shares the user's own alerts and votes when they opt in.
@MainActor
@Observable
final class FlockService {
  private let backend = FlockConfiguration.makeBackend()
  private let quoteService = QuoteService()
  private(set) var reports: [String: FlockReport] = [:]
  private(set) var overview = FlockOverview()
  private(set) var radar: [RadarItem] = []
  private(set) var isLoadingOverview = false
  private var loading: Set<String> = []

  var isAvailable: Bool { backend != nil }
  var isSample: Bool { backend?.isSample ?? false }

  // MARK: Reports

  func load(symbol: String, currentPrice: Double, force: Bool = false) async {
    guard let backend, currentPrice > 0, !loading.contains(symbol) else { return }
    if !force, let existing = reports[symbol], Date.now.timeIntervalSince(existing.now) < 120 { return }
    loading.insert(symbol)
    defer { loading.remove(symbol) }
    guard let entries = try? await backend.entries(for: symbol, near: currentPrice) else { return }
    let votes = (try? await backend.votes(for: symbol, week: FlockCalendar.weekKey())) ?? FlockVotes(bullish: 0, bearish: 0)
    let watchers = Array(Set(entries.filter(\.isActive).map(\.installID)))
    let related = (try? await backend.related(to: symbol, watchers: watchers)) ?? []
    reports[symbol] = FlockReport(symbol: symbol, currentPrice: currentPrice, entries: entries, votes: votes, related: related, isSample: backend.isSample)
  }

  // MARK: Overview

  func loadOverview() async {
    guard let backend, !isLoadingOverview else { return }
    isLoadingOverview = true
    defer { isLoadingOverview = false }
    guard let recent = try? await backend.recentEntries(days: 14) else { return }

    let now = Date.now
    let bySymbol = Dictionary(grouping: recent, by: \.symbol)
    let trending = bySymbol.map { symbol, items -> TrendingSymbol in
      let thisWeek = items.filter { now.timeIntervalSince($0.entry.createdAt) < FlockCalendar.week }
      let lastWeek = items.count - thisWeek.count
      let sides = thisWeek.map(\.entry.kind.side).filter { $0 != .watch }
      return TrendingSymbol(
        symbol: symbol,
        alertsThisWeek: thisWeek.count,
        weekChange: lastWeek == 0 ? 1 : Double(thisWeek.count) / Double(lastWeek) - 1,
        buyShare: sides.isEmpty ? 0.5 : Double(sides.filter { $0 == .buy }.count) / Double(sides.count)
      )
    }
    .sorted { $0.alertsThisWeek > $1.alertsThisWeek }

    let created = recent.map { FlockEvent(symbol: $0.symbol, entry: $0.entry, isTrigger: false, date: $0.entry.createdAt) }
    let triggered = recent.compactMap { item in item.entry.triggeredAt.map { FlockEvent(symbol: item.symbol, entry: item.entry, isTrigger: true, date: $0) } }
    let thisWeek = recent.filter { now.timeIntervalSince($0.entry.createdAt) < FlockCalendar.week }

    overview = FlockOverview(
      trending: Array(trending.prefix(12)),
      feed: (created + triggered).filter { $0.date <= now }.sorted { $0.date > $1.date }.prefix(30).map { $0 },
      mood: (try? await backend.votes(for: nil, week: FlockCalendar.weekKey())) ?? FlockVotes(bullish: 0, bearish: 0),
      investors: Set(recent.map(\.entry.installID)).count,
      alertsThisWeek: thisWeek.count,
      isSample: backend.isSample
    )
    await loadRadar()
  }

  /// Finds trending stocks that are trading inside the flock's buy zone right now.
  private func loadRadar() async {
    let symbols = overview.trending.prefix(12).map(\.symbol)
    let quotes = await quoteService.quotes(for: symbols)
    var items: [RadarItem] = []
    for symbol in symbols {
      guard let quote = quotes[symbol] else { continue }
      await load(symbol: symbol, currentPrice: quote.price)
      guard let report = reports[symbol], let zone = report.buyZone else { continue }
      // Include stocks inside the zone or within 3% above it.
      guard quote.price <= zone.upperBound * 1.03 else { continue }
      items.append(RadarItem(symbol: symbol, name: quote.name, price: quote.price, currency: quote.currency,
                             buyZone: zone, conviction: report.conviction, watchers: report.watcherCount))
    }
    radar = items.sorted { $0.conviction > $1.conviction }
    publishSnapshot()
  }

  /// Shares the crowd's picks with the Flock widget.
  private func publishSnapshot() {
    FlockSnapshot(
      picks: radar.prefix(8).map {
        FlockSnapshot.Pick(symbol: $0.symbol, name: $0.name, price: $0.price, currency: $0.currency,
                           zoneLower: $0.buyZone.lowerBound, zoneUpper: $0.buyZone.upperBound, conviction: $0.conviction, watchers: $0.watchers)
      },
      trending: overview.trending.prefix(6).map { FlockSnapshot.Trend(symbol: $0.symbol, alertsThisWeek: $0.alertsThisWeek, buyShare: $0.buyShare) },
      bullShare: overview.mood.bullShare,
      investors: overview.investors,
      alertsThisWeek: overview.alertsThisWeek,
      updatedAt: .now
    ).save()
    WidgetCenter.shared.reloadTimelines(ofKind: "FlockWidget")
  }

  // MARK: Votes

  func userVote(for symbol: String) -> Bool? {
    UserDefaults.standard.object(forKey: "vote-\(symbol)-\(FlockCalendar.weekKey())") as? Bool
  }

  func vote(symbol: String, bullish: Bool) async {
    let week = FlockCalendar.weekKey()
    let previous = userVote(for: symbol)
    UserDefaults.standard.set(bullish, forKey: "vote-\(symbol)-\(week)")
    if var report = reports[symbol] {
      if let previous { if previous { report.votes.bullish -= 1 } else { report.votes.bearish -= 1 } }
      if bullish { report.votes.bullish += 1 } else { report.votes.bearish += 1 }
      reports[symbol] = report
    }
    try? await backend?.vote(symbol: symbol, bullish: bullish, week: week, installID: FlockConfiguration.installID)
  }

  // MARK: Sharing

  func share(_ alert: PriceAlert) async {
    guard let backend, AlertSettings.shareWithFlock, alert.flockRecordName == nil else { return }
    alert.flockRecordName = try? await backend.publish(
      symbol: alert.symbol, rule: alert.rule, priceAtCreation: alert.priceAtCreation, installID: FlockConfiguration.installID
    )
  }

  func withdraw(_ alert: PriceAlert) async {
    guard let backend, let recordName = alert.flockRecordName else { return }
    try? await backend.withdraw(recordName: recordName)
    alert.flockRecordName = nil
  }

  func markTriggered(_ alert: PriceAlert, price: Double) async {
    guard let backend, let recordName = alert.flockRecordName else { return }
    try? await backend.markTriggered(recordName: recordName, price: price)
  }
}
