import SwiftUI

/// The first moment of every launch: Dippy quietly appears, opens his eyes, and the name settles in beneath him.
/// It starts on the same navy as the system launch screen, so there's no flash, and every move is slow and soft.
struct SplashView: View {
  var onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var showsOwl = false
  @State private var eyesOpen = false
  @State private var showsName = false

  var body: some View {
    ZStack {
      Brand.nightMiddle.ignoresSafeArea()
      VStack(spacing: 22) {
        OwlMark(blink: eyesOpen ? 0 : 1)
          .frame(width: 104, height: 120)
          .opacity(showsOwl ? 1 : 0)
          .scaleEffect(showsOwl ? 1 : 0.94)
        VStack(spacing: 6) {
          Text("Dipwise")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
          Text("Buy the dip.")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white.opacity(0.6))
        }
        .opacity(showsName ? 1 : 0)
        .offset(y: showsName ? 0 : 6)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Dipwise")
    .task { await play() }
  }

  private func play() async {
    if reduceMotion {
      showsOwl = true
      eyesOpen = true
      showsName = true
      try? await Task.sleep(for: .seconds(0.6))
      onFinish()
      return
    }
    withAnimation(.easeOut(duration: 0.5)) { showsOwl = true }
    try? await Task.sleep(for: .seconds(0.45))
    withAnimation(.easeInOut(duration: 0.35)) { eyesOpen = true }
    try? await Task.sleep(for: .seconds(0.2))
    withAnimation(.easeOut(duration: 0.55)) { showsName = true }
    try? await Task.sleep(for: .seconds(0.85))
    onFinish()
  }
}
