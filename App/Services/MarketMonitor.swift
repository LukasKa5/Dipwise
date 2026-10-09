import Foundation
import SwiftData

/// Refreshes prices, fires alerts, and updates the widgets and watch. Used in the foreground and in background refresh.
@MainActor
enum MarketMonitor {
  static func refresh(context: ModelContext, quotes: QuoteStore) async {
    let holdings = (try? context.fetch(FetchDescriptor<Holding>())) ?? []
    await quotes.refresh(symbols: holdings.map(\.symbol))

    let alerts = holdings.flatMap { $0.alerts ?? [] }
    let headsUp = AlertSettings.isPro && AlertSettings.headsUpEnabled ? AlertSettings.headsUpThreshold : nil
    let events = AlertEngine.evaluate(alerts, quotes: quotes.quotes, headsUpThreshold: headsUp)
    try? context.save()
    await NotificationManager.post(events)
    SnapshotPublisher.publish(context: context)
  }
}
