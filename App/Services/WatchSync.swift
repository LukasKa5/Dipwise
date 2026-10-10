import Foundation
import WatchConnectivity

/// Sends the active alerts to the paired Apple Watch.
final class WatchSync: NSObject, WCSessionDelegate {
  static let shared = WatchSync()

  private var pending: ([WatchedTarget], ProgressSnapshot)?

  func activate() {
    guard WCSession.isSupported() else { return }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func send(targets: [WatchedTarget], progress: ProgressSnapshot) {
    guard WCSession.isSupported() else { return }
    let session = WCSession.default
    guard session.activationState == .activated else {
      pending = (targets, progress)
      return
    }
    guard session.isPaired, session.isWatchAppInstalled,
          let data = try? JSONEncoder().encode(targets),
          let progressData = try? JSONEncoder().encode(progress) else { return }
    try? session.updateApplicationContext(["targets": data, "progress": progressData])
  }

  func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
    if activationState == .activated, let pending {
      self.pending = nil
      send(targets: pending.0, progress: pending.1)
    }
  }

  func sessionDidBecomeInactive(_ session: WCSession) {}

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }
}
