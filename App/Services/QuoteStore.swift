import Foundation
import Observation

/// Latest prices and exchange rates for everything the user follows, cached for offline launches and widgets.
@MainActor
@Observable
final class QuoteStore {
  private(set) var quotes: [String: Quote]
  private(set) var isRefreshing = false
  private(set) var lastError: Error?
  private(set) var baseCurrency = AlertSettings.baseCurrency
  /// Units of base currency per unit of each quote currency.
  private(set) var rates: [String: Double] = [:]
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
    await refreshRates()
  }

  func store(_ quote: Quote) {
    quotes[quote.symbol] = quote
  }

  func setBaseCurrency(_ currency: String) async {
    baseCurrency = currency
    rates = [:]
    await refreshRates()
  }

  private func refreshRates() async {
    let currencies = Set(quotes.values.map(\.currency)).subtracting([baseCurrency]).subtracting(rates.keys)
    for currency in currencies {
      if let rate = await service.exchangeRate(from: currency, to: baseCurrency) {
        rates[currency] = rate
      }
    }
  }

  /// Converts an amount into the base currency, or returns nil while the rate is unknown.
  func toBase(_ amount: Double, from currency: String) -> Double? {
    if currency == baseCurrency { return amount }
    return rates[currency].map { amount * $0 }
  }

  func formatBase(_ amount: Double) -> String {
    amount.formatted(.currency(code: baseCurrency))
  }
}
