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
        KeyframeTrack(\.squash) {
          CubicKeyframe(0.9, duration: 0.12)
          SpringKeyframe(1.06, duration: 0.18, spring: .snappy)
          CubicKeyframe(1, duration: 0.7)
          CubicKeyframe(0.92, duration: 0.1)
          SpringKeyframe(1, duration: 0.3, spring: .bouncy)
        }
        KeyframeTrack(\.lift) {
          LinearKeyframe(0, duration: 0.12)
          SpringKeyframe(height, duration: 0.3, spring: .snappy)
          CubicKeyframe(height * 0.85, duration: 0.2)
          CubicKeyframe(height * 0.95, duration: 0.2)
          CubicKeyframe(height * 0.6, duration: 0.18)
          SpringKeyframe(0, duration: 0.35, spring: .bouncy)
        }
        KeyframeTrack(\.wing) {
          LinearKeyframe(0.15, duration: 0.12)
          CubicKeyframe(1, duration: 0.09)
          CubicKeyframe(0.25, duration: 0.1)
          CubicKeyframe(1, duration: 0.09)
          CubicKeyframe(0.3, duration: 0.1)
          CubicKeyframe(0.95, duration: 0.1)
          CubicKeyframe(0.4, duration: 0.11)
          CubicKeyframe(0.8, duration: 0.12)
          CubicKeyframe(0.75, duration: 0.15)
          CubicKeyframe(1, duration: 0.1)
          CubicKeyframe(0, duration: 0.25)
        }
        KeyframeTrack(\.tilt) {
          CubicKeyframe(-4 * direction, duration: 0.12)
          CubicKeyframe(14 * direction, duration: 0.3)
          CubicKeyframe(6 * direction, duration: 0.4)
          CubicKeyframe(-8 * direction, duration: 0.15)
          SpringKeyframe(0, duration: 0.35, spring: .bouncy)
        }
        KeyframeTrack(\.scale) {
          CubicKeyframe(1, duration: 0.12)
          CubicKeyframe(1.08, duration: 0.3)
          CubicKeyframe(1.0, duration: 0.6)
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
struct LivelyOwl: View {
  var lookOffset: CGSize = .zero
  var hopsOnTap = true
  var mood: OwlMood = .calm
  @Environment(\.owlWingSpread) private var wingSpread
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hops = 0
  @State private var taps = 0
  @State private var blink = 0.0
  @State private var look = CGSize.zero
  @State private var stretch = 0.0
  @State private var breathing = false
  @State private var awake = false
  @State private var recentTaps: [Date] = []
  @State private var spin = 0.0

  var body: some View {
    let isAsleep = mood == .sleeping && !awake
    OwlMark(wingSpread: max(wingSpread, stretch), blink: isAsleep ? 1 : blink, lookOffset: lookOffset == .zero ? look : lookOffset)
      .scaleEffect(x: 1, y: breathing ? (isAsleep ? 1.04 : 1.025) : 1, anchor: .bottom)
      .rotation3DEffect(.degrees(spin), axis: (x: 0, y: 1, z: 0))
      .overlay(alignment: .topTrailing) {
        if isAsleep { SleepingZs().offset(x: 14, y: -10) }
      }
      .contentShape(.rect)
      .onTapGesture { handleTap() }
      .owlFlight(trigger: hops, direction: hops.isMultiple(of: 2) ? 1 : -1, height: 22, isEnabled: !reduceMotion)
      .sensoryFeedback(.impact(weight: .light), trigger: taps)
      .onAppear {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { breathing = true }
      }
      .task {
        guard !reduceMotion else { return }
        await liveForever()
      }
  }

  private func handleTap() {
    guard hopsOnTap || mood == .sleeping else { return }
    taps += 1
    if mood == .sleeping && !awake {
      withAnimation(.snappy) { awake = true }
      Task {
        try? await Task.sleep(for: .seconds(4))
        withAnimation(.smooth) { awake = false }
      }
    }
    hops += 1
    blinkOnce()
    // Five quick taps: a barrel roll.
    recentTaps = recentTaps.filter { Date.now.timeIntervalSince($0) < 2 } + [.now]
    if recentTaps.count >= 5, !reduceMotion {
      recentTaps = []
      withAnimation(.spring(duration: 0.9, bounce: 0.3)) { spin += 360 }
      ToastCenter.shared.show("Wheee! Hoo hoo!", systemImage: "tornado")
    }
  }

  private func blinkOnce() {
    withAnimation(.easeIn(duration: 0.07)) { blink = 1 }
    withAnimation(.easeOut(duration: 0.12).delay(0.1)) { blink = 0 }
  }

  /// Small, random idle behaviors, like a real owl on a branch.
  private func liveForever() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(Double.random(in: 1.6...3.8)))
      if mood == .sleeping && !awake { continue }
      if mood == .celebrating, Int.random(in: 0..<3) == 0 {
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
        if hopsOnTap { hops += 1 } else { blinkOnce() }
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
