import SwiftUI

/// Blurs Pro-only content and invites the user to upgrade.
struct ProLockedModifier: ViewModifier {
  var isLocked: Bool
  var message: String
  @State private var showsPaywall = false

  func body(content: Content) -> some View {
    content
      .blur(radius: isLocked ? 9 : 0)
      .allowsHitTesting(!isLocked)
      .accessibilityHidden(isLocked)
      .overlay {
        if isLocked {
          VStack(spacing: 12) {
            Image(systemName: "lock.fill")
              .font(.title2)
              .foregroundStyle(Palette.amber)
            Text(message)
              .font(.subheadline.weight(.semibold))
              .multilineTextAlignment(.center)
            Button("Unlock with Pro") { showsPaywall = true }
              .buttonStyle(.borderedProminent)
          }
          .padding(20)
          .frame(maxWidth: 300)
          .background(.regularMaterial, in: .rect(cornerRadius: 24))
        }
      }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
  }
}

extension View {
  func proLocked(_ isLocked: Bool, message: String) -> some View {
    modifier(ProLockedModifier(isLocked: isLocked, message: message))
  }
}
