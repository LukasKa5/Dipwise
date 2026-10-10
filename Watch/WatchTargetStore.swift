import Foundation
import Observation
import WatchConnectivity
import WidgetKit

/// Receives plans and progress from the iPhone, fetches prices on the watch, and feeds the complications.
@MainActor
@Observable
final class WatchTargetStore: NSObject {
  private(set) var targets: [WatchedTarget] = TargetSnapshotStore.loadTargets()
  private(set) var quotes: [String: Quote] = TargetSnapshotStore.loadQuotes()
  private(set) var progress = ProgressSnapshot.load()
  private(set) var isLoading = false

  var statuses: [TargetStatus] { TargetStatus.sorted(targets: targets, quotes: quotes) }

  /// Stocks with their alerts, closest to triggering first.
  var stocks: [(symbol: String, name: String, statuses: [TargetStatus])] {
    let grouped = Dictionary(grouping: statuses, by: \.target.symbol)
    return grouped
      .map { ($0.key, $0.value.first?.target.name ?? $0.key, $0.value) }
      .sorted { ($0.2.first?.distance ?? .infinity) < ($1.2.first?.distance ?? .infinity) }
  }

  func activate() {
    if WCSession.isSupported() {
      WCSession.default.delegate = self
      WCSession.default.activate()
    }
    Task { await refresh() }
  }

  func refresh() async {
    guard !targets.isEmpty else { return }
    isLoading = true
    defer { isLoading = false }
    let fresh = await QuoteService().quotes(for: targets.map(\.symbol))
    quotes.merge(fresh) { _, new in new }
    TargetSnapshotStore.save(quotes: quotes)
    WidgetCenter.shared.reloadAllTimelines()
  }

  fileprivate func receive(_ context: [String: Any]) {
    if let data = context["targets"] as? Data, let decoded = try? JSONDecoder().decode([WatchedTarget].self, from: data) {
      targets = decoded
      TargetSnapshotStore.save(targets: decoded)
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
