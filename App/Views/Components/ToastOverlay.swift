import SwiftUI

/// Dippy flies in with a short message, then flies away.
struct ToastOverlay: View {
  var center: ToastCenter
  @State private var flights = 0

  var body: some View {
    VStack {
      if let toast = center.current {
        HStack(spacing: 12) {
          LivelyOwl(hopsOnTap: false, greeting: .flap, greetingDelay: 0.3)
            .frame(width: 38, height: 44)
            .owlFlight(trigger: flights, height: 26)
          Label(toast.message, systemImage: toast.systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
        }
        .padding(.leading, 12)
        .padding(.trailing, 18)
        .padding(.vertical, 10)
        .background(Brand.nightMiddle, in: .capsule)
        .overlay { Capsule().strokeBorder(.white.opacity(0.12)) }
        .shadow(color: .black.opacity(0.25), radius: 14, y: 6)
        .transition(.move(edge: .top).combined(with: .scale(scale: 0.7)).combined(with: .opacity))
        .onAppear { flights += 1 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
      }
      Spacer()
    }
    .padding(.top, 6)
    .animation(.bouncy(duration: 0.55), value: center.current)
    .sensoryFeedback(.success, trigger: center.current?.id)
    .allowsHitTesting(false)
  }
}
