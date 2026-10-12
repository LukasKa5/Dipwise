import AppIntents
import SwiftUI
import WidgetKit

/// The alerts closest to triggering, across all stocks.
struct PlansWidget: Widget {
  let kind = "NearTargetsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PlansProvider()) { entry in
      PlansWidgetView(entry: entry)
    }
    .configurationDisplayName("Your Plans")
    .description("Dippy shows which stocks are closest to your plans. Tap to flip through them.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}

struct PlansEntry: TimelineEntry {
  var date: Date
  var statuses: [TargetStatus]
  var index: Int = 0
}

struct PlansProvider: TimelineProvider {
  func placeholder(in context: Context) -> PlansEntry {
    PlansEntry(date: .now, statuses: Self.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (PlansEntry) -> Void) {
    let statuses = TargetStatus.sorted(targets: TargetSnapshotStore.loadTargets(), quotes: TargetSnapshotStore.loadQuotes())
    completion(PlansEntry(date: .now, statuses: statuses.isEmpty && context.isPreview ? Self.sample : statuses, index: WidgetState.planIndex))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PlansEntry>) -> Void) {
    Task {
      let targets = TargetSnapshotStore.loadTargets()
      let quotes = await WidgetData.quotes(for: targets.map(\.symbol))
      let entry = PlansEntry(date: .now, statuses: TargetStatus.sorted(targets: targets, quotes: quotes), index: WidgetState.planIndex)
      completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(WidgetData.refresh))))
    }
  }

  static let sample: [TargetStatus] = [
    TargetStatus(
      target: WatchedTarget(id: UUID(), symbol: "NVDA", name: "NVIDIA", rule: AlertRule(kind: .buyZone, lower: 170, upper: 178)),
      quote: Quote(symbol: "NVDA", name: "NVIDIA", currency: "USD", price: 182.4, previousClose: 185.2, closes: [], updatedAt: .now)
    ),
    TargetStatus(
      target: WatchedTarget(id: UUID(), symbol: "AAPL", name: "Apple", rule: AlertRule(kind: .sellZone, lower: 255, upper: 265)),
      quote: Quote(symbol: "AAPL", name: "Apple", currency: "USD", price: 247.3, previousClose: 243, closes: [], updatedAt: .now)
    ),
    TargetStatus(
      target: WatchedTarget(id: UUID(), symbol: "MSFT", name: "Microsoft", rule: AlertRule(kind: .rsiOversold, level: 30)),
      quote: Quote(symbol: "MSFT", name: "Microsoft", currency: "USD", price: 512.3, previousClose: 508, closes: [], updatedAt: .now)
    ),
  ]
}

struct PlansWidgetView: View {
  var entry: PlansEntry
  /// Lets the app preview a specific size.
  var previewFamily: WidgetFamily?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { previewFamily ?? environmentFamily }

  private var current: TargetStatus? {
    entry.statuses.isEmpty ? nil : entry.statuses[entry.index % entry.statuses.count]
  }

  var body: some View {
    Group {
      switch family {
      case .accessoryRectangular: rectangular
      case .accessoryCircular: circular
      case .accessoryInline: inline
      case .systemMedium: list(count: 3)
      case .systemLarge: list(count: 6)
      default: small
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(current.map { URL(string: "dipwise://stock/\($0.target.symbol)")! } ?? URL(string: "dipwise://alerts"))
  }

  @ViewBuilder
  private var small: some View {
    if let status = current {
      let color = status.target.rule.kind.side.brandColor
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          WidgetBadge(symbol: status.target.symbol, size: 24)
          Text(status.target.symbol)
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .layoutPriority(1)
          Spacer(minLength: 0)
          if entry.statuses.count > 1 {
            Button(intent: NextPlanIntent()) {
              Image(systemName: "chevron.forward.circle.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
          }
        }
        Spacer(minLength: 0)
        Text(distanceText(status.distance))
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .foregroundStyle(status.distance == 0 ? color : .white)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
          .contentTransition(.numericText())
        Text(compactSummary(status))
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        WidgetTrack(progress: status.progress, color: color)
          .padding(.vertical, 2)
        HStack(alignment: .bottom) {
          if let quote = status.quote {
            Text(compactPrice(quote.price, currency: quote.currency))
              .font(.caption2.weight(.semibold).monospacedDigit())
              .foregroundStyle(.white.opacity(0.7))
              .lineLimit(1)
              .minimumScaleFactor(0.6)
          }
          Spacer(minLength: 0)
          WidgetOwl(size: 20)
        }
      }
    } else {
      empty
    }
  }

  @ViewBuilder
  private func list(count: Int) -> some View {
    if entry.statuses.isEmpty {
      empty
    } else {
      VStack(alignment: .leading, spacing: family == .systemLarge ? 12 : 8) {
        HStack(spacing: 8) {
          WidgetOwl(size: 24)
          Text(dippSays(entry.statuses))
            .font(.subheadline.weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
          Spacer(minLength: 0)
          Button(intent: RefreshWidgetsIntent()) {
            Image(systemName: "arrow.clockwise")
              .font(.caption.weight(.bold))
              .foregroundStyle(.white.opacity(0.7))
          }
          .buttonStyle(.plain)
        }
        ForEach(entry.statuses.prefix(count)) { status in
          let color = status.target.rule.kind.side.brandColor
          Link(destination: URL(string: "dipwise://stock/\(status.target.symbol)")!) {
            HStack(spacing: 10) {
              WidgetBadge(symbol: status.target.symbol, size: 26)
              VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                  Text(status.target.symbol)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .fixedSize()
                  Text(compactSummary(status))
                    .font(.caption)
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                WidgetTrack(progress: status.progress, color: color)
              }
              Text(distanceText(status.distance))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle((status.distance ?? 1) < 0.035 ? color : .white)
                .frame(width: 54, alignment: .trailing)
            }
          }
        }
        Spacer(minLength: 0)
      }
    }
  }

  private var empty: some View {
    VStack(spacing: 8) {
      WidgetOwl(size: 46)
      Text("Set a buy zone in Dipwise")
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .foregroundStyle(.white.opacity(0.7))
    }
  }

  @ViewBuilder
  private var rectangular: some View {
    if let status = entry.statuses.first {
      VStack(alignment: .leading, spacing: 2) {
        Text("\(status.target.symbol) · \(distanceText(status.distance))")
          .font(.headline)
          .widgetAccentable()
        Text(status.summary)
          .font(.caption)
          .lineLimit(1)
        Gauge(value: status.progress) { EmptyView() }
          .gaugeStyle(.accessoryLinearCapacity)
      }
    } else {
      Text("No plans yet")
    }
  }

  @ViewBuilder
  private var circular: some View {
    if let status = entry.statuses.first {
      Gauge(value: status.progress) {
        Text(status.target.symbol)
      } currentValueLabel: {
        Text(status.target.symbol.prefix(4))
          .minimumScaleFactor(0.5)
      }
      .gaugeStyle(.accessoryCircularCapacity)
    } else {
      Image(systemName: "scope")
    }
  }

  private var inline: some View {
    if let status = entry.statuses.first {
      Text("\(status.target.symbol) \(distanceText(status.distance)) · \(status.target.rule.kind.title.lowercased())")
    } else {
      Text("Dipwise: no plans")
    }
  }
}
