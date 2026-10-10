import Foundation

/// Portfolio totals, history, allocation, and dividends in the user's base currency.
struct PortfolioSummary {
  struct Position: Identifiable {
    var holding: Holding
    var quote: Quote
    var value: Double
    var cost: Double
    var dayChangeAmount: Double
    var weight: Double = 0
    var annualDividend: Double

    var id: String { holding.symbol }
    var totalReturn: Double? { cost > 0 ? value / cost - 1 : nil }
  }

  struct Slice: Identifiable {
    var label: String
    var value: Double
    var share: Double
    var id: String { label }
  }

  struct Payment: Identifiable {
    var symbol: String
    var date: Date
    var amount: Double
    var id: String { "\(symbol)-\(date.timeIntervalSince1970)" }
  }

  var holdings: [Holding]
  var quotes: [String: Quote]
  var baseCurrency: String
  var convert: (Double, String) -> Double?

  var positions: [Position] {
    let raw = holdings.compactMap { holding -> Position? in
      guard holding.isOwned, let quote = quotes[holding.symbol],
            let value = convert(holding.value(at: quote.price), quote.currency) else { return nil }
      let cost = convert(holding.costBasis, quote.currency) ?? 0
      let previous = convert(holding.shares * quote.previousClose, quote.currency) ?? value
      let dividend = convert(holding.shares * quote.trailingAnnualDividend, quote.currency) ?? 0
      return Position(holding: holding, quote: quote, value: value, cost: cost, dayChangeAmount: value - previous, annualDividend: dividend)
    }
    let total = raw.reduce(0) { $0 + $1.value }
    return raw.map { position in
      var position = position
      position.weight = total == 0 ? 0 : position.value / total
      return position
    }
    .sorted { $0.value > $1.value }
  }

  var hasPositions: Bool { !positions.isEmpty }

  var totalValue: Double { positions.reduce(0) { $0 + $1.value } }
  var dayChangeAmount: Double { positions.reduce(0) { $0 + $1.dayChangeAmount } }
  var dayChange: Double {
    let previous = totalValue - dayChangeAmount
    return previous == 0 ? 0 : dayChangeAmount / previous
  }

  /// Positions with a known cost basis.
  private var costedPositions: [Position] { positions.filter { $0.cost > 0 } }
  var costBasis: Double { costedPositions.reduce(0) { $0 + $1.cost } }
  var unrealizedGain: Double { costedPositions.reduce(0) { $0 + $1.value - $1.cost } }
  var totalReturn: Double? { costBasis > 0 ? unrealizedGain / costBasis : nil }

  /// Combined value over the last `sessions` trading days, using today's exchange rates.
  func history(sessions: Int) -> (values: [Double], dates: [Date]) {
    let series = positions.map { position in
      (position.holding.shares * (convert(1, position.quote.currency) ?? 0), position.quote.recent(sessions))
    }
    guard let length = series.map(\.1.values.count).min(), length > 1,
          let reference = series.max(by: { $0.1.dates.count < $1.1.dates.count }) else { return ([], []) }
    let values = (0..<length).map { index in
      series.reduce(0) { total, item in total + item.0 * item.1.values[item.1.values.count - length + index] }
    }
    return (values, Array(reference.1.dates.suffix(length)))
  }

  /// Combined value over a preset or custom period (up to the last year).
  func history(period: ChartPeriod) -> (values: [Double], dates: [Date]) {
    let full = history(sessions: 260)
    return period.slice(values: full.values, dates: full.dates)
  }

  /// The first date with portfolio history.
  var earliestDate: Date { history(sessions: 260).dates.first ?? .now.addingTimeInterval(-365 * 86_400) }

  // MARK: Allocation

  var allocationByHolding: [Slice] {
    positions.map { Slice(label: $0.holding.symbol, value: $0.value, share: $0.weight) }
  }

  var allocationByType: [Slice] { group { $0.quote.assetType.isEmpty ? "Other" : Self.typeName($0.quote.assetType) } }
  var allocationByCurrency: [Slice] { group { $0.quote.currency } }

  private func group(by key: (Position) -> String) -> [Slice] {
    let total = totalValue
    return Dictionary(grouping: positions, by: key)
      .map { label, items in
        let value = items.reduce(0) { $0 + $1.value }
        return Slice(label: label, value: value, share: total == 0 ? 0 : value / total)
      }
      .sorted { $0.value > $1.value }
  }

  private static func typeName(_ raw: String) -> String {
    switch raw.uppercased() {
    case "EQUITY": "Stocks"
    case "ETF": "ETFs"
    case "CRYPTOCURRENCY": "Crypto"
    case "MUTUALFUND": "Funds"
    case "INDEX": "Indexes"
    default: raw.capitalized
    }
  }

  // MARK: Dividends

  var annualDividendIncome: Double { positions.reduce(0) { $0 + $1.annualDividend } }
  var dividendYield: Double { totalValue == 0 ? 0 : annualDividendIncome / totalValue }
  var yieldOnCost: Double? { costBasis > 0 ? costedPositions.reduce(0) { $0 + $1.annualDividend } / costBasis : nil }

  /// Expected payments over the next twelve months.
  var upcomingPayments: [Payment] {
    positions.flatMap { position in
      position.quote.projectedDividends.compactMap { payment in
        convert(payment.amount * position.holding.shares, position.quote.currency)
          .map { Payment(symbol: position.holding.symbol, date: payment.date, amount: $0) }
      }
    }
    .sorted { $0.date < $1.date }
  }

  /// Expected dividend income for each of the next twelve months.
  var monthlyDividends: [(month: Date, amount: Double)] {
    let calendar = Calendar.current
    let start = calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
    return (0..<12).map { offset in
      let month = calendar.date(byAdding: .month, value: offset, to: start) ?? start
      let amount = upcomingPayments
        .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
        .reduce(0) { $0 + $1.amount }
      return (month, amount)
    }
  }

  // MARK: Alerts and planning

  var activeAlerts: [PriceAlert] { holdings.flatMap(\.activeAlerts) }

  /// Active alerts sorted closest-to-trigger first.
  var nearestAlerts: [PriceAlert] {
    activeAlerts.sorted { lhs, rhs in
      let left = quotes[lhs.symbol].flatMap { lhs.distance(for: $0) } ?? .infinity
      let right = quotes[rhs.symbol].flatMap { rhs.distance(for: $0) } ?? .infinity
      return left < right
    }
  }

  func closeAlertCount(threshold: Double = 0.035) -> Int {
    activeAlerts.filter { alert in
      quotes[alert.symbol].flatMap { alert.distance(for: $0) }.map { $0 < threshold } ?? false
    }.count
  }

  /// Money set aside across active buy alerts, in the base currency.
  var plannedBuys: Double {
    activeAlerts.filter { $0.kind.side == .buy && $0.budget > 0 }.reduce(0) { total, alert in
      total + (quotes[alert.symbol].flatMap { convert(alert.budget, $0.currency) } ?? alert.budget)
    }
  }

  var biggestPosition: Position? { positions.first }
}
