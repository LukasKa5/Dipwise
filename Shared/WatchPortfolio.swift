import Foundation

/// Portfolio totals worked out from shared positions and cached prices, for Apple Watch and its complications.
struct WatchPortfolio: Hashable {
  var value: Double
  var dayChangeAmount: Double
  var currency: String
  /// Daily values over recent sessions, oldest first.
  var history: [Double]

  var dayChange: Double {
    let previous = value - dayChangeAmount
    return previous > 0 ? dayChangeAmount / previous : 0
  }

  func formatted(_ amount: Double) -> String {
    amount.formatted(.currency(code: currency).precision(.fractionLength(amount >= 10_000 ? 0 : 2)))
  }

  /// Nil when nothing is owned. Positions in a currency without a known rate are left out rather than guessed.
  static func make(stocks: [WatchedStock], quotes: [String: Quote], currency: String, rates: [String: Double], sessions: Int = 30) -> WatchPortfolio? {
    var value = 0.0
    var change = 0.0
    var history = [Double](repeating: 0, count: sessions)
    var counted = 0
    for stock in stocks where stock.isOwned {
      guard let quote = quotes[stock.symbol], let shares = stock.shares else { continue }
      let rate = quote.currency == currency ? 1 : rates[quote.currency]
      guard let rate else { continue }
      counted += 1
      value += quote.price * shares * rate
      change += (quote.price - quote.previousClose) * shares * rate
      let closes = Array(quote.closes.suffix(sessions))
      let offset = sessions - closes.count
      for (index, close) in closes.enumerated() {
        history[offset + index] += close * shares * rate
      }
    }
    guard counted > 0 else { return nil }
    return WatchPortfolio(value: value, dayChangeAmount: change, currency: currency, history: history.drop { $0 == 0 }.map { $0 })
  }

  static func load() -> WatchPortfolio? {
    make(stocks: TargetSnapshotStore.loadStocks(), quotes: TargetSnapshotStore.loadQuotes(),
         currency: TargetSnapshotStore.loadBaseCurrency(), rates: TargetSnapshotStore.loadRates())
  }
}
