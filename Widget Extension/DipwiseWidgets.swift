import SwiftUI
import WidgetKit

@main
struct DipwiseWidgets: WidgetBundle {
  var body: some Widget {
    PlansWidget()
    StockPlanWidget()
    StreakWidget()
  }
}

/// Loads cached quotes, refreshes them from the network, and saves them back for the app.
enum WidgetData {
  static func quotes(for symbols: [String]) async -> [String: Quote] {
    var quotes = TargetSnapshotStore.loadQuotes()
    let fresh = await QuoteService().quotes(for: symbols)
    if !fresh.isEmpty {
      quotes.merge(fresh) { _, new in new }
      TargetSnapshotStore.save(quotes: quotes)
    }
    return quotes
  }

  static let refresh: TimeInterval = 30 * 60
}
