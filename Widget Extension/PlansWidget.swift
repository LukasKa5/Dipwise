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
    .description("Every buy and sell zone, closest first, with the zone and today's price spelled out.")
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
      case .systemMedium: list(perPage: 3)
      case .systemLarge: list(perPage: 4)
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
        WidgetHeader(isPreview: isPreview) {
          HStack(spacing: 6) {
            WidgetBadge(symbol: status.target.symbol, size: 22)
            VStack(alignment: .leading, spacing: -1) {
              Text(status.target.symbol)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
              if let quote = status.quote {
                Text(changeText(quote.change))
                  .font(.caption2.weight(.bold).monospacedDigit())
                  .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
                  .lineLimit(1)
              }
            }
          }
        } accessory: {
          if entry.statuses.count > 1 {
            WidgetHeaderButton(title: "Next plan", systemImage: "chevron.forward", intent: NextPlanIntent())
          }
        }
        Spacer(minLength: 2)
        Text(distanceText(status.distance))
          .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
          .foregroundStyle(status.distance == 0 ? color : .white)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .contentTransition(.numericText())
        Text(zoneLabel(status))
          .font(.caption.weight(.semibold))
          .foregroundStyle(color)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
        Text(compactSummary(status))
          .font(.caption2.weight(.medium))
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
        Spacer(minLength: 4)
        ZoneRuler(status: status)
        HStack(spacing: 4) {
          if let quote = status.quote {
            Text(compactPrice(quote.price, currency: quote.currency))
              .font(.caption2.weight(.semibold).monospacedDigit())
              .foregroundStyle(.white.opacity(0.7))
              .lineLimit(1)
              .minimumScaleFactor(0.5)
          }
          Spacer(minLength: 2)
          if entry.statuses.count > 1 {
            WidgetPageDots(count: entry.statuses.count, index: entry.index)
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

  /// Whole phrases per side, so each language can word them naturally.
  private func zoneLabel(_ status: TargetStatus) -> LocalizedStringKey {
    let isSell = status.target.rule.kind.side == .sell
    if status.distance == 0 { return isSell ? "In your sell zone" : "In your buy zone" }
    return isSell ? "to your sell zone" : "to your buy zone"
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
        WidgetHeader("Closest to your zones", isPreview: isPreview) {
          if pages > 1 {
            WidgetPageDots(count: pages, index: page)
          }
          WidgetHeaderButton(title: "Refresh prices", systemImage: "arrow.clockwise", intent: RefreshWidgetsIntent())
        }
        .padding(.bottom, family == .systemLarge ? 10 : 6)
        VStack(spacing: family == .systemLarge ? 6 : 4) {
          ForEach(rows) { status in
            Link(destination: URL(string: "dipwise://stock/\(status.target.symbol)")!) {
              if family == .systemLarge { largeRow(status) } else { compactRow(status) }
            }
            .frame(maxHeight: family == .systemLarge ? 82 : .infinity)
          }
          // With several pages, empty slots keep rows the same height on the last one.
          ForEach(0..<(pages > 1 ? perPage - rows.count : 0), id: \.self) { _ in
            Color.clear.frame(maxHeight: .infinity)
          }
        }
        .frame(maxHeight: .infinity)
        .id(page)
        .transition(.push(from: .bottom))
      }
      .frame(maxHeight: .infinity, alignment: .top)
    }
  }

  /// One plan in words, for the medium widget: the stock, its zone, and how far the price has to go.
  private func compactRow(_ status: TargetStatus) -> some View {
    HStack(spacing: 8) {
      WidgetBadge(symbol: status.target.symbol, size: 24)
      VStack(alignment: .leading, spacing: 1) {
        Text(status.target.symbol)
          .font(.caption.bold())
          .lineLimit(1)
        Text(compactSummary(status))
          .font(.caption2.weight(.semibold))
          .foregroundStyle(status.target.rule.kind.side.brandColor)
          .lineLimit(1)
          .minimumScaleFactor(0.5)
      }
      Spacer(minLength: 4)
      DistanceLabel(status: status)
    }
    .padding(.horizontal, 10)
    .frame(maxHeight: .infinity)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 11, style: .continuous))
  }

  /// One plan in full, for the large widget: also today's price and where it sits against the zone.
  private func largeRow(_ status: TargetStatus) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 9) {
        WidgetBadge(symbol: status.target.symbol, size: 28)
        VStack(alignment: .leading, spacing: 1) {
          HStack(spacing: 6) {
            Text(status.target.symbol)
              .font(.subheadline.bold())
              .lineLimit(1)
            if let quote = status.quote {
              Text("Now \(compactPrice(quote.price, currency: quote.currency))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
          }
          Text(compactSummary(status))
            .font(.caption.weight(.semibold))
            .foregroundStyle(status.target.rule.kind.side.brandColor)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        Spacer(minLength: 4)
        DistanceLabel(status: status)
      }
      ZoneRuler(status: status)
    }
    .padding(.horizontal, 12)
    .frame(maxHeight: 82)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 13, style: .continuous))
  }

  private var empty: some View {
    VStack(spacing: 8) {
      WidgetOwl(size: 44, isAsleep: isPreview ? false : nil)
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
