import Foundation
import SwiftData

/// Refreshes prices, fires alerts, and updates the widgets and watch. Used in the foreground and in background refresh.
@MainActor
enum MarketMonitor {
  static func refresh(context: ModelContext, quotes: QuoteStore, flock: FlockService? = nil) async {
    let holdings = (try? context.fetch(FetchDescriptor<Holding>())) ?? []
    await quotes.refresh(symbols: holdings.map(\.symbol))

    let alerts = holdings.flatMap { $0.alerts ?? [] }
    let headsUp = AlertSettings.isPro && AlertSettings.headsUpEnabled ? AlertSettings.headsUpThreshold : nil
    let events = AlertEngine.evaluate(alerts, quotes: quotes.quotes, headsUpThreshold: headsUp)
    try? context.save()
    await NotificationManager.post(events)
    if let flock {
      for event in events where event.kind == .reached {
        await flock.markTriggered(event.alert, price: event.quote.price)
      }
    }
    SnapshotPublisher.publish(context: context)
  }
}
