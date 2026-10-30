import SwiftUI

/// What Dippy wears. Every achievement awards an outfit, the top hat comes with Pro, and Pro members can also fly
/// their country's flag. Outfits are worn from the Achievements and shown everywhere Dippy appears: the app, the
/// widgets, and Apple Watch. Dippy himself never changes underneath.
enum DippyOutfit: String, CaseIterable, Identifiable, Codable {
  case none
  case bowTie
  case captainCap
  case hardHat
  case beanie
  case headphones
  case partyHat
  case pocketWatch
  case flockCap
  case beret
  case bankerVisor
  case crown
  case graduationCap
  case topHat
  case flagUS, flagCA, flagBR, flagGB, flagDE, flagFR, flagIT, flagES, flagNL, flagCH, flagPL, flagCZ, flagSK, flagJP, flagKR

  var id: Self { self }

  var title: String {
    switch self {
    case .none: String(localized: "Just Dippy")
    case .bowTie: String(localized: "Bow Tie")
    case .captainCap: String(localized: "Captain's Cap")
    case .hardHat: String(localized: "Hard Hat")
    case .beanie: String(localized: "Beanie")
    case .headphones: String(localized: "Headphones")
    case .partyHat: String(localized: "Party Hat")
    case .pocketWatch: String(localized: "Pocket Watch")
    case .flockCap: String(localized: "Flock Cap")
    case .beret: String(localized: "Writer's Beret")
    case .bankerVisor: String(localized: "Banker's Visor")
    case .crown: String(localized: "Crown")
    case .graduationCap: String(localized: "Graduation Cap")
    case .topHat: String(localized: "Top Hat")
    default: flag.map { Locale.current.localizedString(forRegionCode: $0.region) ?? $0.region } ?? ""
    }
  }

  /// The achievement that unlocks it: every achievement awards one. The top hat is Pro's; flags come with Pro too.
  var achievementID: String? {
    switch self {
    case .bowTie: "first-plan"
    case .captainCap: "full-plan"
    case .hardHat: "toolkit"
    case .beanie: "streak-7"
    case .headphones: "diversified"
    case .partyHat: "dip-catcher"
    case .pocketWatch: "patient"
    case .flockCap: "flock-voice"
    case .beret: "journal"
    case .bankerVisor: "income"
    case .crown: "streak-30"
    case .graduationCap: "wise"
    case .topHat: "pro"
    default: nil
    }
  }

  var requiresPro: Bool { self == .topHat || flag != nil }

  /// How far the outfit reaches beyond Dippy himself, in the icon's coordinates, or nil when it stays on him.
  var extent: CGRect? {
    switch self {
    case .captainCap: CGRect(x: 380, y: 196, width: 264, height: 1)
    case .hardHat: CGRect(x: 350, y: 166, width: 324, height: 1)
    case .beanie: CGRect(x: 340, y: 114, width: 344, height: 1)
    case .headphones: CGRect(x: 280, y: 212, width: 464, height: 1)
    case .partyHat: CGRect(x: 446, y: 110, width: 146, height: 1)
    case .flockCap: CGRect(x: 392, y: 174, width: 318, height: 1)
    case .beret: CGRect(x: 368, y: 188, width: 316, height: 1)
    case .crown: CGRect(x: 420, y: 212, width: 184, height: 1)
    case .graduationCap: CGRect(x: 352, y: 180, width: 320, height: 1)
    case .topHat: CGRect(x: 398, y: 138, width: 228, height: 1)
    default: flag != nil ? CGRect(x: 732, y: 188, width: 248, height: 470) : nil
    }
  }

  /// The flags Pro members can fly, one per country.
  static let flags: [DippyOutfit] = allCases.filter { $0.flag != nil }

  /// The outfit an achievement awards, if any.
  static func reward(for achievementID: String) -> DippyOutfit? {
    allCases.first { $0.achievementID == achievementID }
  }

  static let storageKey = "dippy.outfit"
  private static let key = storageKey

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

