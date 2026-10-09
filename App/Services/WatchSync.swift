import Foundation
import WatchConnectivity

/// Sends the active alerts to the paired Apple Watch.
final class WatchSync: NSObject, WCSessionDelegate {
  static let shared = WatchSync()

  private var pending: [WatchedTarget]?

  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func send(targets: [WatchedTarget]) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated else {
      pending = targets
      return
    }
    guard session.isPaired, session.isWatchAppInstalled,
          let data = try? JSONEncoder().encode(targets) else { return }
    try? session.updateApplicationContext(["targets": data])
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if activationState == .activated, let pending {
      self.pending = nil
      send(targets: pending)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
