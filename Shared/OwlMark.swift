import SwiftUI

/// The Dipwise owl, drawn with the same geometry as the app icon.
struct OwlMark: View {
  private static let bounds = CGRect(x: 298, y: 290, width: 428, height: 484)

  var body: some View {
    Canvas { context, size in
      let bounds = Self.bounds
      let scale = min(size.width / bounds.width, size.height / bounds.height)
      context.translateBy(x: (size.width - bounds.width * scale) / 2, y: (size.height - bounds.height * scale) / 2)
      context.scaleBy(x: scale, y: scale)
      context.translateBy(x: -bounds.minX, y: -bounds.minY)
      draw(in: &context)
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
    context.fill(body, with: .color(Brand.owlWhite))

    var inner = context
    inner.clip(to: body)
    inner.fill(Path(ellipseIn: CGRect(x: 214, y: 470, width: 196, height: 330)), with: .color(Brand.owlWing))
    inner.fill(Path(ellipseIn: CGRect(x: 614, y: 470, width: 196, height: 330)), with: .color(Brand.owlWing))
    inner.fill(Path(ellipseIn: circle(at: CGPoint(x: 442, y: 472), radius: 96)), with: .color(.white))
    inner.fill(Path(ellipseIn: circle(at: CGPoint(x: 582, y: 472), radius: 96)), with: .color(.white))

    let feathers = Path { path in
      let rows: [(CGFloat, [CGFloat])] = [(624, [470, 554]), (668, [428, 512, 596]), (712, [470, 554])]
      for (y, xs) in rows {
        for x in xs {
          path.move(to: CGPoint(x: x - 18, y: y))
          path.addLine(to: CGPoint(x: x, y: y + 14))
          path.addLine(to: CGPoint(x: x + 18, y: y))
        }
      }
    }
    context.stroke(feathers, with: .color(Brand.owlFeather), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))

    for x in [CGFloat(442), 582] {
      context.fill(Path(ellipseIn: circle(at: CGPoint(x: x, y: 472), radius: 60)), with: .color(Brand.owlInk))
      context.fill(Path(ellipseIn: circle(at: CGPoint(x: x, y: 472), radius: 40)), with: .color(Brand.amber))
      context.fill(Path(ellipseIn: circle(at: CGPoint(x: x, y: 472), radius: 20)), with: .color(Brand.owlInk))
      context.fill(Path(ellipseIn: circle(at: CGPoint(x: x - 15, y: 456), radius: 9)), with: .color(.white))
    }

    let beak = Path { path in
      path.move(to: CGPoint(x: 494, y: 540))
      path.addLine(to: CGPoint(x: 530, y: 540))
      path.addLine(to: CGPoint(x: 512, y: 578))
      path.closeSubpath()
    }
    context.fill(beak, with: .color(Brand.amber))
    context.stroke(beak, with: .color(Brand.amber), style: StrokeStyle(lineWidth: 14, lineJoin: .round))

    let talons = Path { path in
      for x in [CGFloat(468), 556] {
        for dx in [CGFloat(-14), 0, 14] {
          path.move(to: CGPoint(x: x + dx, y: 742))
          path.addLine(to: CGPoint(x: x + dx * 1.3, y: 770))
        }
      }
    }
    context.stroke(talons, with: .color(Brand.amber), style: StrokeStyle(lineWidth: 12, lineCap: .round))
  }

  private func circle(at center: CGPoint, radius: CGFloat) -> CGRect {
    CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
  }
}
