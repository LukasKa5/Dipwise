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

/// An owl that blinks now and then, opens its wings during flights, and hops when tapped.
struct LivelyOwl: View {
  var lookOffset: CGSize = .zero
  var hopsOnTap = true
  @Environment(\.owlWingSpread) private var wingSpread
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hops = 0

  var body: some View {
    Group {
      if reduceMotion {
        OwlMark(wingSpread: wingSpread, lookOffset: lookOffset)
      } else {
        PhaseAnimator([0.0, 1.0, 0.0, 0.0]) { blink in
          OwlMark(wingSpread: wingSpread, blink: blink, lookOffset: lookOffset)
        } animation: { phase in
          phase == 1 ? .linear(duration: 0.12) : .linear(duration: phase == 0 ? 0.1 : 3.4)
        }
      }
    }
    .contentShape(.rect)
    .onTapGesture {
      guard hopsOnTap else { return }
      hops += 1
    }
    .owlFlight(trigger: hops, direction: hops.isMultiple(of: 2) ? 1 : -1, height: 22, isEnabled: !reduceMotion)
    .sensoryFeedback(.impact(weight: .light), trigger: hops)
  }
}
