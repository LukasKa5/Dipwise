import SwiftUI

/// Blurs Pro-only content and invites the user to upgrade. In a list of locked rows only one row carries the invitation
/// (`prompt`), so the rest are just blurred instead of each stacking its own.
///
/// Once a day, anyone can try Pro for ten minutes instead: every locked feature opens, with their own stocks and real
/// data, so they see exactly what they'd pay for at the moment they want it.
struct ProLockedModifier: ViewModifier {
  var isLocked: Bool
  var message: LocalizedStringKey
  var prompt = true
  @AppStorage(ProPreview.untilKey) private var previewUntil = 0.0
  @AppStorage(ProPreview.dayKey) private var previewDay = ""
  @State private var showsPaywall = false
  @State private var now = Date.now

  private var isPreviewing: Bool { now.timeIntervalSince1970 < previewUntil }
  private var locked: Bool { isLocked && !isPreviewing }
  private var canPreview: Bool { previewDay != ProPreview.today }

  func body(content: Content) -> some View {
    content
      .blur(radius: locked ? 9 : 0)
      .allowsHitTesting(!locked)
      .accessibilityHidden(locked)
      .overlay {
        if locked && prompt {
          VStack(spacing: 12) {
            Image(systemName: "lock.fill")
              .font(.title2)
              .foregroundStyle(Palette.amber)
            Text(message)
              .font(.subheadline.weight(.semibold))
              .multilineTextAlignment(.center)
            Button("Unlock with Pro") { showsPaywall = true }
              .buttonStyle(.borderedProminent)
            if canPreview {
              Button("Try Pro free for 10 minutes", action: startPreview)
                .font(.footnote.weight(.semibold))
            }
          }
          .padding(20)
          .frame(maxWidth: 300)
          .background(.regularMaterial, in: .rect(cornerRadius: 24))
        }
      }
      .overlay(alignment: .topTrailing) {
        if isLocked && isPreviewing && prompt {
          Label("Pro preview", systemImage: "sparkles")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Palette.amber, in: .capsule)
            .padding(8)
        }
      }
      .animation(.smooth, value: locked)
      .task(id: previewUntil) {
        // Lock again the moment the preview ends.
        now = .now
        let remaining = previewUntil - now.timeIntervalSince1970
        guard remaining > 0 else { return }
        try? await Task.sleep(for: .seconds(remaining))
        now = .now
      }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
  }

  private func startPreview() {
    previewDay = ProPreview.today
    previewUntil = Date.now.addingTimeInterval(ProPreview.length).timeIntervalSince1970
    now = .now
  }
}

/// The daily ten-minute Pro preview, shared by every locked feature in the app.
enum ProPreview {
  static let untilKey = "proPreviewUntil"
  static let dayKey = "proPreviewDay"
  static let length: TimeInterval = 10 * 60

  static var today: String {
    Date.now.formatted(.iso8601.year().month().day())
  }
}

extension View {
  func proLocked(_ isLocked: Bool, message: LocalizedStringKey, prompt: Bool = true) -> some View {
    modifier(ProLockedModifier(isLocked: isLocked, message: message, prompt: prompt))
  }
}
