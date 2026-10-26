import Foundation
import SwiftData
import WidgetKit

/// Shares the active alerts with the widgets and Apple Watch.
@MainActor
enum SnapshotPublisher {
  static func publish(context: ModelContext) {
    let alerts = (try? context.fetch(FetchDescriptor<PriceAlert>(predicate: #Predicate { $0.isActive }))) ?? []
    let targets = alerts.filter { $0.holding != nil }.map(\.watchedTarget)
    TargetSnapshotStore.save(targets: targets)
    let holdings = (try? context.fetch(FetchDescriptor<Holding>(sortBy: [SortDescriptor(\.addedAt)]))) ?? []
    let stocks = holdings.map { WatchedStock(symbol: $0.symbol, name: $0.name, shares: $0.shares, averageCost: $0.averageCost) }
    TargetSnapshotStore.save(stocks: stocks)
    TargetSnapshotStore.save(baseCurrency: AlertSettings.baseCurrency)
    WidgetCenter.shared.reloadAllTimelines()
    PushAlerts.sync(targets: targets, quotes: TargetSnapshotStore.loadQuotes())
    WatchSync.shared.send(targets: targets, stocks: stocks, baseCurrency: AlertSettings.baseCurrency, progress: ProgressSnapshot.load())
  }
}
