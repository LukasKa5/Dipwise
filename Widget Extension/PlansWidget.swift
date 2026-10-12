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
      // Several entries even for one plan, so Dippy changes pose between refreshes.
      let steps = 6
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

  private var isPreview: Bool { previewFamily != nil }

  private var current: TargetStatus? {
    entry.statuses.isEmpty ? nil : entry.statuses[entry.index % entry.statuses.count]
  }

  var body: some View {
    Group {
      switch family {
      case .accessoryRectangular: rectangular
      case .accessoryCircular: circular
      case .accessoryInline: inline
      case .systemMedium: list(perPage: 4)
      case .systemLarge: list(perPage: 7)
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
            LivingDippy(size: 22, date: entry.date, isPreview: isPreview)
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
            LivingDippy(size: 18, date: entry.date, seed: 2, showsBubble: false, isPreview: isPreview)
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

  /// Pages through every plan, a few at a time; the timeline turns the page every few minutes.
  @ViewBuilder
  private func list(perPage: Int) -> some View {
    if entry.statuses.isEmpty {
      empty
    } else {
      let pages = max(1, (entry.statuses.count + perPage - 1) / perPage)
      let page = entry.index % pages
      let rows = Array(entry.statuses.dropFirst(page * perPage).prefix(perPage))
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 6) {
          WidgetDippyLine(text: dippSays(entry.statuses), date: entry.date, isPreview: isPreview)
          Spacer(minLength: 4)
          if pages > 1 {
            WidgetPageDots(count: pages, index: page)
          }
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
        .padding(.bottom, family == .systemLarge ? 10 : 6)
        VStack(spacing: family == .systemLarge ? 6 : 4) {
          ForEach(rows) { status in
            Link(destination: URL(string: "dipwise://stock/\(status.target.symbol)")!) {
              if family == .systemLarge { largeRow(status) } else { compactRow(status) }
            }
            .frame(maxHeight: .infinity)
          }
          // Empty slots keep rows the same height on the last page.
          ForEach(0..<(perPage - rows.count), id: \.self) { _ in
            Color.clear.frame(maxHeight: .infinity)
          }
        }
        .id(page)
        .transition(.push(from: .bottom))
      }
    }
  }

  /// One line per plan, for the medium widget.
  private func compactRow(_ status: TargetStatus) -> some View {
    let color = status.target.rule.kind.side.brandColor
    return HStack(spacing: 8) {
      WidgetBadge(symbol: status.target.symbol, size: 20)
      Text(status.target.symbol)
        .font(.caption.bold())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .frame(width: 46, alignment: .leading)
      Image(systemName: status.target.rule.kind.side == .sell ? "arrow.up.to.line.compact" : "arrow.down.to.line.compact")
        .font(.system(size: 9, weight: .bold))
        .foregroundStyle(color)
      WidgetTrack(progress: status.progress, color: color)
      Text(distanceText(status.distance))
        .font(.caption.weight(.bold).monospacedDigit())
        .foregroundStyle(status.distance == 0 || (status.distance ?? 1) < 0.035 ? color : .white)
        .lineLimit(1)
        .frame(width: 44, alignment: .trailing)
    }
    .padding(.horizontal, 8)
    .frame(maxHeight: .infinity)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 9, style: .continuous))
  }

  /// Two lines per plan, with the zone spelled out, for the large widget.
  private func largeRow(_ status: TargetStatus) -> some View {
    let color = status.target.rule.kind.side.brandColor
    return HStack(spacing: 10) {
      WidgetBadge(symbol: status.target.symbol, size: 30)
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(status.target.symbol)
            .font(.subheadline.bold())
            .lineLimit(1)
          if let quote = status.quote {
            Text(compactPrice(quote.price, currency: quote.currency))
              .font(.caption.monospacedDigit())
              .foregroundStyle(.white.opacity(0.65))
              .lineLimit(1)
          }
          Spacer(minLength: 2)
          Text(compactSummary(status))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        WidgetTrack(progress: status.progress, color: color)
      }
      Text(distanceText(status.distance))
        .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
        .foregroundStyle(status.distance == 0 || (status.distance ?? 1) < 0.035 ? color : .white)
        .lineLimit(1)
        .frame(width: 52, alignment: .trailing)
    }
    .padding(.horizontal, 10)
    .frame(maxHeight: .infinity)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 12, style: .continuous))
  }

  private var empty: some View {
    VStack(spacing: 8) {
      LivingDippy(size: 44, date: entry.date, isPreview: isPreview)
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
