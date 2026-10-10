import SwiftUI
import WidgetKit

@main
struct DipwiseWidgets: WidgetBundle {
  var body: some Widget {
    NearTargetsWidget()
  }
}

struct NearTargetsWidget: Widget {
  let kind = "NearTargetsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: TargetsProvider()) { entry in
      NearTargetsWidgetView(entry: entry)
    }
    .configurationDisplayName("Near Your Targets")
    .description("See which stocks are closest to your buy and sell targets.")
    .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
  }
}

struct TargetsEntry: TimelineEntry {
  var date: Date
  var statuses: [TargetStatus]
}

struct TargetsProvider: TimelineProvider {
  func placeholder(in context: Context) -> TargetsEntry {
    TargetsEntry(date: .now, statuses: Self.sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (TargetsEntry) -> Void) {
    let statuses = TargetStatus.sorted(targets: TargetSnapshotStore.loadTargets(), quotes: TargetSnapshotStore.loadQuotes())
    completion(TargetsEntry(date: .now, statuses: statuses.isEmpty && context.isPreview ? Self.sample : statuses))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<TargetsEntry>) -> Void) {
    Task {
      let targets = TargetSnapshotStore.loadTargets()
      var quotes = TargetSnapshotStore.loadQuotes()
      let fresh = await QuoteService().quotes(for: targets.map(\.symbol))
      if !fresh.isEmpty {
        quotes.merge(fresh) { _, new in new }
        TargetSnapshotStore.save(quotes: quotes)
      }
      let entry = TargetsEntry(date: .now, statuses: TargetStatus.sorted(targets: targets, quotes: quotes))
      completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
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
      target: WatchedTarget(id: UUID(), symbol: "MSFT", name: "Microsoft", rule: AlertRule(kind: .priceAbove, lower: 560)),
      quote: Quote(symbol: "MSFT", name: "Microsoft", currency: "USD", price: 512.3, previousClose: 508, closes: [], updatedAt: .now)
    ),
  ]
}
