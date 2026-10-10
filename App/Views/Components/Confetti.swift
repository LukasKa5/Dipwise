import SwiftUI

/// A short confetti burst in brand colors. Plays each time `trigger` changes.
struct Confetti: View {
  var trigger: Int
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var start: Date?

  private struct Piece {
    var x: Double
    var velocity: CGVector
    var spin: Double
    var color: Color
    var size: CGSize
  }

  private static let pieces: [Piece] = {
    var generator = SystemRandomNumberGenerator()
    let colors: [Color] = [Brand.buy, Brand.amber, Brand.sell, .white, Brand.mint, .yellow]
    return (0..<90).map { _ in
      Piece(
        x: Double.random(in: 0.2...0.8, using: &generator),
        velocity: CGVector(dx: Double.random(in: -260...260, using: &generator), dy: Double.random(in: -820 ... -420, using: &generator)),
        spin: Double.random(in: -8...8, using: &generator),
        color: colors.randomElement(using: &generator) ?? .white,
        size: CGSize(width: Double.random(in: 6...11, using: &generator), height: Double.random(in: 9...16, using: &generator))
      )
    }
  }()

  var body: some View {
    TimelineView(.animation(paused: start == nil)) { timeline in
      Canvas { context, size in
        guard let start else { return }
        let t = timeline.date.timeIntervalSince(start)
        guard t < 3 else { return }
        for piece in Self.pieces {
          let x = piece.x * size.width + piece.velocity.dx * t
          let y = size.height * 0.75 + piece.velocity.dy * t + 900 * t * t / 2
          var pieceContext = context
          pieceContext.opacity = max(0, 1 - t / 3)
          pieceContext.translateBy(x: x, y: y)
          pieceContext.rotate(by: .radians(piece.spin * t))
          pieceContext.fill(Path(roundedRect: CGRect(origin: CGPoint(x: -piece.size.width / 2, y: -piece.size.height / 2), size: piece.size), cornerRadius: 2), with: .color(piece.color))
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
    .onChange(of: trigger) {
      guard !reduceMotion else { return }
      start = .now
      Task {
        try? await Task.sleep(for: .seconds(3.1))
        start = nil
      }
    }
  }
}

/// A floating "+20 XP" badge.
struct XPToast: View {
  var points: Int

  var body: some View {
    Label("+\(points) XP", systemImage: "sparkles")
      .font(.headline)
      .foregroundStyle(Brand.owlInk)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(Brand.amber, in: .capsule)
      .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
  }
}
