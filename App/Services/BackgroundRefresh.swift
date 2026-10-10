import BackgroundTasks
import Foundation
import SwiftData

enum BackgroundRefresh {
  static let identifier = "dipwise.refresh"

  static func schedule() {
    let request = BGAppRefreshTaskRequest(identifier: identifier)
    request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(request)
  }

  @MainActor
  static func run(container: ModelContainer) async {
    schedule()
    await MarketMonitor.refresh(context: ModelContext(container), quotes: QuoteStore(), flock: FlockService())
  }
}
