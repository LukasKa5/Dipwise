import SwiftUI

// Small pieces shared by the widgets, Apple Watch, and the app's previews of them, so they always look the same.

struct WidgetTrack: View {
  var progress: Double
  var color: Color

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.15))
        Capsule()
          .fill(color)
          .frame(width: max(6, geometry.size.width * progress))
      }
    }
    .frame(height: 6)
  }
}

struct WidgetBadge: View {
  var symbol: String
  var size: CGFloat = 26

  private var hue: Double {
    var hash: UInt64 = 5381
    for scalar in symbol.unicodeScalars { hash = (hash &* 33) &+ UInt64(scalar.value) }
    return Double(hash % 360) / 360
  }

  var body: some View {
    Text(symbol.prefix(symbol.count > 4 ? 1 : 2))
      .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
      .foregroundStyle(.white)
      .minimumScaleFactor(0.5)
      .frame(width: size, height: size)
      .background(Color(hue: hue, saturation: 0.62, brightness: 0.72), in: .rect(cornerRadius: size * 0.3))
  }
}

/// One of Dippy's poses. Widgets can't animate continuously, so each update shows a new pose,
/// which makes Dippy feel alive across the day: looking around, blinking, stretching, and cheering.
enum DippyPose: Int, CaseIterable {
  case idle
  case lookLeft
  case lookRight
  case lookUp
  case stretch
  case cheer
  case wink

  /// A pose that changes every few minutes on its own.
  static func at(_ date: Date, seed: Int = 0) -> DippyPose {
    let step = Int(date.timeIntervalSinceReferenceDate / 300) + seed
    // Cheering stays special, so it's left out of the idle rotation.
    let idle: [DippyPose] = [.idle, .lookLeft, .idle, .lookRight, .wink, .lookUp, .idle, .stretch]
    return idle[((step % idle.count) + idle.count) % idle.count]
  }

  var look: CGSize {
    switch self {
    case .lookLeft: CGSize(width: -1, height: 0)
    case .lookRight: CGSize(width: 1, height: 0)
    case .lookUp: CGSize(width: 0.2, height: -0.8)
    case .cheer: CGSize(width: 0, height: -0.5)
    default: .zero
    }
  }

  var wings: Double {
    switch self {
    case .stretch: 0.55
    case .cheer: 0.9
    default: 0
    }
  }
}

/// Dippy for widgets and the watch, asleep while the market is closed.
struct WidgetOwl: View {
  var size: CGFloat
  /// Nil follows the market clock.
  var isAsleep: Bool?
  var pose: DippyPose = .idle

  var body: some View {
    let asleep = isAsleep ?? !MarketClock.isOpen()
    let winks = !asleep && pose == .wink
    OwlMark(
      wingSpread: asleep ? 0 : pose.wings,
      blink: asleep || winks ? 1 : 0,
      lookOffset: asleep ? .zero : pose.look,
      // A wink closes the left eye and keeps the right one open.
      rightEyeOpen: winks ? 1 : 0
    )
    .frame(width: size)
    .overlay(alignment: .topTrailing) {
      if asleep {
        Text("z")
          .font(.system(size: size * 0.35, weight: .heavy, design: .rounded))
          .foregroundStyle(.white.opacity(0.7))
          .offset(x: size * 0.25, y: -size * 0.2)
      }
    }
    .accessibilityHidden(true)
  }
}

/// Prices without unneeded decimals, so big numbers like Bitcoin fit.
func compactPrice(_ value: Double, currency: String) -> String {
  value.formatted(.currency(code: currency).precision(.fractionLength(value >= 1000 ? 0 : 2)))
}

func distanceText(_ distance: Double?) -> String {
  guard let distance else { return "—" }
  return distance == 0 ? "Now" : distance.formatted(.percent.precision(.fractionLength(1)))
}

func changeText(_ change: Double) -> String {
  change.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
}

/// A short form of an alert for small spaces, like "Buy 58,000–61,000".
func compactSummary(_ status: TargetStatus) -> String {
  let rule = status.target.rule
  let currency = status.quote?.currency ?? "USD"
  let format: (Double) -> String = { compactPrice($0, currency: currency) }
  switch rule.kind {
  case .buyZone: return "Buy \(format(rule.lower))–\(format(rule.upper))"
  case .sellZone: return "Sell \(format(rule.lower))–\(format(rule.upper))"
  case .priceBelow: return "Buy below \(format(rule.lower))"
  case .priceAbove: return "Sell above \(format(rule.lower))"
  default: return rule.kind.title
  }
}
