import SwiftUI

/// Animation values for one owl flight: lift, wing flaps, and a lean into the direction of travel.
struct OwlFlightPose {
  var lift: Double = 0
  var wing: Double = 0
  var tilt: Double = 0
  var scale: Double = 1
  /// Vertical squash for the crouch before take-off and the bounce on landing.
  var squash: Double = 1
}

extension View {
  /// Plays a flight (or hop) whenever `trigger` changes.
  func owlFlight(trigger: Int, direction: Double = 1, height: Double = 46, isEnabled: Bool = true) -> some View {
    modifier(OwlFlightModifier(trigger: trigger, direction: direction, height: height, isEnabled: isEnabled))
  }
}

private struct OwlFlightModifier: ViewModifier {
  var trigger: Int
  var direction: Double
  var height: Double
  var isEnabled: Bool

  func body(content: Content) -> some View {
    if isEnabled {
      content.keyframeAnimator(initialValue: OwlFlightPose(), trigger: trigger) { view, pose in
        view
          .environment(\.owlWingSpread, pose.wing)
          .scaleEffect(x: 2 - pose.squash, y: pose.squash, anchor: .bottom)
          .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
          .scaleEffect(pose.scale, anchor: .bottom)
          .offset(y: -pose.lift)
      } keyframes: { _ in
        // A slower, more natural flight: crouch, push off, a few deep wing beats, glide, flare, land.
        KeyframeTrack(\.squash) {
          CubicKeyframe(0.9, duration: 0.18)
          SpringKeyframe(1.05, duration: 0.25, spring: .smooth)
          CubicKeyframe(1, duration: 1.2)
          CubicKeyframe(0.93, duration: 0.15)
          SpringKeyframe(1, duration: 0.45, spring: .bouncy)
        }
        KeyframeTrack(\.lift) {
          LinearKeyframe(0, duration: 0.18)
          SpringKeyframe(height, duration: 0.45, spring: .smooth)
          CubicKeyframe(height * 0.88, duration: 0.35)
          CubicKeyframe(height * 0.96, duration: 0.35)
          CubicKeyframe(height * 0.7, duration: 0.3)
          SpringKeyframe(0, duration: 0.55, spring: .bouncy)
        }
        KeyframeTrack(\.wing) {
          CubicKeyframe(0.2, duration: 0.18)
          CubicKeyframe(1, duration: 0.2)
          CubicKeyframe(0.35, duration: 0.22)
          CubicKeyframe(1, duration: 0.2)
          CubicKeyframe(0.4, duration: 0.24)
          CubicKeyframe(0.9, duration: 0.22)
          CubicKeyframe(0.75, duration: 0.35)
          CubicKeyframe(1, duration: 0.18)
          CubicKeyframe(0, duration: 0.4)
        }
        KeyframeTrack(\.tilt) {
          CubicKeyframe(-3 * direction, duration: 0.18)
          CubicKeyframe(10 * direction, duration: 0.45)
          CubicKeyframe(4 * direction, duration: 0.7)
          CubicKeyframe(-6 * direction, duration: 0.25)
          SpringKeyframe(0, duration: 0.5, spring: .bouncy)
        }
        KeyframeTrack(\.scale) {
          CubicKeyframe(1, duration: 0.18)
          CubicKeyframe(1.05, duration: 0.45)
          CubicKeyframe(1.0, duration: 1.0)
        }
      }
    } else {
      content
    }
  }
}

extension EnvironmentValues {
  @Entry var owlWingSpread: Double = 0
}

/// An owl that feels alive: it breathes, blinks, looks around, stretches its wings, and hops when tapped.
/// Unless told otherwise, Dippy sleeps whenever the US market is closed, everywhere in the app.
struct LivelyOwl: View {
  var lookOffset: CGSize = .zero
  var hopsOnTap = true
  /// Nil follows the market clock.
  var mood: OwlMood? = nil
  @Environment(\.owlWingSpread) private var wingSpread
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hops = 0
  @State private var taps = 0
  @State private var blink = 0.0
  @State private var look = CGSize.zero
  @State private var stretch = 0.0
  @State private var breathing = false
  @State private var peek = 0.0
  @State private var recentTaps: [Date] = []
  @State private var spin = 0.0
  @State private var bubble: String?
  @State private var ruffle = 0

  private var effectiveMood: OwlMood {
    if let mood { return mood }
    return MarketClock.isOpen() || OwlWake.shared.isAwake ? .calm : .sleeping
  }

