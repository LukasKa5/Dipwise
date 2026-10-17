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

/// Where the price sits against a plan's zone: the zone as a band on a short ruler, with a dot for today's price.
/// It reads at a glance whether the price is above the zone, inside it, or below it.
struct ZoneRuler: View {
  var status: TargetStatus

  var body: some View {
    let rule = status.target.rule
    let color = rule.kind.side.brandColor
    let low = rule.lower
    let high = rule.kind.isZone ? max(rule.upper, rule.lower) : rule.lower
    let price = status.quote?.price ?? high
    let minimum = min(low, price)
    let maximum = max(high, price)
    let pad = max((maximum - minimum) * 0.18, maximum * 0.005)
    let start = minimum - pad
    let span = max(maximum + pad - start, 0.0001)
    GeometryReader { geometry in
      let width = geometry.size.width
      let x = { (value: Double) in CGFloat((value - start) / span) * width }
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.14)).frame(height: 4)
        Capsule()
          .fill(color.opacity(0.85))
          .frame(width: max(6, x(high) - x(low)), height: 8)
          .offset(x: x(low))
        Circle()
          .fill(.white)
          .overlay { Circle().strokeBorder(color, lineWidth: 2) }
          .frame(width: 11, height: 11)
          .offset(x: min(max(0, x(price) - 5.5), width - 11))
      }
      .frame(height: 11)
    }
    .frame(height: 11)
    .accessibilityHidden(true)
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

/// Dippy's poses on widgets and Apple Watch. He stays still and calm there; only his eyes change for a wink or a reaction.
enum DippyPose: Int, CaseIterable {
  case idle
  case lookLeft
  case lookRight
  case lookUp
  case stretch
  case cheer
  case wink

  /// Dippy sits still on widgets: always the same calm pose, whatever the time.
  static func at(_ date: Date, seed: Int = 0) -> DippyPose {
    .idle
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

  /// Dippy's wings stay folded on widgets and the watch.
  var wings: Double { 0 }
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
  return distance == 0 ? String(localized: "Now") : distance.formatted(.percent.precision(.fractionLength(1)))
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
  case .buyZone: return String(localized: "Buy \(format(rule.lower))–\(format(rule.upper))")
  case .sellZone: return String(localized: "Sell \(format(rule.lower))–\(format(rule.upper))")
  case .priceBelow: return String(localized: "Buy below \(format(rule.lower))")
  case .priceAbove: return String(localized: "Sell above \(format(rule.lower))")
  default: return rule.kind.title
  }
}
