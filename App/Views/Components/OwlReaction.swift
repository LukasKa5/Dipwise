import Foundation
import Observation

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
  /// Hides behind his wings, then pops out wide-eyed: "Boo!"
  case peekaboo
  /// Sways side to side, wings taking turns, music notes floating up.
  case dance
  /// Two small nods: "Got it."
  case nod
  /// Squints happily while little hearts float up.
  case hearts
  /// A big, slow, sleepy yawn.
  case yawn

  /// The reactions a tap can bring, so tapping him again and again keeps surprising.
  static let onTap: [OwlReaction] = [.wave, .hop, .wink, .flap, .tilt, .surprise, .hoot, .peekaboo, .dance, .nod]

  /// Greetings already shown since launch, so Dippy says hi once rather than on every return to a screen.
  @MainActor static var shownGreetings: Set<String> = []
}

/// Lets anything in the app ask every Dippy on screen to react, like a dance when a plan is saved.
@MainActor
@Observable
final class OwlCue {
  static let shared = OwlCue()
  private(set) var reaction: OwlReaction?
  private(set) var count = 0

  func play(_ reaction: OwlReaction) {
    self.reaction = reaction
    count += 1
  }
}
