import SwiftUI
import WidgetKit

/// The market at a glance: open or closed, a live countdown to the next bell, and the S&P 500 today.
/// Dippy sleeps on it while the market does.
struct MarketWidget: Widget {
  let kind = "MarketWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MarketProvider()) { entry in
      MarketWidgetView(entry: entry)
    }
    .configurationDisplayName("Market")
    .description("Whether the market is open, a countdown to the next bell, and the S&P 500 today.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

struct MarketEntry: TimelineEntry {
  var date: Date
  var market: Quote?
  /// How many of your plans Dippy is watching.
  var plans: Int
}

struct MarketProvider: TimelineProvider {
  func placeholder(in context: Context) -> MarketEntry {
    MarketEntry(date: .now, market: Self.sampleMarket, plans: 4)
  }

  func getSnapshot(in context: Context, completion: @escaping (MarketEntry) -> Void) {
    let market = Benchmark.quote ?? (context.isPreview ? Self.sampleMarket : nil)
    completion(MarketEntry(date: .now, market: market, plans: TargetSnapshotStore.loadTargets().count))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MarketEntry>) -> Void) {
    Task {
      _ = await WidgetData.quotes(for: [])
      let plans = TargetSnapshotStore.loadTargets().count
      // One entry now and one right at the next bell, so open and closed flip on time.
      let bell = MarketClock.nextChange()
      let entries = [MarketEntry(date: .now, market: Benchmark.quote, plans: plans),
                     MarketEntry(date: bell, market: Benchmark.quote, plans: plans)]
      completion(Timeline(entries: entries, policy: .after(min(bell, .now.addingTimeInterval(WidgetData.refresh)))))
    }
  }

  static let sampleMarket = Quote(symbol: Benchmark.symbol, name: "S&P 500", currency: "USD", price: 6_714.59, previousClose: 6_681.30,
                                  closes: [6_590, 6_612, 6_604, 6_641, 6_630, 6_668, 6_652, 6_690, 6_681, 6_714], updatedAt: .now)
}

struct MarketWidgetView: View {
  var entry: MarketEntry
  /// Lets the app preview a specific size.
  var previewFamily: WidgetFamily?
  /// Lets the app's previews show the market open.
  var previewIsOpen: Bool?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { previewFamily ?? environmentFamily }
  private var isOpen: Bool { previewIsOpen ?? MarketClock.isOpen(at: entry.date) }

  var body: some View {
    Group {
      switch family {
      case .accessoryRectangular: rectangular
      case .systemMedium:
        HStack(spacing: 14) {
          status
          index
        }
      default: status
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(URL(string: "dipwise://home"))
  }

  private var status: some View {
    VStack(alignment: .leading, spacing: 0) {
      if family == .systemMedium {
        WidgetTitle(text: "Market").frame(height: 24)
      } else {
        // Dippy keeps the market's hours: awake while it's open.
        WidgetHeader("Market", isPreview: previewIsOpen == true)
      }
      Spacer(minLength: 2)
      HStack(spacing: 6) {
        Circle()
          .fill(isOpen ? Brand.buy : .white.opacity(0.4))
          .frame(width: 8, height: 8)
        Text(isOpen ? "Open" : "Closed")
          .font(.system(size: 26, weight: .bold, design: .rounded))
      }
      Text(isOpen ? "Closes in" : "Opens in")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.6))
        .padding(.top, 4)
      countdownText(to: MarketClock.nextChange(after: entry.date), from: entry.date, isLive: previewFamily == nil)
        .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
        .foregroundStyle(isOpen ? Brand.buy : Brand.amber)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Spacer(minLength: 4)
      Text(entry.plans == 1 ? "Watching 1 plan" : "Watching \(entry.plans) plans")
        .font(.caption2.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @ViewBuilder
  private var index: some View {
    VStack(alignment: .leading, spacing: 4) {
      WidgetHeader("S&P 500", isPreview: previewIsOpen == true)
      if let market = entry.market {
        Text(market.price.formatted(.number.precision(.fractionLength(0))))
          .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        WidgetChangePill(change: market.change)
        WidgetSparkline(values: Array(market.closes.suffix(30)))
          .padding(.top, 2)
      } else {
        Spacer()
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text(isOpen ? "Market open" : "Market closed")
        .font(.headline)
        .widgetAccentable()
      HStack(spacing: 3) {
        Text(isOpen ? "Closes" : "Opens")
        Text(MarketClock.nextChange(after: entry.date), style: .relative)
      }
      .font(.caption)
      if let market = entry.market {
        Text("S&P 500 \(changeText(market.change))")
          .font(.caption.monospacedDigit())
      }
    }
  }
}
