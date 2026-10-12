import Foundation
import Observation
import SwiftUI

/// Whether Dippy is awake, shared by every owl in the app.
/// Dippy only falls asleep when the app is closed while the market is closed. Once he's awake,
/// because the market was open or the user tapped him, he stays awake until the app is closed.
@MainActor
@Observable
final class OwlWake {
  static let shared = OwlWake()

  private(set) var isAwake = MarketClock.isOpen()

  func wake() {
    guard !isAwake else { return }
    withAnimation(.smooth(duration: 0.5)) { isAwake = true }
  }

  /// Call when the app comes to the foreground.
  func appDidBecomeActive() {
    if MarketClock.isOpen() { isAwake = true }
  }

  /// Call when the app is closed. Dippy goes to sleep if the market is closed.
  func appDidEnterBackground() {
    isAwake = MarketClock.isOpen()
  }
}
