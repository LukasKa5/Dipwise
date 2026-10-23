import Charts
import SwiftUI
import WidgetKit

/// The portfolio at a glance: its value, today's move, and how it's been trending. The large size adds the
/// closest buy zone, spelled out, and today's biggest movers.
struct PortfolioWidget: Widget {
  let kind = "PortfolioWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PortfolioProvider()) { entry in
      PortfolioWidgetView(entry: entry)
    }
    .configurationDisplayName("Portfolio")
    .description("Your portfolio's value, today's move, and its last month. The large size adds your closest buy zone and today's movers.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline])
  }
}

struct PortfolioEntry: TimelineEntry {
  var date: Date
  var portfolio: WatchPortfolio?
  var closest: TargetStatus?
  var movers: [Quote]
}

struct PortfolioProvider: TimelineProvider {
  func placeholder(in context: Context) -> PortfolioEntry {
    Self.sample
  }

  func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
    let entry = Self.entry(quotes: TargetSnapshotStore.loadQuotes())
    completion(entry.portfolio == nil && context.isPreview ? Self.sample : entry)
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
    Task {
      let symbols = TargetSnapshotStore.loadStocks().map(\.symbol) + TargetSnapshotStore.loadTargets().map(\.symbol)
      let quotes = await WidgetData.quotes(for: symbols)
      completion(Timeline(entries: [Self.entry(quotes: quotes)], policy: .after(.now.addingTimeInterval(WidgetData.refresh))))
    }
  }

  static func entry(quotes: [String: Quote], date: Date = .now) -> PortfolioEntry {
    let stocks = TargetSnapshotStore.loadStocks()
    let portfolio = WatchPortfolio.make(stocks: stocks, quotes: quotes, currency: TargetSnapshotStore.loadBaseCurrency(), rates: TargetSnapshotStore.loadRates())
    let closest = TargetStatus.sorted(targets: TargetSnapshotStore.loadTargets(), quotes: quotes)
      .first { $0.target.rule.kind.isZone || $0.target.rule.kind == .priceBelow || $0.target.rule.kind == .priceAbove }
    let movers = stocks.compactMap { quotes[$0.symbol] }.sorted { abs($0.change) > abs($1.change) }
    return PortfolioEntry(date: date, portfolio: portfolio, closest: closest, movers: Array(movers.prefix(3)))
  }

  static let sample: PortfolioEntry = {
    let history: [Double] = [118_200, 117_600, 118_900, 119_400, 118_700, 119_900, 120_400, 119_800, 120_900, 121_300, 120_800, 121_600, 122_064]
    let nvda = Quote(symbol: "NVDA", name: "NVIDIA", currency: "USD", price: 228.52, previousClose: 226.27, closes: [], updatedAt: .now)
    return PortfolioEntry(
      date: .now,
      portfolio: WatchPortfolio(value: 122_064.60, dayChangeAmount: 554.13, currency: "USD", history: history),
      closest: TargetStatus(target: WatchedTarget(id: UUID(), symbol: "NVDA", name: "NVIDIA", rule: AlertRule(kind: .buyZone, lower: 206.35, upper: 217.80)), quote: nvda),
      movers: [
        Quote(symbol: "META", name: "Meta", currency: "USD", price: 762.50, previousClose: 743.17, closes: [], updatedAt: .now),
        nvda,
        Quote(symbol: "TSLA", name: "Tesla", currency: "USD", price: 375.23, previousClose: 378.03, closes: [], updatedAt: .now),
      ]
    )
  }()
}

struct PortfolioWidgetView: View {
  var entry: PortfolioEntry
  /// Lets the app preview a specific size.
  var previewFamily: WidgetFamily?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { previewFamily ?? environmentFamily }

  var body: some View {
    Group {
      if let portfolio = entry.portfolio {
        switch family {
        case .accessoryRectangular: rectangular(portfolio)
        case .accessoryInline: Text("\(portfolio.formatted(portfolio.value)) \(changeText(portfolio.dayChange))")
        case .systemMedium: medium(portfolio)
        case .systemLarge: large(portfolio)
        default: small(portfolio)
        }
      } else {
        empty
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(URL(string: "dipwise://portfolio"))
  }

  // MARK: Sizes

  private func small(_ portfolio: WatchPortfolio) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      header
      Spacer(minLength: 4)
      value(portfolio, size: 26)
      todayLine(portfolio)
      PortfolioChart(history: portfolio.history, isUp: portfolio.isUpOverHistory)
        .frame(height: 34)
        .padding(.top, 6)
    }
  }

  private func medium(_ portfolio: WatchPortfolio) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      HStack(spacing: 14) {
        VStack(alignment: .leading, spacing: 3) {
          Spacer(minLength: 4)
          value(portfolio, size: 28)
          todayLine(portfolio)
          if let month = portfolio.historyChange {
            Text("\(changeText(month)) this month")
              .font(.caption2.weight(.semibold).monospacedDigit())
              .foregroundStyle(.white.opacity(0.6))
              .lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        PortfolioChart(history: portfolio.history, isUp: portfolio.isUpOverHistory)
          .frame(maxWidth: .infinity)
          .padding(.top, 6)
      }
    }
  }