  var body: some View {
    let isAsleep = effectiveMood == .sleeping
    OwlMark(
      wingSpread: max(wingSpread, stretch),
      blink: isAsleep ? 1 : blink,
      lookOffset: lookOffset == .zero ? look : lookOffset,
      rightEyeOpen: peek
    )
    .scaleEffect(x: 1, y: breathing ? (isAsleep ? 1.04 : 1.025) : 1, anchor: .bottom)
    .keyframeAnimator(initialValue: 0.0, trigger: ruffle) { view, angle in
      view.rotationEffect(.degrees(angle), anchor: .bottom)
    } keyframes: { _ in
      KeyframeTrack {
        LinearKeyframe(-7, duration: 0.06)
        LinearKeyframe(7, duration: 0.08)
        LinearKeyframe(-5, duration: 0.08)
        LinearKeyframe(4, duration: 0.08)
        SpringKeyframe(0, duration: 0.25, spring: .bouncy)
      }
    }
    .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
    .overlay(alignment: .topTrailing) {
      if isAsleep && peek < 0.5 { SleepingZs().offset(x: 14, y: -10) }
    }
    .overlay(alignment: .top) {
      if let bubble {
        Text(bubble)
          .font(.caption.weight(.heavy))
          .foregroundStyle(Brand.owlInk)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.white, in: .capsule)
          .fixedSize()
          .offset(y: -22)
          .transition(.scale(scale: 0.5, anchor: .bottom).combined(with: .opacity))
      }
    }
    .contentShape(.rect)
    .onTapGesture { handleTap(isAsleep: isAsleep) }
    .onLongPressGesture(minimumDuration: 0.45) { hoot() }
    .owlFlight(trigger: hops, direction: hops.isMultiple(of: 2) ? 1 : -1, height: 22, isEnabled: !reduceMotion)
    .sensoryFeedback(.impact(weight: .light), trigger: taps)
    .sensoryFeedback(.impact(weight: .medium), trigger: ruffle)
    .onAppear {
      guard !reduceMotion else { return }
      withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathing = true }
    }
    .task {
      guard !reduceMotion else { return }
      await liveForever()
    }
  }

  private func say(_ text: String, for seconds: Double = 1.4) {
    withAnimation(.bouncy) { bubble = text }
    Task {
      try? await Task.sleep(for: .seconds(seconds))
      withAnimation(.smooth) { if bubble == text { bubble = nil } }
    }
  }

  private func handleTap(isAsleep: Bool) {
    taps += 1
    if isAsleep {
      // Wake up: one eye first, then both, a big stretch, and a sleepy hoot.
      withAnimation(.easeOut(duration: 0.3)) { peek = 1 }
      say("Hoo? I'm up!", for: 2)
      Task {
        try? await Task.sleep(for: .seconds(0.5))
        OwlWake.shared.wake()
        peek = 0
        withAnimation(.easeOut(duration: 0.6)) { stretch = 0.8 }
        try? await Task.sleep(for: .seconds(0.7))
        withAnimation(.easeInOut(duration: 0.8)) { stretch = 0 }
      }
      return
    }
    guard hopsOnTap else {
      blinkOnce()
      return
    }
    hops += 1
    blinkOnce()
    // Five quick taps: a barrel roll.
    recentTaps = recentTaps.filter { Date.now.timeIntervalSince($0) < 2 } + [.now]
    if recentTaps.count >= 5, !reduceMotion {
      recentTaps = []
      withAnimation(.spring(duration: 0.9, bounce: 0.3)) { spin += 360 }
      say("Wheee!")
    }
  }

  /// Long press: Dippy hoots and ruffles his feathers.
  private func hoot() {
    if effectiveMood == .sleeping {
      say("zzz…")
      return
    }
    ruffle += 1
    withAnimation(.easeOut(duration: 0.2)) { stretch = 0.6 }
    Task {
      try? await Task.sleep(for: .seconds(0.35))
      withAnimation(.easeIn(duration: 0.3)) { stretch = 0 }
    }
    say(["Hoo hoo!", "Hoo!", "Buy low!", "Patience…"].randomElement() ?? "Hoo!")
  }

  private func blinkOnce() {
    withAnimation(.easeIn(duration: 0.07)) { blink = 1 }
    withAnimation(.easeOut(duration: 0.12).delay(0.1)) { blink = 0 }
  }

  /// Small, random idle behaviors, like a real owl on a branch.
  private func liveForever() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(Double.random(in: 1.6...3.8)))
      if effectiveMood == .sleeping { continue }
      if effectiveMood == .celebrating, Int.random(in: 0..<8) == 0 {
        hops += 1
        continue
      }
      switch Int.random(in: 0..<20) {
      case 0..<9:
        blinkOnce()
      case 9..<11:
        blinkOnce()
        try? await Task.sleep(for: .seconds(0.3))
        blinkOnce()
      case 11..<16:
        let direction = CGSize(width: [-1.0, 1.0].randomElement() ?? 1, height: Double.random(in: -0.4...0.3))
        withAnimation(.snappy(duration: 0.3)) { look = direction }
        try? await Task.sleep(for: .seconds(Double.random(in: 0.9...1.6)))
        withAnimation(.snappy(duration: 0.35)) { look = .zero }
      case 16..<18:
        withAnimation(.easeOut(duration: 0.35)) { stretch = 0.55 }
        try? await Task.sleep(for: .seconds(0.45))
        withAnimation(.easeIn(duration: 0.3)) { stretch = 0 }
      default:
        blinkOnce()
      }
    }
  }
}

/// Floating "z" letters for a sleeping owl.
private struct SleepingZs: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 15, paused: reduceMotion)) { timeline in
      let t = timeline.date.timeIntervalSinceReferenceDate
      ZStack {
        ForEach(0..<3) { index in
          let phase = (t / 2.4 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
          Text("z")
            .font(.system(size: 9 + CGFloat(index) * 3, weight: .heavy, design: .rounded))
            .foregroundStyle(.secondary.opacity(1 - phase))
            .offset(x: phase * 14, y: -phase * 26)
        }
      }
    }
    .frame(width: 24, height: 30)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
