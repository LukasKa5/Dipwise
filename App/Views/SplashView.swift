import SwiftUI

/// The first second of every launch: Dippy wakes up, stretches, and the app appears behind him.
/// It starts on the same navy as the system launch screen, so there's no flash.
struct SplashView: View {
  var onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isAwake = false
  @State private var wings = 0.0
  @State private var showsName = false
  @State private var lift: CGFloat = 0

  var body: some View {
    ZStack {
      Brand.nightMiddle.ignoresSafeArea()
      VStack(spacing: 18) {
        OwlMark(wingSpread: wings, blink: isAwake ? 0 : 1)
          .frame(width: 110, height: 126)
          .offset(y: lift)
        VStack(spacing: 4) {
          Text("Dipwise")
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
          Text("Buy the dip. Calmly.")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.buy)
        }
        .opacity(showsName ? 1 : 0)
        .offset(y: showsName ? 0 : 8)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Dipwise")
    .task { await play() }
  }

  private func play() async {
    if reduceMotion {
      isAwake = true
      showsName = true
      try? await Task.sleep(for: .seconds(0.5))
      onFinish()
      return
    }
    try? await Task.sleep(for: .seconds(0.15))
    // Eyes open, a quick stretch with a little hop, then the name.
    withAnimation(.easeOut(duration: 0.25)) { isAwake = true }
    try? await Task.sleep(for: .seconds(0.2))
    withAnimation(.spring(duration: 0.45, bounce: 0.4)) {
      wings = 0.8
      lift = -14
    }
    withAnimation(.smooth(duration: 0.5).delay(0.1)) { showsName = true }
    try? await Task.sleep(for: .seconds(0.4))
    withAnimation(.spring(duration: 0.5, bounce: 0.5)) {
      wings = 0
      lift = 0
    }
    try? await Task.sleep(for: .seconds(0.55))
    onFinish()
  }
}
