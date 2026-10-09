import Foundation
import Observation

/// Latest prices for every symbol the user follows, cached for offline launches and widgets.
@MainActor
@Observable
final class QuoteStore {
  private(set) var quotes: [String: Quote]
  private(set) var isRefreshing = false
  private(set) var lastError: Error?
  private let service = QuoteService()

  init() {
    quotes = TargetSnapshotStore.loadQuotes()
  }

  subscript(symbol: String) -> Quote? { quotes[symbol] }

  var lastUpdated: Date? { quotes.values.map(\.updatedAt).max() }

  func refresh(symbols: [String]) async {
    guard !symbols.isEmpty else { return }
    isRefreshing = true
    defer { isRefreshing = false }
    let fresh = await service.quotes(for: symbols)
    lastError = fresh.isEmpty ? QuoteService.QuoteError.noData : nil
    quotes.merge(fresh) { _, new in new }
    TargetSnapshotStore.save(quotes: quotes)
  }

  func store(_ quote: Quote) {
    quotes[quote.symbol] = quote
  }
}
