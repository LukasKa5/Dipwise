import SwiftUI

/// The Dipwise owl, drawn with the same geometry as the app icon.
/// `wingSpread` (0–1) opens the wings for flight; `blink` (0–1) closes the eyes.
struct OwlMark: View, Animatable {
  var wingSpread: Double = 0
  var blink: Double = 0
  var lookOffset: CGSize = .zero
  /// Opens just the right eye, for a sleepy peek.
  var rightEyeOpen: Double = 0

  var animatableData: AnimatablePair<AnimatablePair<Double, Double>, AnimatablePair<AnimatablePair<CGFloat, CGFloat>, Double>> {
    get { AnimatablePair(AnimatablePair(wingSpread, blink), AnimatablePair(AnimatablePair(lookOffset.width, lookOffset.height), rightEyeOpen)) }
    set {
      wingSpread = newValue.first.first
      blink = newValue.first.second
      lookOffset = CGSize(width: newValue.second.first.first, height: newValue.second.first.second)
      rightEyeOpen = newValue.second.second
    }
  }

  /// The owl's body (including feet), in icon coordinates.
  private static let bounds = CGRect(x: 298, y: 290, width: 428, height: 492)
  /// Extra room around the body so open wings aren't clipped.
  private static let margin: CGFloat = 0.8

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let canvasSize = CGSize(width: size.width * (1 + Self.margin * 2), height: size.height * (1 + Self.margin))
      Canvas { context, _ in
        let bounds = Self.bounds
        let scale = min(size.width / bounds.width, size.height / bounds.height)
        let originX = (canvasSize.width - bounds.width * scale) / 2
        let originY = canvasSize.height - size.height + (size.height - bounds.height * scale) / 2
        context.translateBy(x: originX, y: originY)
        context.scaleBy(x: scale, y: scale)
        context.translateBy(x: -bounds.minX, y: -bounds.minY)
        draw(in: &context)
      }
      .frame(width: canvasSize.width, height: canvasSize.height)
      .position(x: size.width / 2, y: size.height - canvasSize.height / 2)
      .allowsHitTesting(false)
    }
    .aspectRatio(Self.bounds.width / Self.bounds.height, contentMode: .fit)
    .accessibilityHidden(true)
  }

  private func draw(in context: inout GraphicsContext) {
    let body = Path { path in
      path.move(to: CGPoint(x: 346, y: 296))
      path.addCurve(to: CGPoint(x: 512, y: 352), control1: CGPoint(x: 396, y: 324), control2: CGPoint(x: 452, y: 352))
      path.addCurve(to: CGPoint(x: 678, y: 296), control1: CGPoint(x: 572, y: 352), control2: CGPoint(x: 628, y: 324))
      path.addCurve(to: CGPoint(x: 716, y: 556), control1: CGPoint(x: 716, y: 380), control2: CGPoint(x: 726, y: 466))
      path.addCurve(to: CGPoint(x: 512, y: 752), control1: CGPoint(x: 704, y: 680), control2: CGPoint(x: 626, y: 752))
      path.addCurve(to: CGPoint(x: 308, y: 556), control1: CGPoint(x: 398, y: 752), control2: CGPoint(x: 320, y: 680))
      path.addCurve(to: CGPoint(x: 346, y: 296), control1: CGPoint(x: 298, y: 466), control2: CGPoint(x: 308, y: 380))
      path.closeSubpath()
    }

    // Open wings sit behind the body: broad, rounded, with a scalloped feather edge.
    if wingSpread > 0.02 {
      for side in [CGFloat(-1), 1] {
        var wingContext = context
        let shoulder = CGPoint(x: 512 + side * 168, y: 500)
        wingContext.translateBy(x: shoulder.x, y: shoulder.y)
        wingContext.rotate(by: .degrees(-Double(side) * (15 + 100 * wingSpread)))
        let length: CGFloat = 250
        let width: CGFloat = 150
        let tip = CGPoint(x: side * width * 0.45, y: length)
        let trailingEnd = CGPoint(x: side * -width * 0.25, y: length * 0.28)
        let wing = Path { path in
          path.move(to: CGPoint(x: side * -20, y: -10))
          path.addQuadCurve(to: CGPoint(x: side * width * 0.95, y: length * 0.55), control: CGPoint(x: side * width * 1.15, y: length * 0.05))
          path.addQuadCurve(to: tip, control: CGPoint(x: side * width * 0.95, y: length * 0.9))
          // Scalloped trailing edge from the tip back toward the body.
          let scallops = 5
          var previous = tip
          for index in 1...scallops {
            let t = CGFloat(index) / CGFloat(scallops)
            let point = CGPoint(x: tip.x + (trailingEnd.x - tip.x) * t, y: tip.y + (trailingEnd.y - tip.y) * t)
            let middle = CGPoint(x: (previous.x + point.x) / 2, y: (previous.y + point.y) / 2)
            let control = CGPoint(x: middle.x - side * 18, y: middle.y + 26)
            path.addQuadCurve(to: point, control: control)
            previous = point
          }
          path.addQuadCurve(to: CGPoint(x: side * -20, y: -10), control: CGPoint(x: side * -width * 0.35, y: length * 0.08))
          path.closeSubpath()
        }
        wingContext.fill(wing, with: .color(Brand.owlWing))
        // Feather lines fanning toward the scallops.
        let feathers = Path { path in
          for index in 1..<5 {
            let t = CGFloat(index) / 5
            let edge = CGPoint(x: tip.x + (trailingEnd.x - tip.x) * t, y: tip.y + (trailingEnd.y - tip.y) * t)
            path.move(to: CGPoint(x: side * width * 0.3, y: length * 0.25))
            path.addQuadCurve(to: CGPoint(x: edge.x + side * 6, y: edge.y - 18), control: CGPoint(x: side * width * 0.45, y: (length * 0.25 + edge.y) / 2))
          }
        }
        wingContext.stroke(feathers, with: .color(Brand.owlFeather.opacity(0.8)), style: StrokeStyle(lineWidth: 6, lineCap: .round))
        wingContext.stroke(wing, with: .color(Brand.owlFeather), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
      }
    }

    // Feet emerge from under the body.
    let feet = Path { path in
      for x in [CGFloat(476), 548] {
        for dx in [CGFloat(-13), 0, 13] {
          path.move(to: CGPoint(x: x + dx * 0.6, y: 724))
          path.addLine(to: CGPoint(x: x + dx * 1.35, y: 778))
        }
      }
    }
    context.stroke(feet, with: .color(Brand.amber), style: StrokeStyle(lineWidth: 14, lineCap: .round))

    context.fill(body, with: .color(Brand.owlWhite))
    context.stroke(body, with: .color(Brand.owlFeather.opacity(0.9)), style: StrokeStyle(lineWidth: 8, lineJoin: .round))

    var inner = context
    inner.clip(to: body)
    let foldedWings = Path { path in
      path.move(to: CGPoint(x: 306, y: 520))
      path.addCurve(to: CGPoint(x: 440, y: 756), control1: CGPoint(x: 392, y: 548), control2: CGPoint(x: 444, y: 670))
      path.addLine(to: CGPoint(x: 240, y: 780))
      path.addLine(to: CGPoint(x: 240, y: 520))
      path.closeSubpath()
      path.move(to: CGPoint(x: 718, y: 520))
      path.addCurve(to: CGPoint(x: 584, y: 756), control1: CGPoint(x: 632, y: 548), control2: CGPoint(x: 580, y: 670))
      path.addLine(to: CGPoint(x: 784, y: 780))
      path.addLine(to: CGPoint(x: 784, y: 520))
      path.closeSubpath()
    }
    inner.opacity = 1 - min(1, wingSpread * 1.5)
    inner.fill(foldedWings, with: .color(Brand.owlWing))
    let wingLines = Path { path in
      path.move(to: CGPoint(x: 330, y: 600))
      path.addQuadCurve(to: CGPoint(x: 392, y: 700), control: CGPoint(x: 372, y: 640))
      path.move(to: CGPoint(x: 694, y: 600))
      path.addQuadCurve(to: CGPoint(x: 632, y: 700), control: CGPoint(x: 652, y: 640))
    }
    inner.stroke(wingLines, with: .color(Brand.owlFeather), style: StrokeStyle(lineWidth: 9, lineCap: .round))
    inner.opacity = 1
    inner.fill(Path(ellipseIn: circle(at: CGPoint(x: 446, y: 468), radius: 84)), with: .color(.white))
    inner.fill(Path(ellipseIn: circle(at: CGPoint(x: 578, y: 468), radius: 84)), with: .color(.white))

    let chest = Path { path in
      let rows: [(CGFloat, [CGFloat])] = [(624, [486, 538]), (666, [460, 512, 564]), (708, [486, 538])]
      for (y, xs) in rows {
        for x in xs {
          path.move(to: CGPoint(x: x - 15, y: y))
          path.addLine(to: CGPoint(x: x, y: y + 12))
          path.addLine(to: CGPoint(x: x + 15, y: y))
        }
      }
    }
    context.stroke(chest, with: .color(Brand.owlFeather), style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))

    for x in [CGFloat(446), 578] {
      let openness = max(0.08, x > 512 ? max(1 - blink, rightEyeOpen) : 1 - blink)
      let center = CGPoint(x: x, y: 468)
      var eye = context
      eye.translateBy(x: center.x, y: center.y)
      eye.scaleBy(x: 1, y: openness)
      eye.fill(Path(ellipseIn: circle(at: .zero, radius: 56)), with: .color(Brand.owlInk))
      if openness > 0.3 {
        let look = CGPoint(x: lookOffset.width * 14, y: lookOffset.height * 14)
        eye.fill(Path(ellipseIn: circle(at: look, radius: 38)), with: .color(Brand.amber))
        eye.fill(Path(ellipseIn: circle(at: look, radius: 19)), with: .color(Brand.owlInk))
        eye.fill(Path(ellipseIn: circle(at: CGPoint(x: look.x - 14, y: look.y - 15), radius: 9)), with: .color(.white))
      }
    }

    let beak = Path { path in
      path.move(to: CGPoint(x: 495, y: 540))
      path.addLine(to: CGPoint(x: 529, y: 540))
      path.addLine(to: CGPoint(x: 512, y: 576))
      path.closeSubpath()
    }
    context.fill(beak, with: .color(Brand.amber))
    context.stroke(beak, with: .color(Brand.amber), style: StrokeStyle(lineWidth: 14, lineJoin: .round))
  }

  private func circle(at center: CGPoint, radius: CGFloat) -> CGRect {
    CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
  }
}
