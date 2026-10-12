import Charts
import SwiftUI
import WidgetKit

extension View {
  /// Widgets use the same solid navy as the app's hero cards and icon.
  func dipwiseWidgetBackground() -> some View {
    containerBackground(for: .widget) { Brand.nightMiddle }
  }
}

/// The soft inset tile used on the app's navy cards.
struct WidgetTile<Content: View>: View {
  var padding: CGFloat = 8
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.white.opacity(0.08), in: .rect(cornerRadius: 12, style: .continuous))
  }
}

/// Dippy on a widget: his pose changes with every update, and tapping him gets a reaction.
struct LivingDippy: View {
  var size: CGFloat
  var date: Date
  /// Offsets the pose so several widgets don't all look the same way at once.
  var seed = 0
  var showsBubble = true
  /// Lets the app's previews skip the intent and its stored reaction.
  var isPreview = false

  var body: some View {
    let reaction = isPreview ? nil : WidgetState.recentReaction
    // In the app's previews Dippy is always awake, so new users meet him at his best.
    let owl = WidgetOwl(size: size, isAsleep: isPreview ? false : nil, pose: reaction == nil ? DippyPose.at(date, seed: seed) : .cheer)
    Group {
      if isPreview {
        owl
      } else {
        Button(intent: PetDippyIntent()) { owl }
          .buttonStyle(.plain)
          .accessibilityLabel("Say hi to Dippy")
      }
    }
    .overlay(alignment: .topTrailing) {
      if showsBubble, let reaction {
        Text(reaction)
          .font(.system(size: 9, weight: .heavy, design: .rounded))
          .foregroundStyle(Brand.owlInk)
          .padding(.horizontal, 6)
          .padding(.vertical, 3)
          .background(.white, in: .capsule)
          .fixedSize()
          .offset(x: -size * 0.5, y: -size * 0.45)
      }
    }
  }
}

/// Dippy with a short line, the way he talks on the app's Home card.
struct WidgetDippyLine: View {
  var text: String
  var owlSize: CGFloat = 22
  var date: Date = .now
  var isPreview = false

  var body: some View {
    HStack(spacing: 6) {
      LivingDippy(size: owlSize, date: date, showsBubble: false, isPreview: isPreview)
      Text(text)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.85))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
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

  /// Dates every few minutes for the next half hour, so Dippy changes pose between data refreshes.
  static func livingDates(count: Int = 6, from start: Date = .now) -> [Date] {
    (0..<count).map { start.addingTimeInterval(Double($0) * rotation) }
  }
  /// How often rotating widgets move on to the next stock.
  static let rotation: TimeInterval = 5 * 60
}
