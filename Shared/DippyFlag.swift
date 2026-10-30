import SwiftUI

/// A country's flag on a little pole that Dippy holds up beside him, drawn flat like the icon with a gentle wave.
/// Drawn in the owl's icon coordinates (1024 points), off to his right.
struct DippyFlag {
  var region: String

  private static let flagRect = CGRect(x: 760, y: 236, width: 210, height: 140)

  func draw(in context: inout GraphicsContext) {
    let rect = Self.flagRect
    // The pole, from his wing up past the top of the flag, with a gold finial.
    let pole = Path { path in
      path.move(to: CGPoint(x: rect.minX - 6, y: 650))
      path.addLine(to: CGPoint(x: rect.minX - 6, y: rect.minY - 18))
    }
    context.stroke(pole, with: .color(Brand.owlInk), style: StrokeStyle(lineWidth: 14, lineCap: .round))
    context.fill(Path(ellipseIn: CGRect(x: rect.minX - 22, y: rect.minY - 44, width: 32, height: 32)), with: .color(Brand.amber))

    // The cloth, with a soft wave along the top and bottom.
    let wave: CGFloat = 10
    let cloth = Path { path in
      path.move(to: CGPoint(x: rect.minX, y: rect.minY))
      path.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                    control1: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.minY - wave),
                    control2: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.minY + wave))
      path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
      path.addCurve(to: CGPoint(x: rect.minX, y: rect.maxY),
                    control1: CGPoint(x: rect.minX + rect.width * 0.66, y: rect.maxY + wave),
                    control2: CGPoint(x: rect.minX + rect.width * 0.33, y: rect.maxY - wave))
      path.closeSubpath()
    }
    var flag = context
    flag.clip(to: cloth)
    paint(in: &flag, rect: rect.insetBy(dx: 0, dy: -wave))
    // Light catching the folds.
    for (offset, alpha) in [(0.3, 0.14), (0.72, 0.1)] {
      let x = rect.minX + rect.width * offset
      flag.fill(Path(CGRect(x: x - 14, y: rect.minY - wave, width: 28, height: rect.height + wave * 2)), with: .color(.white.opacity(alpha)))
    }
    context.stroke(cloth, with: .color(Brand.owlInk.opacity(0.18)), lineWidth: 3)
  }

  // MARK: Patterns

  private func paint(in context: inout GraphicsContext, rect: CGRect) {
    func fill(_ r: CGRect, _ color: Color) { context.fill(Path(r), with: .color(color)) }
    func horizontal(_ colors: [Color], weights: [CGFloat]? = nil) {
      let weights = weights ?? colors.map { _ in 1 }
      let total = weights.reduce(0, +)
      var y = rect.minY
      for (color, weight) in zip(colors, weights) {
        let height = rect.height * weight / total
        fill(CGRect(x: rect.minX, y: y, width: rect.width, height: height + 1), color)
        y += height
      }
    }
    func vertical(_ colors: [Color], weights: [CGFloat]? = nil) {
      let weights = weights ?? colors.map { _ in 1 }
      let total = weights.reduce(0, +)
      var x = rect.minX
      for (color, weight) in zip(colors, weights) {
        let width = rect.width * weight / total
        fill(CGRect(x: x, y: rect.minY, width: width + 1, height: rect.height), color)
        x += width
      }
    }
    let red = Color(red: 0.82, green: 0.11, blue: 0.16)
    let white = Color.white
    let center = CGPoint(x: rect.midX, y: rect.midY)

    switch region {
    case "US":
      horizontal((0..<13).map { $0 % 2 == 0 ? red : white })
      let canton = CGRect(x: rect.minX, y: rect.minY, width: rect.width * 0.42, height: rect.height * 7 / 13)
      fill(canton, Color(red: 0.12, green: 0.18, blue: 0.42))
      for row in 0..<4 {
        for column in 0..<5 {
          let x = canton.minX + canton.width * (CGFloat(column) + 0.5 + (row % 2 == 0 ? 0 : 0.25)) / 5.25
          let y = canton.minY + canton.height * (CGFloat(row) + 0.6) / 4.4
          context.fill(Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)), with: .color(white))
        }
      }
    case "CA":
      vertical([red, white, red], weights: [1, 2, 1])
      let leaf = Path { path in
        let points: [(CGFloat, CGFloat)] = [(0, -42), (10, -22), (26, -30), (20, -6), (40, -12), (30, 6), (36, 12), (8, 14), (6, 40),
                                            (-6, 40), (-8, 14), (-36, 12), (-30, 6), (-40, -12), (-20, -6), (-26, -30), (-10, -22)]
        path.move(to: CGPoint(x: center.x + points[0].0, y: center.y + points[0].1))
        for point in points.dropFirst() { path.addLine(to: CGPoint(x: center.x + point.0, y: center.y + point.1)) }
        path.closeSubpath()
      }
      context.fill(leaf, with: .color(red))
    case "BR":
      fill(rect, Color(red: 0.0, green: 0.6, blue: 0.29))
      let diamond = Path { path in
        path.move(to: CGPoint(x: rect.midX, y: rect.minY + 16))
        path.addLine(to: CGPoint(x: rect.maxX - 18, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 16))
        path.addLine(to: CGPoint(x: rect.minX + 18, y: rect.midY))
        path.closeSubpath()
      }
      context.fill(diamond, with: .color(Color(red: 1.0, green: 0.82, blue: 0.0)))
      context.fill(Path(ellipseIn: CGRect(x: center.x - 34, y: center.y - 34, width: 68, height: 68)), with: .color(Color(red: 0.0, green: 0.15, blue: 0.46)))
      context.stroke(Path { $0.move(to: CGPoint(x: center.x - 34, y: center.y - 4)); $0.addQuadCurve(to: CGPoint(x: center.x + 34, y: center.y + 6), control: CGPoint(x: center.x, y: center.y - 18)) },
                     with: .color(white), lineWidth: 6)
    case "GB":
      fill(rect, Color(red: 0.0, green: 0.14, blue: 0.43))
      let diagonals = Path { path in
        path.move(to: CGPoint(x: rect.minX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
      }
      context.stroke(diagonals, with: .color(white), lineWidth: 30)
      context.stroke(diagonals, with: .color(red), lineWidth: 10)
      let cross = Path { path in
        path.move(to: CGPoint(x: rect.midX, y: rect.minY)); path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.move(to: CGPoint(x: rect.minX, y: rect.midY)); path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
      }
      context.stroke(cross, with: .color(white), lineWidth: 44)
      context.stroke(cross, with: .color(red), lineWidth: 26)
    case "DE":
      horizontal([Color(white: 0.08), Color(red: 0.87, green: 0.0, blue: 0.0), Color(red: 1.0, green: 0.8, blue: 0.0)])
    case "FR":
      vertical([Color(red: 0.0, green: 0.14, blue: 0.58), white, Color(red: 0.93, green: 0.16, blue: 0.22)])
    case "IT":
      vertical([Color(red: 0.0, green: 0.57, blue: 0.27), white, Color(red: 0.81, green: 0.17, blue: 0.21)])
    case "ES":
      horizontal([Color(red: 0.78, green: 0.04, blue: 0.12), Color(red: 1.0, green: 0.77, blue: 0.0), Color(red: 0.78, green: 0.04, blue: 0.12)], weights: [1, 2, 1])
    case "NL":
      horizontal([Color(red: 0.68, green: 0.11, blue: 0.16), white, Color(red: 0.13, green: 0.28, blue: 0.55)])
    case "CH":
      fill(rect, Color(red: 0.85, green: 0.0, blue: 0.0))
      fill(CGRect(x: center.x - 12, y: center.y - 42, width: 24, height: 84), white)
      fill(CGRect(x: center.x - 42, y: center.y - 12, width: 84, height: 24), white)
    case "PL":
      horizontal([white, Color(red: 0.86, green: 0.08, blue: 0.24)])
    case "CZ":
      horizontal([white, Color(red: 0.84, green: 0.08, blue: 0.13)])
      let triangle = Path { path in
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
      }
      context.fill(triangle, with: .color(Color(red: 0.07, green: 0.27, blue: 0.49)))
    case "SK":
      horizontal([white, Color(red: 0.04, green: 0.31, blue: 0.64), Color(red: 0.93, green: 0.11, blue: 0.14)])
      // The shield: red, with the white double cross on blue hills, outlined in white.
      let shield = Path { path in
        let x = rect.minX + 36, y = rect.minY + 26
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + 56, y: y))
        path.addLine(to: CGPoint(x: x + 56, y: y + 52))
        path.addQuadCurve(to: CGPoint(x: x + 28, y: y + 88), control: CGPoint(x: x + 56, y: y + 78))
        path.addQuadCurve(to: CGPoint(x: x, y: y + 52), control: CGPoint(x: x, y: y + 78))
        path.closeSubpath()
      }
      context.fill(shield, with: .color(Color(red: 0.93, green: 0.11, blue: 0.14)))
      var inside = context
      inside.clip(to: shield)
      inside.fill(Path(ellipseIn: CGRect(x: rect.minX + 28, y: rect.minY + 88, width: 72, height: 50)), with: .color(Color(red: 0.04, green: 0.31, blue: 0.64)))
      let cx = rect.minX + 64
      inside.fill(Path(CGRect(x: cx - 4, y: rect.minY + 36, width: 8, height: 58)), with: .color(white))
      inside.fill(Path(CGRect(x: cx - 16, y: rect.minY + 48, width: 32, height: 7)), with: .color(white))
      inside.fill(Path(CGRect(x: cx - 20, y: rect.minY + 64, width: 40, height: 7)), with: .color(white))
      context.stroke(shield, with: .color(white), lineWidth: 5)
    case "JP":
      fill(rect, white)
      context.fill(Path(ellipseIn: CGRect(x: center.x - 40, y: center.y - 40, width: 80, height: 80)), with: .color(Color(red: 0.74, green: 0.0, blue: 0.18)))
    case "KR":
      fill(rect, white)
      let circle = CGRect(x: center.x - 34, y: center.y - 34, width: 68, height: 68)
      context.fill(Path(ellipseIn: circle), with: .color(Color(red: 0.0, green: 0.2, blue: 0.53)))
      var top = context
      top.clip(to: Path(CGRect(x: circle.minX - 2, y: circle.minY - 2, width: circle.width + 4, height: circle.height / 2 + 2)))
      top.fill(Path(ellipseIn: circle), with: .color(Color(red: 0.8, green: 0.0, blue: 0.2)))
      context.fill(Path(ellipseIn: CGRect(x: center.x - 34, y: center.y - 17, width: 34, height: 34)), with: .color(Color(red: 0.8, green: 0.0, blue: 0.2)))
      context.fill(Path(ellipseIn: CGRect(x: center.x, y: center.y - 17, width: 34, height: 34)), with: .color(Color(red: 0.0, green: 0.2, blue: 0.53)))
      for (dx, dy) in [(-1.0, -1.0), (1.0, -1.0), (-1.0, 1.0), (1.0, 1.0)] {
        for bar in 0..<3 {
          let x = center.x + CGFloat(dx) * 66 - 14
          let y = center.y + CGFloat(dy) * 42 - 10 + CGFloat(bar) * 8
          context.fill(Path(CGRect(x: x, y: y, width: 28, height: 5)), with: .color(.black))
        }
      }
    default:
      fill(rect, white)
    }
  }
}

extension DippyOutfit {
  /// The flag this outfit flies, if it's one of the country flags.
  var flag: DippyFlag? {
    let name = rawValue
    guard name.hasPrefix("flag"), name.count == 6 else { return nil }
    return DippyFlag(region: String(name.suffix(2)))
  }
}
