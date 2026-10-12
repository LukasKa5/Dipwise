import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Receives plans, stocks, and progress from the iPhone, fetches prices on the watch, and feeds the complications.
@MainActor
@Observable
final class WatchTargetStore: NSObject {
  private(set) var targets: [WatchedTarget] = TargetSnapshotStore.loadTargets()
  private(set) var watched: [WatchedStock] = TargetSnapshotStore.loadStocks()
  private(set) var quotes: [String: Quote] = TargetSnapshotStore.loadQuotes()
  private(set) var progress = ProgressSnapshot.load()
  private(set) var baseCurrency = TargetSnapshotStore.loadBaseCurrency()
  private(set) var rates = TargetSnapshotStore.loadRates()
  private(set) var isLoading = false
  private(set) var lastUpdated: Date?

  var statuses: [TargetStatus] { TargetStatus.sorted(targets: targets, quotes: quotes) }

  var portfolio: WatchPortfolio? {
    WatchPortfolio.make(stocks: watched, quotes: quotes, currency: baseCurrency, rates: rates)
  }

  var market: Quote? { quotes[Benchmark.symbol] }

  /// Every followed stock, including ones that only have alerts.
  var allSymbols: [String] {
    var symbols = watched.map(\.symbol)
    for target in targets where !symbols.contains(target.symbol) { symbols.append(target.symbol) }
    return symbols
  }

  /// Followed stocks with a price, biggest move today first.
  var movers: [Quote] {
    allSymbols.compactMap { quotes[$0] }.sorted { abs($0.change) > abs($1.change) }
  }

  /// Stocks with their alerts, closest to triggering first.
  var stocks: [(symbol: String, name: String, statuses: [TargetStatus])] {
    let grouped = Dictionary(grouping: statuses, by: \.target.symbol)
    return grouped
      .map { ($0.key, $0.value.first?.target.name ?? $0.key, $0.value) }
      .sorted { ($0.2.first?.distance ?? .infinity) < ($1.2.first?.distance ?? .infinity) }
  }

  func stock(_ symbol: String) -> WatchedStock? {
    watched.first { $0.symbol == symbol }
  }

  func activate() {
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
    Task { await refresh() }
  }

  func refresh() async {
    let symbols = allSymbols
    guard !symbols.isEmpty else { return }
    isLoading = true
    defer { isLoading = false }
    let service = QuoteService()
    let fresh = await service.quotes(for: symbols + [Benchmark.symbol])
    quotes.merge(fresh) { _, new in new }
    if let market = fresh[Benchmark.symbol] { Benchmark.quote = market }
    TargetSnapshotStore.save(quotes: quotes)
    // Rates for every currency the portfolio holds, so totals are in the user's own currency.
    let currencies = Set(watched.filter(\.isOwned).compactMap { quotes[$0.symbol]?.currency }).subtracting([baseCurrency])
    for currency in currencies {
      if let rate = await service.exchangeRate(from: currency, to: baseCurrency) { rates[currency] = rate }
    }
    TargetSnapshotStore.save(rates: rates)
    lastUpdated = .now
    WidgetCenter.shared.reloadAllTimelines()
  }

  fileprivate func receive(_ context: [String: Any]) {
    if let data = context["targets"] as? Data, let decoded = try? JSONDecoder().decode([WatchedTarget].self, from: data) {
      targets = decoded
      TargetSnapshotStore.save(targets: decoded)
    }
    if let data = context["stocks"] as? Data, let decoded = try? JSONDecoder().decode([WatchedStock].self, from: data) {
      watched = decoded
      TargetSnapshotStore.save(stocks: decoded)
    }
    if let currency = context["baseCurrency"] as? String {
      baseCurrency = currency
      TargetSnapshotStore.save(baseCurrency: currency)
    }
    if let data = context["progress"] as? Data, let decoded = try? JSONDecoder().decode(ProgressSnapshot.self, from: data) {
      progress = decoded
      decoded.save()
    }
    WidgetCenter.shared.reloadAllTimelines()
    Task { await refresh() }
  }
}

extension WatchTargetStore: WCSessionDelegate {
  nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    let context = session.receivedApplicationContext
    guard !context.isEmpty else { return }
    nonisolated(unsafe) let payload = context
    Task { @MainActor in self.receive(payload) }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    nonisolated(unsafe) let payload = applicationContext
    Task { @MainActor in self.receive(payload) }
  }
}
