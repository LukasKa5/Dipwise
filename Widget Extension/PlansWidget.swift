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
    .description("Your plans, closest first. It flips through them on its own, or tap the arrow.")
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
      let statuses = TargetStatus.sorted(targets: targets, quotes: quotes)
      // The small widget flips to the next plan every few minutes by itself.
      let steps = statuses.count > 1 ? 10 : 1
      let start = WidgetState.planIndex
      let entries = (0..<steps).map { step in
        PlansEntry(date: .now.addingTimeInterval(Double(step) * WidgetData.rotation), statuses: statuses, index: start + step)
      }
      completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(WidgetData.refresh))))
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

  // MARK: Small

  @ViewBuilder
  private var small: some View {
    if let status = current {
      let color = status.target.rule.kind.side.brandColor
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 6) {
          WidgetBadge(symbol: status.target.symbol, size: 26)
          VStack(alignment: .leading, spacing: 0) {
            Text(status.target.symbol)
              .font(.subheadline.bold())
              .lineLimit(1)
              .minimumScaleFactor(0.6)
            if let quote = status.quote {
              Text(changeText(quote.change))
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
                .lineLimit(1)
            }
          }
          .layoutPriority(1)
          Spacer(minLength: 0)
          if entry.statuses.count > 1 {
            Button(intent: NextPlanIntent()) {
              Image(systemName: "chevron.forward")
                .font(.caption.weight(.heavy))
                .frame(width: 24, height: 24)
                .background(.white.opacity(0.12), in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next plan")
          } else {
            WidgetOwl(size: 22)
          }
        }
        Spacer(minLength: 2)
        Text(distanceText(status.distance))
          .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(status.distance == 0 ? color : .white)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
          .contentTransition(.numericText())
        Text(status.distance == 0 ? "In your \(sideWord(status)) zone" : "to your \(sideWord(status)) zone")
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Spacer(minLength: 4)
        WidgetTrack(progress: status.progress, color: color)
        HStack(spacing: 4) {
          if let quote = status.quote {
            Text(compactPrice(quote.price, currency: quote.currency))
              .font(.caption2.weight(.semibold).monospacedDigit())
              .foregroundStyle(.white.opacity(0.7))
              .lineLimit(1)
              .minimumScaleFactor(0.6)
          }
          Spacer(minLength: 2)
          if entry.statuses.count > 1 {
            WidgetPageDots(count: entry.statuses.count, index: entry.index)
            WidgetOwl(size: 16)
          }
        }
        .padding(.top, 6)
      }
      .id(status.id)
      .transition(.opacity.combined(with: .scale(scale: 0.96)))
    } else {
      empty
    }
  }

  private func sideWord(_ status: TargetStatus) -> String {
    status.target.rule.kind.side == .sell ? "sell" : "buy"
  }

  // MARK: Medium and large

  @ViewBuilder
  private func list(count: Int) -> some View {
    if entry.statuses.isEmpty {
      empty
    } else {
      VStack(alignment: .leading, spacing: family == .systemLarge ? 8 : 6) {
        HStack(spacing: 6) {
          WidgetDippyLine(text: dippSays(entry.statuses))
          Spacer(minLength: 0)
          Button(intent: RefreshWidgetsIntent()) {
            Image(systemName: "arrow.clockwise")
              .font(.caption2.weight(.bold))
              .foregroundStyle(.white.opacity(0.75))
              .frame(width: 22, height: 22)
              .background(.white.opacity(0.12), in: .circle)
          }
          .buttonStyle(.plain)
          .accessibilityLabel("Refresh prices")
        }
        ForEach(entry.statuses.prefix(count)) { status in
          let color = status.target.rule.kind.side.brandColor
          Link(destination: URL(string: "dipwise://stock/\(status.target.symbol)")!) {
            WidgetTile(padding: 7) {
              HStack(spacing: 8) {
                WidgetBadge(symbol: status.target.symbol, size: 24)
                VStack(alignment: .leading, spacing: 3) {
                  HStack(spacing: 5) {
                    Text(status.target.symbol)
                      .font(.caption.bold())
                      .lineLimit(1)
                      .fixedSize()
                    Text(compactSummary(status))
                      .font(.caption2.weight(.medium))
                      .foregroundStyle(color)
                      .lineLimit(1)
                      .minimumScaleFactor(0.7)
                  }
                  WidgetTrack(progress: status.progress, color: color)
                }
                Text(distanceText(status.distance))
                  .font(.caption.weight(.bold).monospacedDigit())
                  .foregroundStyle((status.distance ?? 1) < 0.035 ? color : .white)
                  .lineLimit(1)
                  .frame(width: 46, alignment: .trailing)
              }
            }
          }
        }
        Spacer(minLength: 0)
      }
    }
  }

  private var empty: some View {
    VStack(spacing: 8) {
      WidgetOwl(size: 44)
      Text("Set a buy zone in Dipwise and Dippy will watch it.")
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .foregroundStyle(.white.opacity(0.75))
    }
  }

  // MARK: Accessories

  @ViewBuilder
  private var rectangular: some View {
    if let status = entry.statuses.first {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          OwlMark().frame(width: 12)
          Text("\(status.target.symbol) · \(distanceText(status.distance))")
            .font(.headline)
        }
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