    case .captainCap:
      // A white captain's cap with a navy band, a black visor, and a gold badge: the plan for the whole voyage.
      let crownShape = Path { path in
        path.move(to: CGPoint(x: 410, y: 316))
        path.addCurve(to: CGPoint(x: 386, y: 232), control1: CGPoint(x: 394, y: 290), control2: CGPoint(x: 372, y: 252))
        path.addCurve(to: CGPoint(x: 638, y: 232), control1: CGPoint(x: 440, y: 196), control2: CGPoint(x: 584, y: 196))
        path.addCurve(to: CGPoint(x: 614, y: 316), control1: CGPoint(x: 652, y: 252), control2: CGPoint(x: 630, y: 290))
        path.closeSubpath()
      }
      context.fill(crownShape, with: .color(.white))
      context.stroke(crownShape, with: .color(Brand.owlWing), style: StrokeStyle(lineWidth: 6, lineJoin: .round))
      context.fill(Path(roundedRect: CGRect(x: 408, y: 292, width: 208, height: 40), cornerRadius: 8), with: .color(ink))
      let visor = Path { path in
        path.move(to: CGPoint(x: 420, y: 326))
        path.addQuadCurve(to: CGPoint(x: 604, y: 326), control: CGPoint(x: 512, y: 384))
        path.addQuadCurve(to: CGPoint(x: 420, y: 326), control: CGPoint(x: 512, y: 350))
        path.closeSubpath()
      }
      context.fill(visor, with: .color(Color(white: 0.12)))
      context.fill(Path(ellipseIn: CGRect(x: 490, y: 238, width: 44, height: 44)), with: .color(Brand.amber))
      context.fill(Path(ellipseIn: CGRect(x: 502, y: 250, width: 20, height: 20)), with: .color(Color(red: 0.85, green: 0.55, blue: 0.05)))

    case .hardHat:
      // A builder's hard hat: the toolkit is put to work.
      let dome = Path { path in
        path.move(to: CGPoint(x: 384, y: 330))
        path.addCurve(to: CGPoint(x: 512, y: 168), control1: CGPoint(x: 384, y: 232), control2: CGPoint(x: 440, y: 168))
        path.addCurve(to: CGPoint(x: 640, y: 330), control1: CGPoint(x: 584, y: 168), control2: CGPoint(x: 640, y: 232))
        path.closeSubpath()
      }
      context.fill(dome, with: .color(Brand.amber))
      context.fill(Path(roundedRect: CGRect(x: 494, y: 172, width: 36, height: 158), cornerRadius: 14), with: .color(Color(red: 1, green: 0.8, blue: 0.35)))
      context.fill(Path(roundedRect: CGRect(x: 350, y: 314, width: 324, height: 36), cornerRadius: 18), with: .color(Color(red: 0.88, green: 0.56, blue: 0.06)))

    case .pocketWatch:
      // A gold pocket watch on a chain across his chest: patience, measured.
      let chain = Path { path in
        path.move(to: CGPoint(x: 410, y: 612))
        path.addQuadCurve(to: CGPoint(x: 560, y: 640), control: CGPoint(x: 480, y: 668))
      }
      context.stroke(chain, with: .color(Brand.amber), style: StrokeStyle(lineWidth: 7, lineCap: .round, dash: [2, 12]))
      context.fill(Path(ellipseIn: CGRect(x: 552, y: 600, width: 20, height: 20)), with: .color(Brand.amber))
      context.fill(Path(ellipseIn: CGRect(x: 520, y: 620, width: 104, height: 104)), with: .color(Brand.amber))
      context.fill(Path(ellipseIn: CGRect(x: 532, y: 632, width: 80, height: 80)), with: .color(.white))
      context.stroke(Path { path in
        path.move(to: CGPoint(x: 572, y: 672)); path.addLine(to: CGPoint(x: 572, y: 646))
        path.move(to: CGPoint(x: 572, y: 672)); path.addLine(to: CGPoint(x: 592, y: 682))
      }, with: .color(ink), style: StrokeStyle(lineWidth: 6, lineCap: .round))

