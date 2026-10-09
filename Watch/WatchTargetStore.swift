import Foundation
import Observation
import WatchConnectivity

/// Receives price targets from the iPhone and fetches current prices on the watch.
@MainActor
@Observable
final class WatchTargetStore: NSObject {
  private static let targetsKey = "watchTargets"

  private(set) var targets: [WatchedTarget] = []
  private(set) var quotes: [String: Quote] = [:]
  private(set) var isLoading = false

  var statuses: [TargetStatus] { TargetStatus.sorted(targets: targets, quotes: quotes) }

  override init() {
    super.init()
    if let data = UserDefaults.standard.data(forKey: Self.targetsKey),
       let saved = try? JSONDecoder().decode([WatchedTarget].self, from: data) {
      targets = saved
    }
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
  }

  fileprivate func receive(_ data: Data) {
    guard let decoded = try? JSONDecoder().decode([WatchedTarget].self, from: data) else { return }
    targets = decoded
    UserDefaults.standard.set(data, forKey: Self.targetsKey)
    Task { await refresh() }
  }
}

extension WatchTargetStore: WCSessionDelegate {
  nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if let data = session.receivedApplicationContext["targets"] as? Data {
      Task { @MainActor in self.receive(data) }
    }
  }

  nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
    if let data = applicationContext["targets"] as? Data {
      Task { @MainActor in self.receive(data) }
    }
  }
}
