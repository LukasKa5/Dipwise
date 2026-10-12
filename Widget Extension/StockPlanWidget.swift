import AppIntents
import SwiftUI
import WidgetKit

/// A followed stock, offered as a choice when configuring the widget.
struct StockEntity: AppEntity {
  static let typeDisplayRepresentation: TypeDisplayRepresentation = "Stock"
  static let defaultQuery = StockQuery()

  var id: String
  var name: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: "\(id)", subtitle: "\(name)")
  }
}

struct StockQuery: EntityQuery {
  func entities(for identifiers: [StockEntity.ID]) async throws -> [StockEntity] {
    let stocks = TargetSnapshotStore.loadStocks()
    return identifiers.map { id in StockEntity(id: id, name: stocks.first { $0.symbol == id }?.name ?? id) }
  }

  func suggestedEntities() async throws -> [StockEntity] {
    TargetSnapshotStore.loadStocks().map { StockEntity(id: $0.symbol, name: $0.name) }
  }

  func defaultResult() async -> StockEntity? {
    TargetSnapshotStore.loadStocks().first.map { StockEntity(id: $0.symbol, name: $0.name) }
  }
}

struct SelectStockIntent: WidgetConfigurationIntent {
  static let title: LocalizedStringResource = "Choose Stock"
  static let description = IntentDescription("Pick which stock's plan to show.")

  @Parameter(title: "Stock")
  var stock: StockEntity?
}

/// One stock's price, trend, and buy and sell zones.
struct StockPlanWidget: Widget {
  let kind = "StockPlanWidget"

  var body: some WidgetConfiguration {
    AppIntentConfiguration(kind: kind, intent: SelectStockIntent.self, provider: StockPlanProvider()) { entry in
      StockPlanWidgetView(entry: entry)
    }
    .configurationDisplayName("Stock Plan")
    .description("A stock's price with your green buy zones and red sell zones.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct StockPlanEntry: TimelineEntry {
  var date: Date
  var symbol: String?
  var quote: Quote?
  var targets: [WatchedTarget]
}

struct StockPlanProvider: AppIntentTimelineProvider {
  func placeholder(in context: Context) -> StockPlanEntry {
    StockPlanEntry(date: .now, symbol: "NVDA", quote: Quote(symbol: "NVDA", name: "NVIDIA", currency: "USD", price: 182.4, previousClose: 180,
                                                            closes: [176, 179, 175, 172, 174, 178, 181, 180, 182.4], updatedAt: .now),
                   targets: [WatchedTarget(id: UUID(), symbol: "NVDA", name: "NVIDIA", rule: AlertRule(kind: .buyZone, lower: 168, upper: 174)),
                             WatchedTarget(id: UUID(), symbol: "NVDA", name: "NVIDIA", rule: AlertRule(kind: .sellZone, lower: 200, upper: 210))])
  }

  func snapshot(for configuration: SelectStockIntent, in context: Context) async -> StockPlanEntry {
    let symbol = configuration.stock?.id ?? TargetSnapshotStore.loadStocks().first?.symbol
    guard let symbol else { return placeholder(in: context) }
    return StockPlanEntry(date: .now, symbol: symbol, quote: TargetSnapshotStore.loadQuotes()[symbol],
                          targets: TargetSnapshotStore.loadTargets().filter { $0.symbol == symbol })
  }

  func timeline(for configuration: SelectStockIntent, in context: Context) async -> Timeline<StockPlanEntry> {
    let symbol = configuration.stock?.id ?? TargetSnapshotStore.loadStocks().first?.symbol
    var entry = StockPlanEntry(date: .now, symbol: symbol, quote: nil, targets: [])
    if let symbol {
      entry.quote = await WidgetData.quotes(for: [symbol])[symbol]
      entry.targets = TargetSnapshotStore.loadTargets().filter { $0.symbol == symbol }
    }
    return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(WidgetData.refresh)))
  }
}

struct StockPlanWidgetView: View {
  var entry: StockPlanEntry
  /// Lets the app preview a specific size.
  var previewFamily: WidgetFamily?
  /// Lets the app preview the zones side without changing the real widget.
  var previewShowsZones: Bool?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { previewFamily ?? environmentFamily }
  private var showsZones: Bool { previewShowsZones ?? WidgetState.showsZones }

