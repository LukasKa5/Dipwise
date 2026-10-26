import SwiftUI

/// The first moment of every launch, under two seconds: the icon's glowing price line draws itself, dips, and climbs
/// to a ping; Dippy pops onto it, blinks awake, and flaps; and a first line about the user's own plans settles in.
/// It starts on the same navy as the system launch screen, so there's no flash. A tap skips it.
struct SplashView: View {
  var onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var line = 0.0
  @State private var showsOwl = false
  @State private var eyesOpen = false
  @State private var wings = 0.0
  @State private var ping = false
  @State private var showsName = false
  @State private var isDone = false

  /// The closest plan from the shared snapshot, so the first words are about the user's own stocks.
  private let headline: String = {
    let statuses = TargetStatus.sorted(targets: TargetSnapshotStore.loadTargets(), quotes: TargetSnapshotStore.loadQuotes())
    guard let closest = statuses.first, let distance = closest.distance else { return String(localized: "Buy the dip. Calmly.") }
    let isSell = closest.target.rule.kind.side == .sell
    if distance == 0 {
      return isSell ? String(localized: "\(closest.target.symbol) is in your sell zone.")
                    : String(localized: "\(closest.target.symbol) is in your buy zone.")
    }
    let percent = distance.formatted(.percent.precision(.fractionLength(1)))
    return isSell ? String(localized: "\(closest.target.symbol) is \(percent) from your sell zone.")
                  : String(localized: "\(closest.target.symbol) is \(percent) from your buy zone.")
  }()

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let height = geometry.size.height
      let lineTop = height * 0.44
      ZStack {
        Brand.nightMiddle.ignoresSafeArea()
        PriceLine()
          .trim(from: 0, to: line)
          .stroke(Brand.mint, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
          .shadow(color: Brand.mint.opacity(0.7), radius: 10)
          .frame(width: width, height: 120)
          .position(x: width / 2, y: lineTop)
        // The ping where the line ends, like the icon's dot.
        ZStack {
          Circle().stroke(Brand.mint.opacity(ping ? 0 : 0.6), lineWidth: 3)
            .frame(width: ping ? 70 : 14, height: ping ? 70 : 14)
          Circle().fill(.white).frame(width: 12, height: 12)
            .overlay { Circle().strokeBorder(Brand.mint, lineWidth: 3) }
            .opacity(line > 0.98 ? 1 : 0)
        }
        .position(x: width * 0.92, y: lineTop - 120 * 0.36)
        OwlMark(blink: eyesOpen ? 0 : 1, leftWing: wings, rightWing: wings)
          .frame(width: 92, height: 106)
          .scaleEffect(showsOwl ? 1 : 0.4, anchor: .bottom)
          .opacity(showsOwl ? 1 : 0)
          .position(x: width * 0.44, y: lineTop + 120 * 0.28 - 50)
        VStack(spacing: 8) {
          Text("Dipwise")
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
          Text(headline)
            .font(.headline)
            .foregroundStyle(Brand.mint)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
        }
        .opacity(showsName ? 1 : 0)
        .offset(y: showsName ? 0 : 8)
        .position(x: width / 2, y: lineTop + 150)
      }
    }
    .contentShape(.rect)
    .onTapGesture { finish() }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Dipwise. \(headline)")
    .task { await play() }
  }

  private func play() async {
    if reduceMotion {
      line = 1
      showsOwl = true
      eyesOpen = true
      showsName = true
      try? await Task.sleep(for: .seconds(0.8))
      finish()
      return
    }
    withAnimation(.easeInOut(duration: 0.75)) { line = 1 }
    try? await Task.sleep(for: .seconds(0.3))
    withAnimation(.bouncy(duration: 0.45)) { showsOwl = true }
    try? await Task.sleep(for: .seconds(0.35))
    withAnimation(.easeInOut(duration: 0.25)) { eyesOpen = true }
    withAnimation(.easeOut(duration: 0.7)) { ping = true }
    for _ in 0..<2 {
      withAnimation(.easeOut(duration: 0.12)) { wings = 0.8 }
      try? await Task.sleep(for: .seconds(0.12))
      withAnimation(.easeIn(duration: 0.12)) { wings = 0 }
      try? await Task.sleep(for: .seconds(0.12))
    }
    withAnimation(.easeOut(duration: 0.45)) { showsName = true }
    try? await Task.sleep(for: .seconds(0.75))
    finish()
  }

  private func finish() {
    guard !isDone else { return }
    isDone = true
    onFinish()
  }
}

/// The icon's price line: a calm start, the dip where Dippy sits, and the climb to the ping.
private struct PriceLine: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      let w = rect.width, h = rect.height
      path.move(to: CGPoint(x: -10, y: h * 0.35))
      path.addCurve(to: CGPoint(x: w * 0.44, y: h * 0.78), control1: CGPoint(x: w * 0.16, y: h * 0.38), control2: CGPoint(x: w * 0.3, y: h * 0.8))
      path.addCurve(to: CGPoint(x: w * 0.92, y: h * 0.14), control1: CGPoint(x: w * 0.6, y: h * 0.76), control2: CGPoint(x: w * 0.76, y: h * 0.12))
    }
  }
}
