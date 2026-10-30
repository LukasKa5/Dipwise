import SwiftUI

/// The first moment of every launch, under a second and as quiet as Apple's own: Dippy alone in the middle of the
/// icon's navy, the same color as the system launch screen so there's no flash. He opens his eyes, blinks once, and
/// the screen eases away into the app. A tap skips it.
struct SplashView: View {
  var onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var blink = 1.0
  @State private var isLeaving = false
  @State private var isDone = false

  var body: some View {
    ZStack {
      Brand.nightMiddle.ignoresSafeArea()
      OwlMark(blink: blink)
        .frame(width: 112, height: 129)
        .scaleEffect(isLeaving ? 1.12 : 1)
        .opacity(isLeaving ? 0 : 1)
    }
    .contentShape(.rect)
    .onTapGesture { finish() }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Dipwise")
    .task { await play() }
  }

  private func play() async {
    if reduceMotion {
      blink = 0
      try? await Task.sleep(for: .seconds(0.5))
      finish()
      return
    }
    try? await Task.sleep(for: .seconds(0.15))
    withAnimation(.easeOut(duration: 0.22)) { blink = 0 }
    try? await Task.sleep(for: .seconds(0.35))
    withAnimation(.easeInOut(duration: 0.08)) { blink = 1 }
    try? await Task.sleep(for: .seconds(0.09))
    withAnimation(.easeInOut(duration: 0.1)) { blink = 0 }
    try? await Task.sleep(for: .seconds(0.2))
    withAnimation(.smooth(duration: 0.3)) { isLeaving = true }
    try? await Task.sleep(for: .seconds(0.22))
    finish()
  }

  private func finish() {
    guard !isDone else { return }
    isDone = true
    onFinish()
  }
}