  private var zones: [AlertRule] { entry.targets.map(\.rule).filter { $0.kind.isZone || $0.kind == .priceBelow || $0.kind == .priceAbove } }

  var body: some View {
    Group {
      if let symbol = entry.symbol, let quote = entry.quote {
        VStack(alignment: .leading, spacing: 8) {
          if family == .systemMedium {
            HStack(spacing: 8) {
              WidgetBadge(symbol: symbol)
              VStack(alignment: .leading, spacing: 0) {
                Text(symbol)
                  .font(.headline)
                  .lineLimit(1)
                  .minimumScaleFactor(0.5)
                Text(quote.name).font(.caption2).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
              }
              Spacer(minLength: 0)
              VStack(alignment: .trailing, spacing: 0) {
                Text(compactPrice(quote.price, currency: quote.currency))
                  .font(.headline.monospacedDigit())
                  .lineLimit(1)
                  .minimumScaleFactor(0.6)
                Text(changeText(quote.change))
                  .font(.caption.weight(.semibold))
                  .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
              }
            }
          } else {
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 6) {
                WidgetBadge(symbol: symbol, size: 22)
                Text(symbol)
                  .font(.subheadline.bold())
                  .lineLimit(1)
                  .minimumScaleFactor(0.5)
                Spacer(minLength: 0)
                Text(changeText(quote.change))
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
              }
              Text(compactPrice(quote.price, currency: quote.currency))
                .font(.title3.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            }
          }
          if family == .systemMedium && showsZones {
            WidgetZoneScale(price: quote.price, zones: zones, format: quote.formatted)
            Spacer(minLength: 0)
          } else {
            WidgetSparkline(values: Array(quote.closes.suffix(30)), zones: zones)
          }
          HStack {
            if let nearest = entry.targets.min(by: { ($0.rule.distance(for: quote) ?? 9) < ($1.rule.distance(for: quote) ?? 9) }) {
              Text("\(distanceText(nearest.rule.distance(for: quote))) · \(nearest.rule.kind.title.lowercased())")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(nearest.rule.kind.side.brandColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            } else {
              Text("No plan yet").font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: 0)
            if family == .systemMedium {
              Button(intent: ToggleZonesIntent()) {
                Label(showsZones ? "Chart" : "Zones", systemImage: showsZones ? "chart.xyaxis.line" : "arrow.left.and.right")
                  .font(.caption2.weight(.bold))
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(.white.opacity(0.15), in: .capsule)
              }
              .buttonStyle(.plain)
            }
          }
        }
      } else {
        VStack(spacing: 8) {
          WidgetOwl(size: 44)
          Text("Choose a stock")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
        }
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(entry.symbol.flatMap { URL(string: "dipwise://stock/\($0)") })
  }
}

/// A compact price scale with green buy zones, red sell zones, and today's price.
private struct WidgetZoneScale: View {
  var price: Double
  var zones: [AlertRule]
  var format: (Double) -> String

  var body: some View {
    let values = zones.flatMap { [$0.lower, max($0.lower, $0.upper)] } + [price]
    let low = (values.min() ?? price) * 0.98
    let high = (values.max() ?? price) * 1.02
    VStack(spacing: 6) {
      GeometryReader { geometry in
        let x: (Double) -> CGFloat = { CGFloat(($0 - low) / max(high - low, 0.0001)) * geometry.size.width }
        ZStack(alignment: .leading) {
          Capsule().fill(.white.opacity(0.15)).frame(height: 10)
          ForEach(Array(zones.enumerated()), id: \.offset) { _, zone in
            Capsule()
              .fill(zone.kind.side.brandColor)
              .frame(width: max(8, x(max(zone.lower, zone.upper)) - x(zone.lower)), height: 10)
              .offset(x: x(zone.lower))
          }
          Capsule()
            .fill(.white)
            .frame(width: 3, height: 22)
            .offset(x: x(price) - 1.5)
        }
        .frame(maxHeight: .infinity)
      }
      .frame(height: 22)
      HStack {
        Text(format(low)).font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.6))
        Spacer()
        Text("Now \(format(price))").font(.caption2.weight(.semibold))
        Spacer()
        Text(format(high)).font(.caption2.monospacedDigit()).foregroundStyle(.white.opacity(0.6))
      }
    }
  }
}
