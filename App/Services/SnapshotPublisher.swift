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
    WidgetCenter.shared.reloadAllTimelines()
    WatchSync.shared.send(targets: targets)
  }
}
