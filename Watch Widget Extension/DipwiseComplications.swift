import Charts
import SwiftUI
import WidgetKit

@main
struct DipwiseComplications: WidgetBundle {
  var body: some Widget {
    NearestPlanComplication()
    PortfolioComplication()
    MarketComplication()
    StreakComplication()
  }
}

struct PlanEntry: TimelineEntry {
  var date: Date
  var status: TargetStatus?
}

struct PlanProvider: TimelineProvider {
  func placeholder(in context: Context) -> PlanEntry {
    PlanEntry(date: .now, status: TargetStatus(
      target: WatchedTarget(id: UUID(), symbol: "NVDA", name: "NVIDIA", rule: AlertRule(kind: .buyZone, lower: 170, upper: 178)),
      quote: Quote(symbol: "NVDA", name: "NVIDIA", currency: "USD", price: 182.4, previousClose: 180, closes: [], updatedAt: .now)
    ))
  }

  func getSnapshot(in context: Context, completion: @escaping (PlanEntry) -> Void) {
    let status = TargetStatus.sorted(targets: TargetSnapshotStore.loadTargets(), quotes: TargetSnapshotStore.loadQuotes()).first
    completion(status == nil && context.isPreview ? placeholder(in: context) : PlanEntry(date: .now, status: status))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PlanEntry>) -> Void) {
    Task {
      let targets = TargetSnapshotStore.loadTargets()
      var quotes = TargetSnapshotStore.loadQuotes()
      let fresh = await QuoteService().quotes(for: targets.map(\.symbol))
      if !fresh.isEmpty {
        quotes.merge(fresh) { _, new in new }
        TargetSnapshotStore.save(quotes: quotes)
      }
      let entry = PlanEntry(date: .now, status: TargetStatus.sorted(targets: targets, quotes: quotes).first)
      completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
  }
}

/// The alert closest to triggering, on the watch face.
struct NearestPlanComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NearestPlanComplication", provider: PlanProvider()) { entry in
      NearestPlanView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Nearest Plan")
    .description("The stock closest to your buy or sell zone.")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
  }
}

private struct NearestPlanView: View {
  var entry: PlanEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    if let status = entry.status {
      let color = status.target.rule.kind.side.brandColor
      let distance = status.distance.map { $0 == 0 ? "Now" : $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—"
      switch family {
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 2) {
          Text("\(status.target.symbol) · \(distance)")
            .font(.headline)
            .widgetAccentable()
          Text(status.summary)
            .font(.caption2)
            .lineLimit(1)
          Gauge(value: status.progress) { EmptyView() }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(color)
        }
      case .accessoryInline:
        Text("\(status.target.symbol) \(distance) to \(status.target.rule.kind.title.lowercased())")
      case .accessoryCorner:
        Text(status.target.symbol)
          .widgetCurvesContent()
          .widgetLabel {
            Gauge(value: status.progress) { Text(status.target.symbol) }
              .tint(color)
          }
      default:
        Gauge(value: status.progress) {
          Text(status.target.symbol)
        } currentValueLabel: {
          Text(status.target.symbol.prefix(4)).minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(color)
      }
    } else {
      Image(systemName: "scope")
    }
  }
}

struct StreakEntry: TimelineEntry {
  var date: Date
  var progress: ProgressSnapshot
}

struct StreakProvider: TimelineProvider {
  func placeholder(in context: Context) -> StreakEntry {
    StreakEntry(date: .now, progress: ProgressSnapshot(streak: 12, lastBrief: .now, level: 3, levelTitle: "Night Watcher"))
  }

  func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
    completion(StreakEntry(date: .now, progress: ProgressSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
    let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400)).addingTimeInterval(60)
    completion(Timeline(entries: [StreakEntry(date: .now, progress: ProgressSnapshot.load())], policy: .after(tomorrow)))
  }
}

/// Your daily brief streak on the watch face.
struct StreakComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "StreakComplication", provider: StreakProvider()) { entry in
      VStack(spacing: 0) {
        Image(systemName: "flame.fill")
          .foregroundStyle(entry.progress.briefDoneToday ? Brand.amber : .secondary)
        Text("\(entry.progress.streak)")
          .font(.headline)
      }
      .widgetAccentable()
      .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Streak")
    .description("Your Dipwise daily brief streak.")
    .supportedFamilies([.accessoryCircular])
  }
}

// MARK: - Portfolio

struct PortfolioEntry: TimelineEntry {
  var date: Date
  var portfolio: WatchPortfolio?
}

struct PortfolioProvider: TimelineProvider {
  func placeholder(in context: Context) -> PortfolioEntry {
    PortfolioEntry(date: .now, portfolio: WatchPortfolio(value: 24_318, dayChangeAmount: 286, currency: "USD", history: [23_400, 23_800, 23_650, 24_100, 24_032, 24_318]))
  }

