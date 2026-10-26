import AppIntents
import Charts
import SwiftUI
import WidgetKit

extension View {
  /// Widgets use the same solid navy as the app's hero cards and icon.
  func dipwiseWidgetBackground() -> some View {
    containerBackground(for: .widget) { Brand.nightMiddle }
  }
}

/// The top row every Dipwise widget shares: what the widget shows on the leading side, and Dippy in the top
/// trailing corner, always the same size and in the same place, so every widget reads as Dipwise at a glance.
struct WidgetHeader<Leading: View, Accessory: View>: View {
  /// In the app's previews Dippy is always awake.
  var isPreview = false
  @ViewBuilder var leading: Leading
  @ViewBuilder var accessory: Accessory

  var body: some View {
    HStack(spacing: 6) {
      leading
        .layoutPriority(1)
      Spacer(minLength: 4)
      accessory
      WidgetOwl(size: 20, isAsleep: isPreview ? false : nil)
    }
    .frame(height: 24)
  }
}

extension WidgetHeader where Leading == WidgetTitle, Accessory == EmptyView {
  init(_ title: LocalizedStringKey, isPreview: Bool = false) {
    self.init(isPreview: isPreview) { WidgetTitle(text: title) } accessory: { EmptyView() }
  }
}

extension WidgetHeader where Leading == WidgetTitle {
  init(_ title: LocalizedStringKey, isPreview: Bool = false, @ViewBuilder accessory: () -> Accessory) {
    self.init(isPreview: isPreview, leading: { WidgetTitle(text: title) }, accessory: accessory)
  }
}

/// A widget's name, small and quiet, the same on every widget.
struct WidgetTitle: View {
  var text: LocalizedStringKey

  var body: some View {
    Text(text)
      .font(.caption.weight(.bold))
      .foregroundStyle(.white.opacity(0.65))
      .lineLimit(1)
      .minimumScaleFactor(0.5)
  }
}

/// A small round button in a widget's header, like Refresh or Next.
struct WidgetHeaderButton<Intent: AppIntent>: View {
  var title: LocalizedStringKey
  var systemImage: String
  var intent: Intent

  var body: some View {
    Button(intent: intent) {
      Label(title, systemImage: systemImage)
        .labelStyle(.iconOnly)
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.white.opacity(0.8))
        .frame(width: 22, height: 22)
        .background(.white.opacity(0.12), in: .circle)
    }
    .buttonStyle(.plain)
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
