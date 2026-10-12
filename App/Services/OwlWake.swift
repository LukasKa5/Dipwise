import Foundation
import Observation
import SwiftUI

/// Shared "awake" state, so tapping a sleeping Dippy wakes him up everywhere for a while.
@MainActor
@Observable
final class OwlWake {
  static let shared = OwlWake()
  static let awakeDuration: TimeInterval = 60

  private(set) var isAwake = false
  private var sleepTask: Task<Void, Never>?

  func wake() {
    withAnimation(.easeOut(duration: 0.9)) { isAwake = true }
    sleepTask?.cancel()
    sleepTask = Task {
      try? await Task.sleep(for: .seconds(Self.awakeDuration))
      guard !Task.isCancelled else { return }
      withAnimation(.easeIn(duration: 1.6)) { isAwake = false }
    }
  }
}
