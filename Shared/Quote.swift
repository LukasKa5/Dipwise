import Foundation

struct DividendPayment: Codable, Hashable {
  var date: Date
  var amount: Double
}

struct Quote: Codable, Hashable {
  var symbol: String
  var name: String
  var currency: String
  var exchange: String = ""
  var assetType: String = ""
  var price: Double
  var previousClose: Double
  /// Daily closes for about a year, oldest first. The last value is the current price.
  var closes: [Double]
  /// Session dates matching `closes`.
  var dates: [Date] = []
  var dividends: [DividendPayment] = []
  var updatedAt: Date

  var change: Double {
    previousClose == 0 ? 0 : price / previousClose - 1
  }

  var high52: Double { closes.max() ?? price }
  var low52: Double { closes.min() ?? price }
  var drawdownFromHigh: Double { high52 == 0 ? 0 : price / high52 - 1 }

  func movingAverage(days: Int) -> Double? {
    guard closes.count >= days, days > 0 else { return nil }
    return closes.suffix(days).reduce(0, +) / Double(days)
  }

  /// The most recent `sessions` closes with their dates.
  func recent(_ sessions: Int) -> (values: [Double], dates: [Date]) {
    (Array(closes.suffix(sessions)), Array(dates.suffix(sessions)))
  }

  /// Dividends paid over the last twelve months, per share.
  var trailingAnnualDividend: Double {
    let cutoff = Date.now.addingTimeInterval(-365 * 24 * 3600)
    return dividends.filter { $0.date > cutoff }.reduce(0) { $0 + $1.amount }
  }

  var dividendYield: Double {
    price == 0 ? 0 : trailingAnnualDividend / price
  }

  /// Expected payment dates for the next twelve months, projected from the last year's schedule.
  var projectedDividends: [DividendPayment] {
    let cutoff = Date.now.addingTimeInterval(-365 * 24 * 3600)
    let lastYear = dividends.filter { $0.date > cutoff }.sorted { $0.date < $1.date }
    return lastYear.map { payment in
      var date = payment.date
      while date < .now { date = Calendar.current.date(byAdding: .year, value: 1, to: date) ?? date.addingTimeInterval(365 * 24 * 3600) }
      return DividendPayment(date: date, amount: payment.amount)
    }
    .sorted { $0.date < $1.date }
  }

  func formatted(_ value: Double) -> String {
    value.formatted(.currency(code: currency).precision(.fractionLength(value < 10 ? 2...4 : 2...2)))
  }
}

enum ChartRange: String, CaseIterable, Identifiable, Codable {
  case week = "5d"
  case month = "1mo"
  case threeMonths = "3mo"
  case year = "1y"
  case fiveYears = "5y"

  var id: Self { self }

  var title: String {
    switch self {
    case .week: "1W"
    case .month: "1M"
    case .threeMonths: "3M"
    case .year: "1Y"
    case .fiveYears: "5Y"
    }
  }

  /// Sessions covered by this range within a one-year quote, or nil when it needs its own request.
  var sessions: Int? {
    switch self {
    case .week: 5
    case .month: 22
    case .threeMonths: 64
    case .year: 260
    case .fiveYears: nil
    }
  }
}
