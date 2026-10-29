import SwiftUI

/// What Dippy wears. Outfits are achievements' rewards (the top hat comes with Pro), worn from the Achievements, and
/// shown everywhere Dippy appears: the app, the widgets, and Apple Watch. Dippy himself never changes underneath.
enum DippyOutfit: String, CaseIterable, Identifiable, Codable {
  case none
  case bowTie
  case beanie
  case headphones
  case partyHat
  case crown
  case graduationCap
  case topHat

  var id: Self { self }

  var title: String {
    switch self {
    case .none: String(localized: "Just Dippy")
    case .bowTie: String(localized: "Bow Tie")
    case .beanie: String(localized: "Beanie")
    case .headphones: String(localized: "Headphones")
    case .partyHat: String(localized: "Party Hat")
    case .crown: String(localized: "Crown")
    case .graduationCap: String(localized: "Graduation Cap")
    case .topHat: String(localized: "Top Hat")
    }
  }

  /// The achievement that unlocks it. Every outfit is an achievement's reward; the top hat is Pro's.
  var achievementID: String? {
    switch self {
    case .none: nil
    case .bowTie: "first-plan"
    case .beanie: "streak-7"
    case .headphones: "diversified"
    case .partyHat: "dip-catcher"
    case .crown: "streak-30"
    case .graduationCap: "wise"
    case .topHat: "pro"
    }
  }

  var requiresPro: Bool { self == .topHat }

  /// The outfit an achievement awards, if any.
  static func reward(for achievementID: String) -> DippyOutfit? {
    allCases.first { $0.achievementID == achievementID }
  }

  private static let key = "dippy.outfit"

  /// What Dippy wears right now, shared with the widgets and the watch through the App Group.
  static var equipped: DippyOutfit {
    get { AppGroup.defaults.string(forKey: key).flatMap(DippyOutfit.init(rawValue:)) ?? .none }
    set { AppGroup.defaults.set(newValue.rawValue, forKey: key) }
  }
}

extension EnvironmentValues {
  /// Shows Dippy in a specific outfit, like when trying one on in the Wardrobe. Nil uses the equipped one.
  @Entry var dippyOutfit: DippyOutfit? = nil
}

// MARK: - Drawing

