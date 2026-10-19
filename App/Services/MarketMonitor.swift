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
    let crowdSymbols = alerts.filter { $0.isActive && $0.kind.needsCrowd }.map(\.symbol)
    let crowd = await flock?.crowdFacts(for: crowdSymbols, quotes: quotes.quotes) ?? [:]
    let events = AlertEngine.evaluate(alerts, quotes: quotes.quotes, headsUpThreshold: headsUp, crowd: crowd)
    try? context.save()
    await NotificationManager.post(events)
    if let first = events.first(where: { $0.kind == .reached }) {
      ToastCenter.shared.show("\(first.alert.symbol): \(first.alert.kind.title)!", systemImage: "bell.badge.fill")
    }
    if let flock {
      for event in events where event.kind == .reached {
        await flock.markTriggered(event.alert, price: event.quote.price)
      }
    }
    if let flock {
      await flock.syncPortfolio(holdings: holdings.map { ($0.symbol, $0.shares) }, quotes: quotes.quotes)
    }
    SnapshotPublisher.publish(context: context)
  }
}
