import Charts
import SwiftUI
import WidgetKit

extension View {
  /// Widgets use the same navy as the app's main cards and icon, with a soft glow in the color of what matters now.
  func dipwiseWidgetBackground(glow: Color? = nil) -> some View {
    containerBackground(for: .widget) { WidgetBackdrop(glow: glow) }
  }
}

/// Deep navy with a gentle top light, and an optional green or red glow.
struct WidgetBackdrop: View {
  var glow: Color?

  var body: some View {
    ZStack {
      LinearGradient(colors: [Brand.nightTop, Brand.nightMiddle, Brand.nightBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
      if let glow {
        RadialGradient(colors: [glow.opacity(0.32), glow.opacity(0)], center: .topTrailing, startRadius: 4, endRadius: 170)
      }
    }
  }
}

/// Small dots showing which of several plans is on screen.
struct WidgetPageDots: View {
  var count: Int
  var index: Int

  var body: some View {
    HStack(spacing: 4) {
      ForEach(0..<min(count, 6), id: \.self) { dot in
        Capsule()
          .fill(.white.opacity(dot == index % min(count, 6) ? 0.95 : 0.3))
          .frame(width: dot == index % min(count, 6) ? 10 : 4, height: 4)
      }
    }
    .accessibilityHidden(true)
  }
}

/// A day change as a small green or red pill.
struct WidgetChangePill: View {
  var change: Double

  var body: some View {
    Text(changeText(change))
      .font(.caption2.weight(.bold).monospacedDigit())
      .foregroundStyle(change >= 0 ? Brand.buy : Brand.sell)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background((change >= 0 ? Brand.buy : Brand.sell).opacity(0.18), in: .capsule)
      .lineLimit(1)
      .fixedSize()
  }
}

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

/// Dippy, asleep while the market is closed.
struct WidgetOwl: View {
  var size: CGFloat

  var body: some View {
    let asleep = !MarketClock.isOpen()
    OwlMark(blink: asleep ? 1 : 0)
      .frame(width: size)
      .overlay(alignment: .topTrailing) {
        if asleep {
          Text("z")
            .font(.system(size: size * 0.35, weight: .heavy, design: .rounded))
            .foregroundStyle(.white.opacity(0.7))
            .offset(x: size * 0.25, y: -size * 0.2)
        }
      }
  }
}

struct WidgetSparkline: View {
  var values: [Double]
  var zones: [AlertRule] = []

  var body: some View {
    let isUp = (values.last ?? 0) >= (values.first ?? 0)
    let bounds = values + zones.flatMap { [$0.lower, max($0.lower, $0.upper)] }
    Chart {
      ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
        RectangleMark(yStart: .value("Low", zone.lower), yEnd: .value("High", max(zone.lower * 1.003, zone.upper)))
          .foregroundStyle(zone.kind.side.brandColor.opacity(0.3))
      }
      ForEach(Array(values.enumerated()), id: \.offset) { index, value in
        LineMark(x: .value("Day", index), y: .value("Price", value))
          .foregroundStyle(isUp ? Brand.buy : Brand.sell)
          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
          .interpolationMethod(.monotone)
      }
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: (bounds.min() ?? 0) * 0.995...max((bounds.max() ?? 1) * 1.005, (bounds.min() ?? 0) + 0.0001))
  }
}

/// Prices without unneeded decimals, so big numbers like Bitcoin fit.
func compactPrice(_ value: Double, currency: String) -> String {
  value.formatted(.currency(code: currency).precision(.fractionLength(value >= 1000 ? 0 : 2)))
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

func distanceText(_ distance: Double?) -> String {
  guard let distance else { return "—" }
  return distance == 0 ? "Now" : distance.formatted(.percent.precision(.fractionLength(1)))
}

func changeText(_ change: Double) -> String {
  change.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
}

/// A one-line, Dippy-voiced summary of what matters most right now.
func dippSays(_ statuses: [TargetStatus]) -> String {
  guard let first = statuses.first else { return "Set a buy zone and I'll watch it." }
  if first.distance == 0 { return "\(first.target.symbol) is in your plan right now!" }
  if !MarketClock.isOpen() { return "Markets closed. \(statuses.count) plans on watch." }
  return "\(first.target.symbol) is \(distanceText(first.distance)) away."
}

/// Loads cached quotes, refreshes them from the network, and saves them back for the app.
enum WidgetData {
  static func quotes(for symbols: [String]) async -> [String: Quote] {
    var quotes = TargetSnapshotStore.loadQuotes()
    let fresh = await QuoteService().quotes(for: symbols + [Benchmark.symbol])
    if let market = fresh[Benchmark.symbol] { Benchmark.quote = market }
    if !fresh.isEmpty {
      quotes.merge(fresh) { _, new in new }
      TargetSnapshotStore.save(quotes: quotes)
    }
    return quotes
  }

  static let refresh: TimeInterval = 30 * 60
  /// How often rotating widgets move on to the next stock.
  static let rotation: TimeInterval = 5 * 60
}
