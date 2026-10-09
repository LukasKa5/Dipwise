import Foundation

/// Totals and history for the home screen, derived from holdings and their latest quotes.
struct PortfolioSummary {
  var holdings: [Holding]
  var quotes: [String: Quote]

  private var owned: [Holding] { holdings.filter { $0.isOwned && quotes[$0.symbol] != nil } }

  var hasPositions: Bool { !owned.isEmpty }

  var currency: String {
    owned.first.flatMap { quotes[$0.symbol]?.currency } ?? "USD"
  }

  var totalValue: Double {
    owned.reduce(0) { $0 + $1.value(at: quotes[$1.symbol]?.price ?? 0) }
  }

  var previousValue: Double {
    owned.reduce(0) { $0 + $1.shares * (quotes[$1.symbol]?.previousClose ?? 0) }
  }

  var dayChange: Double {
    previousValue == 0 ? 0 : totalValue / previousValue - 1
  }

  /// Combined daily value, aligned on the most recent sessions shared by every position.
  var history: [Double] {
    let series = owned.compactMap { holding in quotes[holding.symbol].map { (holding.shares, $0.closes) } }
    guard let length = series.map(\.1.count).min(), length > 1 else { return [] }
    return (0..<length).map { index in
      series.reduce(0) { total, item in total + item.0 * item.1[item.1.count - length + index] }
    }
  }

  var activeAlerts: [PriceAlert] {
    holdings.flatMap(\.activeAlerts)
  }

  /// Active alerts sorted closest-to-target first.
  var nearestAlerts: [PriceAlert] {
    activeAlerts.sorted { lhs, rhs in
      let left = quotes[lhs.symbol].map { lhs.distance(from: $0.price) } ?? .infinity
      let right = quotes[rhs.symbol].map { rhs.distance(from: $0.price) } ?? .infinity
      return left < right
    }
  }

  func closeAlertCount(threshold: Double = 0.035) -> Int {
    activeAlerts.filter { alert in
      quotes[alert.symbol].map { alert.distance(from: $0.price) < threshold } ?? false
    }.count
  }
}