    case .flockCap:
      // The flock's own baseball cap, in mint, the bill turned to the side.
      let dome = Path { path in
        path.move(to: CGPoint(x: 396, y: 328))
        path.addCurve(to: CGPoint(x: 512, y: 186), control1: CGPoint(x: 392, y: 236), control2: CGPoint(x: 444, y: 186))
        path.addCurve(to: CGPoint(x: 628, y: 328), control1: CGPoint(x: 580, y: 186), control2: CGPoint(x: 632, y: 236))
        path.closeSubpath()
      }
      context.fill(dome, with: .color(Brand.buy))
      context.stroke(Path { $0.move(to: CGPoint(x: 512, y: 192)); $0.addLine(to: CGPoint(x: 512, y: 324)) },
                     with: .color(Color(red: 0.04, green: 0.5, blue: 0.32)), lineWidth: 6)
      let bill = Path { path in
        path.move(to: CGPoint(x: 560, y: 312))
        path.addQuadCurve(to: CGPoint(x: 708, y: 334), control: CGPoint(x: 676, y: 296))
        path.addQuadCurve(to: CGPoint(x: 560, y: 340), control: CGPoint(x: 640, y: 352))
        path.closeSubpath()
      }
      context.fill(bill, with: .color(Color(red: 0.04, green: 0.5, blue: 0.32)))
      context.fill(Path(ellipseIn: CGRect(x: 498, y: 176, width: 28, height: 20)), with: .color(Color(red: 0.04, green: 0.5, blue: 0.32)))

    case .beret:
      // A writer's beret, tipped to one side, for the journal keeper.
      let beret = Path { path in
        path.move(to: CGPoint(x: 372, y: 318))
        path.addCurve(to: CGPoint(x: 540, y: 206), control1: CGPoint(x: 368, y: 246), control2: CGPoint(x: 446, y: 206))
        path.addCurve(to: CGPoint(x: 672, y: 300), control1: CGPoint(x: 624, y: 206), control2: CGPoint(x: 684, y: 250))
        path.addCurve(to: CGPoint(x: 372, y: 318), control1: CGPoint(x: 600, y: 336), control2: CGPoint(x: 440, y: 342))
        path.closeSubpath()
      }
      context.fill(beret, with: .color(Color(red: 0.58, green: 0.12, blue: 0.2)))
      context.fill(Path(roundedRect: CGRect(x: 528, y: 190, width: 18, height: 26), cornerRadius: 6), with: .color(Color(red: 0.45, green: 0.08, blue: 0.15)))

    case .bankerVisor:
      // The classic green eyeshade of the people who count the money: earned by collecting dividends.
      let visor = Path { path in
        path.move(to: CGPoint(x: 352, y: 340))
        path.addQuadCurve(to: CGPoint(x: 672, y: 340), control: CGPoint(x: 512, y: 296))
        path.addQuadCurve(to: CGPoint(x: 352, y: 340), control: CGPoint(x: 512, y: 430))
        path.closeSubpath()
      }
      context.fill(visor, with: .color(Color(red: 0.08, green: 0.62, blue: 0.4).opacity(0.88)))
      context.stroke(Path { path in
        path.move(to: CGPoint(x: 352, y: 340))
        path.addQuadCurve(to: CGPoint(x: 672, y: 340), control: CGPoint(x: 512, y: 296))
      }, with: .color(Color(red: 0.04, green: 0.4, blue: 0.26)), style: StrokeStyle(lineWidth: 12, lineCap: .round))

    case .topHat:
      context.fill(Path(ellipseIn: CGRect(x: 398, y: 302, width: 228, height: 54)), with: .color(ink))
      context.fill(Path(roundedRect: CGRect(x: 446, y: 140, width: 132, height: 190), cornerRadius: 10), with: .color(ink))
      context.fill(Path(CGRect(x: 446, y: 282, width: 132, height: 28)), with: .color(Brand.sell))
      context.stroke(Path { $0.move(to: CGPoint(x: 462, y: 160)); $0.addLine(to: CGPoint(x: 462, y: 270)) },
                     with: .color(.white.opacity(0.2)), style: StrokeStyle(lineWidth: 10, lineCap: .round))

    default:
      flag?.draw(in: &context)
    }
  }
}