extension DippyOutfit {
  /// Draws the outfit in the icon's coordinates, on top of Dippy. `body` is his outline, for clipping.
  func draw(in context: inout GraphicsContext, body: Path) {
    let ink = Brand.owlInk
    switch self {
    case .none:
      break

    case .bowTie:
      let left = Path { path in
        path.move(to: CGPoint(x: 512, y: 604))
        path.addLine(to: CGPoint(x: 448, y: 570))
        path.addLine(to: CGPoint(x: 448, y: 638))
        path.closeSubpath()
      }
      let right = Path { path in
        path.move(to: CGPoint(x: 512, y: 604))
        path.addLine(to: CGPoint(x: 576, y: 570))
        path.addLine(to: CGPoint(x: 576, y: 638))
        path.closeSubpath()
      }
      for side in [left, right] {
        context.fill(side, with: .color(Brand.sell))
        context.stroke(side, with: .color(Brand.sell), style: StrokeStyle(lineWidth: 12, lineJoin: .round))
      }
      context.fill(Path(roundedRect: CGRect(x: 496, y: 588, width: 32, height: 32), cornerRadius: 9), with: .color(Color(red: 0.75, green: 0.15, blue: 0.2)))

    case .beanie:
      let dome = Path { path in
        path.move(to: CGPoint(x: 340, y: 284))
        path.addCurve(to: CGPoint(x: 512, y: 150), control1: CGPoint(x: 350, y: 190), control2: CGPoint(x: 430, y: 150))
        path.addCurve(to: CGPoint(x: 684, y: 284), control1: CGPoint(x: 594, y: 150), control2: CGPoint(x: 674, y: 190))
        path.addCurve(to: CGPoint(x: 512, y: 340), control1: CGPoint(x: 628, y: 312), control2: CGPoint(x: 572, y: 340))
        path.addCurve(to: CGPoint(x: 340, y: 284), control1: CGPoint(x: 452, y: 340), control2: CGPoint(x: 396, y: 312))
        path.closeSubpath()
      }
      context.fill(dome, with: .color(Brand.buy))
      let band = Path { path in
        path.move(to: CGPoint(x: 340, y: 290))
        path.addCurve(to: CGPoint(x: 512, y: 346), control1: CGPoint(x: 396, y: 318), control2: CGPoint(x: 452, y: 346))
        path.addCurve(to: CGPoint(x: 684, y: 290), control1: CGPoint(x: 572, y: 346), control2: CGPoint(x: 628, y: 318))
      }
      context.stroke(band, with: .color(Color(red: 0.04, green: 0.5, blue: 0.32)), style: StrokeStyle(lineWidth: 40, lineCap: .round))
      context.fill(Path(ellipseIn: CGRect(x: 482, y: 116, width: 60, height: 60)), with: .color(.white))

    case .headphones:
      let arc = Path { path in
        path.move(to: CGPoint(x: 318, y: 476))
        path.addCurve(to: CGPoint(x: 706, y: 476), control1: CGPoint(x: 300, y: 130), control2: CGPoint(x: 724, y: 130))
      }
      context.stroke(arc, with: .color(Color(white: 0.22)), style: StrokeStyle(lineWidth: 22, lineCap: .round))
      for x in [CGFloat(280), 680] {
        context.fill(Path(roundedRect: CGRect(x: x, y: 420, width: 64, height: 120), cornerRadius: 26), with: .color(Brand.buy))
        context.stroke(Path(roundedRect: CGRect(x: x, y: 420, width: 64, height: 120), cornerRadius: 26), with: .color(Color(white: 0.22)), lineWidth: 8)
      }

    case .partyHat:
      let cone = Path { path in
        path.move(to: CGPoint(x: 446, y: 346))
        path.addLine(to: CGPoint(x: 540, y: 140))
        path.addLine(to: CGPoint(x: 592, y: 342))
        path.closeSubpath()
      }
      context.fill(cone, with: .color(Brand.amber))
      var stripes = context
      stripes.clip(to: cone)
      for offset in stride(from: CGFloat(-200), through: 260, by: 52) {
        stripes.stroke(Path { $0.move(to: CGPoint(x: 400 + offset, y: 360)); $0.addLine(to: CGPoint(x: 520 + offset, y: 120)) },
                       with: .color(Brand.sell), lineWidth: 16)
      }
      context.fill(Path(ellipseIn: CGRect(x: 516, y: 112, width: 50, height: 50)), with: .color(Brand.buy))

    case .crown:
      let crown = Path { path in
        path.move(to: CGPoint(x: 428, y: 344))
        path.addLine(to: CGPoint(x: 422, y: 236))
        path.addLine(to: CGPoint(x: 470, y: 290))
        path.addLine(to: CGPoint(x: 512, y: 214))
        path.addLine(to: CGPoint(x: 554, y: 290))
        path.addLine(to: CGPoint(x: 602, y: 236))
        path.addLine(to: CGPoint(x: 596, y: 344))
        path.closeSubpath()
      }
      context.fill(crown, with: .color(Brand.amber))
      context.stroke(crown, with: .color(Color(red: 0.85, green: 0.55, blue: 0.05)), style: StrokeStyle(lineWidth: 8, lineJoin: .round))
      context.fill(Path(ellipseIn: CGRect(x: 498, y: 292, width: 28, height: 28)), with: .color(Brand.sell))
      for x in [CGFloat(454), 570] {
        context.fill(Path(ellipseIn: CGRect(x: x - 11, y: 308, width: 22, height: 22)), with: .color(Brand.buy))
      }

    case .graduationCap:
      let cap = Path { path in
        path.move(to: CGPoint(x: 432, y: 236))
        path.addLine(to: CGPoint(x: 592, y: 236))
        path.addLine(to: CGPoint(x: 600, y: 340))
        path.addQuadCurve(to: CGPoint(x: 424, y: 340), control: CGPoint(x: 512, y: 372))
        path.closeSubpath()
      }
      context.fill(cap, with: .color(ink))
      let board = Path { path in
        path.move(to: CGPoint(x: 352, y: 226))
        path.addLine(to: CGPoint(x: 512, y: 182))
        path.addLine(to: CGPoint(x: 672, y: 226))
        path.addLine(to: CGPoint(x: 512, y: 270))
        path.closeSubpath()
      }
      context.fill(board, with: .color(ink))
      context.stroke(board, with: .color(Color(white: 0.3)), style: StrokeStyle(lineWidth: 4, lineJoin: .round))
      context.stroke(Path { path in
        path.move(to: CGPoint(x: 512, y: 226))
        path.addLine(to: CGPoint(x: 640, y: 246))
        path.addLine(to: CGPoint(x: 646, y: 330))
      }, with: .color(Brand.amber), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
      context.fill(Path(roundedRect: CGRect(x: 634, y: 322, width: 24, height: 40), cornerRadius: 6), with: .color(Brand.amber))

    case .topHat:
      context.fill(Path(ellipseIn: CGRect(x: 398, y: 302, width: 228, height: 54)), with: .color(ink))
      context.fill(Path(roundedRect: CGRect(x: 446, y: 140, width: 132, height: 190), cornerRadius: 10), with: .color(ink))
      context.fill(Path(CGRect(x: 446, y: 282, width: 132, height: 28)), with: .color(Brand.sell))
      context.stroke(Path { $0.move(to: CGPoint(x: 462, y: 160)); $0.addLine(to: CGPoint(x: 462, y: 270)) },
                     with: .color(.white.opacity(0.2)), style: StrokeStyle(lineWidth: 10, lineCap: .round))
    }
  }
}