  private func large(_ portfolio: WatchPortfolio) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 3) {
        header
        value(portfolio, size: 32)
        todayLine(portfolio)
      }
      PortfolioChart(history: portfolio.history, isUp: portfolio.isUpOverHistory)
        .frame(height: 64)
      if let closest = entry.closest {
        WidgetTile(padding: 10) {
          ClosestZoneRow(status: closest)
        }
      }
      if !entry.movers.isEmpty {
        VStack(alignment: .leading, spacing: 6) {
          Text("Today's movers")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white.opacity(0.6))
          ForEach(entry.movers, id: \.symbol) { quote in
            HStack(spacing: 8) {
              WidgetBadge(symbol: quote.symbol, size: 22)
              Text(quote.symbol)
                .font(.caption.bold())
                .lineLimit(1)
              Spacer(minLength: 4)
              Text(compactPrice(quote.price, currency: quote.currency))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
              WidgetChangePill(change: quote.change)
            }
          }
        }
      }
      Spacer(minLength: 0)
    }
  }

  private func rectangular(_ portfolio: WatchPortfolio) -> some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Portfolio")
        .font(.caption2.weight(.semibold))
        .widgetAccentable()
      Text(portfolio.formatted(portfolio.value))
        .font(.headline.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text("\(changeText(portfolio.dayChange)) today")
        .font(.caption.monospacedDigit())
    }
  }

  private var empty: some View {
    VStack(spacing: 8) {
      WidgetOwl(size: 40)
      Text("Add what you own in Dipwise to see your portfolio here.")
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .foregroundStyle(.white.opacity(0.75))
    }
  }

  // MARK: Pieces

  private var header: some View {
    WidgetHeader("Portfolio", isPreview: previewFamily != nil)
  }

  private func value(_ portfolio: WatchPortfolio, size: CGFloat) -> some View {
    Text(portfolio.formatted(portfolio.value))
      .font(.system(size: size, weight: .bold, design: .rounded).monospacedDigit())
      .lineLimit(1)
      .minimumScaleFactor(0.5)
      .contentTransition(.numericText())
  }

  private func todayLine(_ portfolio: WatchPortfolio) -> some View {
    let isUp = portfolio.dayChangeAmount >= 0
    return HStack(spacing: 3) {
      Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
        .font(.system(size: 9, weight: .heavy))
      Text("\(changeText(portfolio.dayChange)) · \(isUp ? "+" : "")\(portfolio.formatted(portfolio.dayChangeAmount)) today")
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .font(.caption.weight(.semibold).monospacedDigit())
    .foregroundStyle(isUp ? Brand.buy : Brand.sell)
  }
}

/// The closest plan in full words: the stock, the zone, where the price is now, and how far it has to go.
struct ClosestZoneRow: View {
  var status: TargetStatus

  var body: some View {
    let color = status.target.rule.kind.side.brandColor
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        WidgetBadge(symbol: status.target.symbol, size: 24)
        VStack(alignment: .leading, spacing: 0) {
          Text("Closest plan · \(status.target.symbol)")
            .font(.caption.bold())
            .lineLimit(1)
          Text(compactSummary(status))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        Spacer(minLength: 4)
        DistanceLabel(status: status)
      }
      ZoneRuler(status: status)
    }
  }
}

/// How far a plan has to go, with the words that say what the number means.
struct DistanceLabel: View {
  var status: TargetStatus

  var body: some View {
    let color = status.target.rule.kind.side.brandColor
    let isIn = status.distance == 0
    VStack(alignment: .trailing, spacing: 0) {
      Text(isIn ? "In zone" : distanceText(status.distance))
        .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
        .foregroundStyle(isIn || (status.distance ?? 1) < 0.035 ? color : .white)
        .lineLimit(1)
      Text(isIn ? "Now" : "to go")
        .font(.caption2.weight(.medium))
        .foregroundStyle(.white.opacity(0.55))
    }
    .fixedSize()
  }
}

/// The portfolio's recent days as a soft area chart, like the app's Home card.
struct PortfolioChart: View {
  var history: [Double]
  var isUp: Bool

  var body: some View {
    let color = isUp ? Brand.buy : Brand.sell
    let low = history.min() ?? 0
    let high = history.max() ?? 1
    let pad = max((high - low) * 0.1, high * 0.001)
    Chart(Array(history.enumerated()), id: \.offset) { index, value in
      AreaMark(x: .value("Day", index), yStart: .value("Floor", low - pad), yEnd: .value("Value", value))
        .foregroundStyle(LinearGradient(colors: [color.opacity(0.3), color.opacity(0)], startPoint: .top, endPoint: .bottom))
        .interpolationMethod(.monotone)
      LineMark(x: .value("Day", index), y: .value("Value", value))
        .foregroundStyle(color)
        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .interpolationMethod(.monotone)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: (low - pad)...(high + pad))
    .accessibilityHidden(true)
  }
}

extension WatchPortfolio {
  /// How much the portfolio moved across its history.
  var historyChange: Double? {
    guard let first = history.first, first > 0, history.count > 1 else { return nil }
    return value / first - 1
  }

  var isUpOverHistory: Bool { (historyChange ?? dayChange) >= 0 }
}
