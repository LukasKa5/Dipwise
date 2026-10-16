import Foundation

/// The little things Dippy does: each one is a short, hand-tuned piece of animation in `LivelyOwl`.
enum OwlReaction: CaseIterable {
  /// Waves one wing at you.
  case wave
  /// A quick hop on the spot.
  case hop
  /// Closes one eye.
  case wink
  /// Flaps both wings, pleased.
  case flap
  /// Tilts his head, curious.
  case tilt
  /// Eyes wide, a startled little jump.
  case surprise
  /// Hoots, beak open, feathers ruffled.
  case hoot

  /// The reactions a tap can bring, so tapping him again and again keeps surprising.
  static let onTap: [OwlReaction] = [.wave, .hop, .wink, .flap, .tilt, .surprise, .hoot]

  /// Greetings already shown since launch, so Dippy says hi once rather than on every return to a screen.
  @MainActor static var shownGreetings: Set<String> = []
}