  func getSnapshot(in context: Context, completion: @escaping (PortfolioEntry) -> Void) {
    let portfolio = WatchPortfolio.load()
    completion(portfolio == nil && context.isPreview ? placeholder(in: context) : PortfolioEntry(date: .now, portfolio: portfolio))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PortfolioEntry>) -> Void) {
    Task {
      let stocks = TargetSnapshotStore.loadStocks().filter(\.isOwned)
      var quotes = TargetSnapshotStore.loadQuotes()
      let fresh = await QuoteService().quotes(for: stocks.map(\.symbol))
      if !fresh.isEmpty {
        quotes.merge(fresh) { _, new in new }
        TargetSnapshotStore.save(quotes: quotes)
      }
      let portfolio = WatchPortfolio.make(stocks: stocks, quotes: quotes, currency: TargetSnapshotStore.loadBaseCurrency(), rates: TargetSnapshotStore.loadRates())
      completion(Timeline(entries: [PortfolioEntry(date: .now, portfolio: portfolio)], policy: .after(.now.addingTimeInterval(20 * 60))))
    }
  }
}

/// Your portfolio's value and today's move, on the watch face.
struct PortfolioComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PortfolioComplication", provider: PortfolioProvider()) { entry in
      PortfolioComplicationView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Portfolio")
    .description("Your portfolio value and today's change.")
    .supportedFamilies([.accessoryRectangular, .accessoryCircular, .accessoryInline, .accessoryCorner])
  }
}

private struct PortfolioComplicationView: View {
  var entry: PortfolioEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    if let portfolio = entry.portfolio {
      let change = portfolio.dayChange.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
      let color = portfolio.dayChange >= 0 ? Brand.buy : Brand.sell
      switch family {
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 1) {
          HStack {
            Text("Portfolio")
              .font(.caption2.weight(.semibold))
              .widgetAccentable()
            Spacer()
            Text(change)
              .font(.caption2.weight(.bold))
              .foregroundStyle(color)
          }
          Text(portfolio.formatted(portfolio.value))
            .font(.headline)
            .monospacedDigit()
            .minimumScaleFactor(0.5)
          if portfolio.history.count > 1 {
            Chart(Array(portfolio.history.enumerated()), id: \.offset) { index, value in
              LineMark(x: .value("Day", index), y: .value("Value", value))
                .foregroundStyle(color)
                .interpolationMethod(.monotone)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
          }
        }
      case .accessoryInline:
        Text("Portfolio \(change)")
      case .accessoryCorner:
        Text(change)
          .foregroundStyle(color)
          .widgetCurvesContent()
          .widgetLabel { Text(portfolio.formatted(portfolio.value)) }
      default:
        VStack(spacing: 0) {
          Image(systemName: portfolio.dayChange >= 0 ? "arrow.up.right" : "arrow.down.right")
            .font(.caption.weight(.bold))
          Text(portfolio.dayChange.formatted(.percent.precision(.fractionLength(1))))
            .font(.caption.weight(.semibold))
            .minimumScaleFactor(0.5)
        }
        .foregroundStyle(color)
        .widgetAccentable()
      }
    } else {
      Image(systemName: "chart.pie")
    }
  }
}

// MARK: - Market

struct MarketEntry: TimelineEntry {
  var date: Date
  var isOpen: Bool
  var nextChange: Date
}

struct MarketProvider: TimelineProvider {
  func placeholder(in context: Context) -> MarketEntry {
    MarketEntry(date: .now, isOpen: true, nextChange: .now.addingTimeInterval(7_200))
  }

  func getSnapshot(in context: Context, completion: @escaping (MarketEntry) -> Void) {
    completion(MarketEntry(date: .now, isOpen: MarketClock.isOpen(), nextChange: MarketClock.nextChange()))
  }

  /// One entry now and one at each open or close, so the face flips right on time.
  func getTimeline(in context: Context, completion: @escaping (Timeline<MarketEntry>) -> Void) {
    var entries: [MarketEntry] = []
    var date = Date.now
    for _ in 0..<6 {
      let next = MarketClock.nextChange(after: date)
      entries.append(MarketEntry(date: date, isOpen: MarketClock.isOpen(at: date), nextChange: next))
      date = next.addingTimeInterval(1)
    }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

/// Whether the US market is open, with a countdown to the next open or close.
struct MarketComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "MarketComplication", provider: MarketProvider()) { entry in
      MarketComplicationView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Market Hours")
    .description("Whether the US market is open, and a countdown to the bell.")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
  }
}

private struct MarketComplicationView: View {
  var entry: MarketEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    switch family {
    case .accessoryRectangular:
      VStack(alignment: .leading, spacing: 2) {
        Label(entry.isOpen ? "Market open" : "Market closed", systemImage: entry.isOpen ? "bell.fill" : "moon.zzz.fill")
          .font(.headline)
          .widgetAccentable()
        HStack(spacing: 3) {
          Text(entry.isOpen ? "Closes in" : "Opens in")
          Text(entry.nextChange, style: .relative)
        }
        .font(.caption)
        .monospacedDigit()
      }
    case .accessoryInline:
      Text(entry.isOpen ? "Market closes \(entry.nextChange, style: .relative)" : "Market opens \(entry.nextChange, style: .relative)")
    default:
      VStack(spacing: 0) {
        Image(systemName: entry.isOpen ? "bell.fill" : "moon.zzz.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(entry.isOpen ? Brand.buy : .secondary)
        Text(entry.isOpen ? "OPEN" : "SHUT")
          .font(.system(size: 10, weight: .bold))
      }
      .widgetAccentable()
    }
  }
}
