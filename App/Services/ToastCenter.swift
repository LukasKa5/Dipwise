import Foundation
import Observation

/// Short celebratory messages from Dippy, shown at the top of the app.
@MainActor
@Observable
final class ToastCenter {
  struct Toast: Identifiable, Equatable {
    var id = UUID()
    var message: String
    var systemImage: String
  }

  static let shared = ToastCenter()
  private(set) var current: Toast?

  func show(_ message: String, systemImage: String = "sparkles") {
    let toast = Toast(message: message, systemImage: systemImage)
    current = toast
    OwlCue.shared.play(systemImage == "bell.badge.fill" ? .surprise : .dance)
    Task {
      try? await Task.sleep(for: .seconds(2.6))
      if current?.id == toast.id { current = nil }
    }
  }
}
