import SwiftUI

/// Animation values for one owl flight: lift, wing flaps, and a lean into the direction of travel.
struct OwlFlightPose {
  var lift: Double = 0
  var wing: Double = 0
  var tilt: Double = 0
  var scale: Double = 1
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
          .rotationEffect(.degrees(pose.tilt), anchor: .bottom)
          .scaleEffect(pose.scale, anchor: .bottom)
          .offset(y: -pose.lift)
      } keyframes: { _ in
        KeyframeTrack(\.lift) {
          SpringKeyframe(height, duration: 0.32, spring: .snappy)
          CubicKeyframe(height * 0.7, duration: 0.25)
          SpringKeyframe(0, duration: 0.4, spring: .bouncy)
        }
        KeyframeTrack(\.wing) {
          LinearKeyframe(1, duration: 0.1)
          LinearKeyframe(0.35, duration: 0.11)
          LinearKeyframe(1, duration: 0.11)
          LinearKeyframe(0.35, duration: 0.11)
          LinearKeyframe(1, duration: 0.11)
          LinearKeyframe(0.6, duration: 0.15)
          LinearKeyframe(0, duration: 0.2)
        }
        KeyframeTrack(\.tilt) {
          CubicKeyframe(12 * direction, duration: 0.3)
          CubicKeyframe(4 * direction, duration: 0.3)
          SpringKeyframe(0, duration: 0.35, spring: .bouncy)
        }
        KeyframeTrack(\.scale) {
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
  @Environment(\.owlWingSpread) private var wingSpread
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hops = 0
  @State private var taps = 0
  @State private var blink = 0.0
  @State private var look = CGSize.zero
  @State private var stretch = 0.0
  @State private var breathing = false

  var body: some View {
    OwlMark(wingSpread: max(wingSpread, stretch), blink: blink, lookOffset: lookOffset == .zero ? look : lookOffset)
      .scaleEffect(x: 1, y: breathing ? 1.025 : 1, anchor: .bottom)
      .contentShape(.rect)
      .onTapGesture {
        guard hopsOnTap else { return }
        hops += 1
        taps += 1
        blinkOnce()
      }
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

  private func blinkOnce() {
    withAnimation(.easeIn(duration: 0.07)) { blink = 1 }
    withAnimation(.easeOut(duration: 0.12).delay(0.1)) { blink = 0 }
  }

  /// Small, random idle behaviors, like a real owl on a branch.
  private func liveForever() async {
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(Double.random(in: 1.6...3.8)))
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
