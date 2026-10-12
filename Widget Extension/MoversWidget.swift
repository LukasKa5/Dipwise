import SwiftUI
import WidgetKit

/// Today's biggest moves among the stocks you watch.
struct MoversWidget: Widget {
  let kind = "MoversWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: MoversProvider()) { entry in
      MoversWidgetView(entry: entry)
    }
    .configurationDisplayName("Today's Movers")
    .description("Your stocks that moved the most today, up and down.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
  }
}

struct MoversEntry: TimelineEntry {
  var date: Date
  /// Watched stocks, biggest move first.
  var quotes: [Quote]

  var gainers: [Quote] { quotes.filter { $0.change >= 0 }.sorted { $0.change > $1.change } }
  var losers: [Quote] { quotes.filter { $0.change < 0 }.sorted { $0.change < $1.change } }
}

struct MoversProvider: TimelineProvider {
  func placeholder(in context: Context) -> MoversEntry {
    MoversEntry(date: .now, quotes: Self.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (MoversEntry) -> Void) {
    let quotes = Self.sorted(TargetSnapshotStore.loadStocks().compactMap { TargetSnapshotStore.loadQuotes()[$0.symbol] })
    completion(MoversEntry(date: .now, quotes: quotes.isEmpty && context.isPreview ? Self.sample : quotes))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<MoversEntry>) -> Void) {
    Task {
      let symbols = TargetSnapshotStore.loadStocks().map(\.symbol)
      let quotes = await WidgetData.quotes(for: symbols)
      let sorted = Self.sorted(symbols.compactMap { quotes[$0] })
      let entries = WidgetData.livingDates().map { MoversEntry(date: $0, quotes: sorted) }
      completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(WidgetData.refresh))))
    }
  }

  static func sorted(_ quotes: [Quote]) -> [Quote] {
    quotes.sorted { abs($0.change) > abs($1.change) }
  }

  static let sample: [Quote] = [
    Quote(symbol: "NVDA", name: "NVIDIA", currency: "USD", price: 182.4, previousClose: 176.1, closes: [170, 172, 171, 175, 174, 178, 176.1, 182.4], updatedAt: .now),
    Quote(symbol: "TSLA", name: "Tesla", currency: "USD", price: 241.2, previousClose: 249.9, closes: [255, 252, 254, 250, 251, 249.9, 241.2], updatedAt: .now),
    Quote(symbol: "AAPL", name: "Apple", currency: "USD", price: 247.3, previousClose: 244.1, closes: [240, 241, 243, 242, 244.1, 247.3], updatedAt: .now),
    Quote(symbol: "MSFT", name: "Microsoft", currency: "USD", price: 508.2, previousClose: 512.9, closes: [515, 514, 516, 512.9, 508.2], updatedAt: .now),
  ]
}

struct MoversWidgetView: View {
  var entry: MoversEntry
  /// Lets the app preview a specific size.
  var previewFamily: WidgetFamily?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { previewFamily ?? environmentFamily }

  var body: some View {
    Group {
      if entry.quotes.isEmpty {
        VStack(spacing: 8) {
          WidgetOwl(size: 44)
          Text("Add stocks in Dipwise")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
        }
      } else {
        switch family {
        case .accessoryRectangular: rectangular
        case .systemMedium: medium
        default: small
        }
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(entry.quotes.first.flatMap { URL(string: "dipwise://stock/\($0.symbol)") })
  }

  @ViewBuilder
  private var small: some View {
    if let top = entry.quotes.first {
      let color = top.change >= 0 ? Brand.buy : Brand.sell
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 6) {
          WidgetBadge(symbol: top.symbol, size: 24)
          VStack(alignment: .leading, spacing: 0) {
            Text(top.symbol)
              .font(.subheadline.bold())
              .lineLimit(1)
              .minimumScaleFactor(0.6)
            Text("Top mover")
              .font(.caption2.weight(.semibold))
              .foregroundStyle(.white.opacity(0.6))
          }
          Spacer(minLength: 0)
          LivingDippy(size: 20, date: entry.date, seed: 3, isPreview: previewFamily != nil)
        }
        Text(changeText(top.change))
          .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
          .padding(.top, 4)
          .foregroundStyle(color)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        WidgetSparkline(values: Array(top.closes.suffix(22)))
          .frame(maxHeight: .infinity)
        HStack(spacing: 4) {
          ForEach(entry.quotes.dropFirst().prefix(2), id: \.symbol) { quote in
            Text("\(quote.symbol) \(changeText(quote.change))")
              .font(.system(size: 10, weight: .bold).monospacedDigit())
              .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
              .lineLimit(1)
              .minimumScaleFactor(0.6)
          }
        }
      }
    }
  }

  private var medium: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        WidgetDippyLine(text: "Today's movers", date: entry.date, isPreview: previewFamily != nil)
        Spacer(minLength: 0)
        Text(MarketClock.isOpen() ? "Market open" : "Market closed")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(MarketClock.isOpen() ? Brand.buy : .white.opacity(0.55))
      }
      HStack(alignment: .top, spacing: 8) {
        WidgetTile(padding: 7) { column(title: "Up", quotes: Array(entry.gainers.prefix(3))) }
        WidgetTile(padding: 7) { column(title: "Down", quotes: Array(entry.losers.prefix(3))) }
      }
      Spacer(minLength: 0)
    }
  }

  private func column(title: String, quotes: [Quote]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption2.weight(.heavy))
        .foregroundStyle(.white.opacity(0.5))
        .textCase(.uppercase)
      if quotes.isEmpty {
        Text("Nothing yet")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.45))
      }
      ForEach(quotes, id: \.symbol) { quote in
        Link(destination: URL(string: "dipwise://stock/\(quote.symbol)")!) {
          HStack(spacing: 6) {
            Text(quote.symbol)
              .font(.caption.weight(.bold))
              .lineLimit(1)
              .minimumScaleFactor(0.6)
            Spacer(minLength: 2)
            Text(changeText(quote.change))
              .font(.caption2.weight(.bold).monospacedDigit())
              .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
              .lineLimit(1)
              .fixedSize()
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var rectangular: some View {
    VStack(alignment: .leading, spacing: 1) {
      Text("Movers")
        .font(.headline)
        .widgetAccentable()
      ForEach(entry.quotes.prefix(3), id: \.symbol) { quote in
        HStack {
          Text(quote.symbol)
          Spacer()
          Text(changeText(quote.change)).monospacedDigit()
        }
        .font(.caption)
      }
    }
  }
}
