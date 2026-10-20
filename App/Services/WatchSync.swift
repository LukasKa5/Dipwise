import Foundation
import WatchConnectivity

/// Sends the active alerts to the paired Apple Watch.
final class WatchSync: NSObject, WCSessionDelegate {
  static let shared = WatchSync()

  private var pending: (targets: [WatchedTarget], stocks: [WatchedStock], baseCurrency: String, progress: ProgressSnapshot)?

  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func send(targets: [WatchedTarget], stocks: [WatchedStock], baseCurrency: String, progress: ProgressSnapshot) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated else {
      pending = (targets, stocks, baseCurrency, progress)
      return
    }
    guard session.isPaired, session.isWatchAppInstalled,
          let data = try? JSONEncoder().encode(targets),
          let stocksData = try? JSONEncoder().encode(stocks),
          let progressData = try? JSONEncoder().encode(progress) else { return }
    try? session.updateApplicationContext(["targets": data, "stocks": stocksData, "baseCurrency": baseCurrency, "progress": progressData, "realTime": MarketData.isRealTime])
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if activationState == .activated, let pending {
      self.pending = nil
      send(targets: pending.targets, stocks: pending.stocks, baseCurrency: pending.baseCurrency, progress: pending.progress)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
