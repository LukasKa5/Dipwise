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

  /// Every sharing member's portfolio mix, and a year of their moves.
  private(set) var portfolios: [FlockPortfolio] = []
  private(set) var moves: [FlockMove] = []
  private(set) var ownership: [OwnershipStat] = []
  private(set) var flows: [FlowStat] = []
  private(set) var leaders: [FlockInvestor] = []
  /// Investors the user follows, by anonymous ID.
  private(set) var following: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "flock.following") ?? [])

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
    await loadPortfolios()
    await loadRadar()
  }

  // MARK: Portfolios

  /// Loads what the flock owns and does, and works out ownership, this week's buying and selling, and the leaders.
  func loadPortfolios() async {
    guard let backend else { return }
    guard let portfolios = try? await backend.portfolios() else { return }
    let moves = (try? await backend.moves(days: 365)) ?? []
    self.portfolios = portfolios
    self.moves = moves
    // Crowd views need a real crowd: it keeps everyone anonymous and the numbers meaningful.
    let enoughMembers = portfolios.count >= FlockInsights.minimumMembers
    ownership = enoughMembers ? FlockInsights.ownership(portfolios).filter { $0.holders >= FlockInsights.minimumGroup } : []
    flows = enoughMembers ? FlockInsights.flows(moves).filter { $0.total >= FlockInsights.minimumGroup } : []
    leaders = portfolios.count >= FlockInsights.minimumMembersForLeaders ? FlockInsights.leaders(portfolios, moves: moves) : []
    await notifyFollowedMoves()
  }

  func investor(_ id: String) -> FlockInvestor? {
    leaders.first { $0.id == id } ?? portfolios.first { $0.installID == id }.map { portfolio in
      FlockInvestor(portfolio: portfolio, moves: moves.filter { $0.installID == id }.sorted { $0.date > $1.date })
    }
  }

  func ownership(of symbol: String) -> OwnershipStat? {
    ownership.first { $0.symbol == symbol }
  }

  func flow(of symbol: String) -> FlowStat? {
    flows.first { $0.symbol == symbol }
  }

  /// The leaders who own this stock, best first.
  func leaders(holding symbol: String) -> [FlockInvestor] {
    leaders.filter { $0.portfolio.weight(of: symbol) != nil }
  }

  /// What the crowd knows about a stock, for Flock alerts.
  func crowdFacts(for symbol: String) -> CrowdFacts {
    let flow = flow(of: symbol)
    let dayAgo = Date.now.addingTimeInterval(-24 * 3600)
    let topBuys = leaders.filter { investor in
      investor.moves.contains { $0.symbol == symbol && $0.isBuy && $0.date > dayAgo }
    }.count
    return CrowdFacts(buyZone: reports[symbol]?.buyZone, buyShare: flow?.buyShare ?? 0.5, movers: flow?.total ?? 0, topInvestorBuysToday: topBuys)
  }

  /// Loads what Flock alerts need for these stocks.
  func crowdFacts(for symbols: [String], quotes: [String: Quote]) async -> [String: CrowdFacts] {
    guard isAvailable, !symbols.isEmpty else { return [:] }
    if portfolios.isEmpty { await loadPortfolios() }
    var facts: [String: CrowdFacts] = [:]
    for symbol in Set(symbols) {
      if let price = quotes[symbol]?.price { await load(symbol: symbol, currentPrice: price) }
      facts[symbol] = crowdFacts(for: symbol)
    }
    return facts
  }

  func dipBehavior(for quote: Quote) -> DipBehavior? {
    FlockInsights.dipBehavior(symbol: quote.symbol, closes: quote.closes, dates: quote.dates, moves: moves)
  }

  // MARK: Following

  func isFollowing(_ id: String) -> Bool { following.contains(id) }

  func toggleFollow(_ id: String) {
    if following.contains(id) { following.remove(id) } else { following.insert(id) }
    UserDefaults.standard.set(Array(following), forKey: "flock.following")
    // Only moves made from now on are news.
    UserDefaults.standard.set(Date.now, forKey: "flock.followSeen")
  }

  /// Notifies Pro members about new moves by the investors they follow.
  private func notifyFollowedMoves() async {
    guard AlertSettings.isPro, !following.isEmpty else { return }
    let key = "flock.followSeen"
    let seen = UserDefaults.standard.object(forKey: key) as? Date ?? .now
    let fresh = moves.filter { following.contains($0.installID) && $0.date > seen && $0.date <= .now }
    UserDefaults.standard.set(Date.now, forKey: key)
    if !fresh.isEmpty { await NotificationManager.post(followed: fresh) }
  }

  // MARK: Sharing the portfolio mix

  /// Shares the user's portfolio mix (weights only) and any adds or trims since last time, if they opted in.
  func syncPortfolio(holdings: [(symbol: String, shares: Double)], quotes: [String: Quote]) async {
    guard let backend, AlertSettings.sharePortfolio else { return }
    let installID = FlockConfiguration.installID
    let current = Dictionary(holdings.filter { $0.shares > 0 }.map { ($0.symbol, $0.shares) }, uniquingKeysWith: +)
    let previous = UserDefaults.standard.dictionary(forKey: "flock.sharedShares") as? [String: Double]
    // The first share is a snapshot, not a burst of moves.
    if let previous {
      for symbol in Set(current.keys).union(previous.keys) {
        let now = current[symbol] ?? 0
        let before = previous[symbol] ?? 0
        guard abs(now - before) > max(0.0001, before * 0.001) else { continue }
        try? await backend.publish(move: FlockMove(installID: installID, symbol: symbol, isBuy: now > before, date: .now))
      }
    }
    let lastPublish = UserDefaults.standard.object(forKey: "flock.portfolioPublished") as? Date ?? .distantPast
    guard previous != current || Date.now.timeIntervalSince(lastPublish) > 24 * 3600,
          let snapshot = FlockInsights.snapshot(installID: installID, holdings: holdings, quotes: quotes) else { return }
    try? await backend.publish(portfolio: snapshot)
    UserDefaults.standard.set(current, forKey: "flock.sharedShares")
    UserDefaults.standard.set(Date.now, forKey: "flock.portfolioPublished")
  }

  /// Removes the user's portfolio mix and moves from the flock.
  func withdrawPortfolio() async {
    UserDefaults.standard.removeObject(forKey: "flock.sharedShares")
    UserDefaults.standard.removeObject(forKey: "flock.portfolioPublished")
    try? await backend?.withdrawPortfolio(installID: FlockConfiguration.installID)
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

  /// Shares the crowd's picks and mood with the Flock widgets.
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
    WidgetCenter.shared.reloadTimelines(ofKind: "FlockZonesWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "FlockMoodWidget")
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
