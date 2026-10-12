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
  var opens: [Double] = []
  var volumes: [Double] = []
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

  // MARK: Indicators

  /// Highest and lowest close before today.
  var previousHigh: Double { closes.dropLast().max() ?? price }
  var previousLow: Double { closes.dropLast().min() ?? price }

  /// Price change over the last `sessions` trading days.
  func change(over sessions: Int) -> Double {
    guard closes.count > sessions, let then = closes.dropLast(sessions).last, then > 0 else { return 0 }
    return price / then - 1
  }

  /// How far today's open gapped from yesterday's close.
  var gap: Double {
    guard let open = opens.last, previousClose > 0, open > 0 else { return 0 }
    return open / previousClose - 1
  }

  /// Today's volume compared with the 20-day average.
  var volumeRatio: Double? {
    guard volumes.count > 21, let today = volumes.last, today > 0 else { return nil }
    let average = volumes.dropLast().suffix(20).reduce(0, +) / 20
    return average > 0 ? today / average : nil
  }

  /// Relative Strength Index with Wilder's smoothing.
  func rsi(period: Int = 14) -> Double? {
    guard closes.count > period + 1 else { return nil }
    let changes = zip(closes.dropFirst(), closes).map { $0 - $1 }
    var gain = changes.prefix(period).map { max($0, 0) }.reduce(0, +) / Double(period)
    var loss = changes.prefix(period).map { max(-$0, 0) }.reduce(0, +) / Double(period)
    for change in changes.dropFirst(period) {
      gain = (gain * Double(period - 1) + max(change, 0)) / Double(period)
      loss = (loss * Double(period - 1) + max(-change, 0)) / Double(period)
    }
    guard loss > 0 else { return 100 }
    return 100 - 100 / (1 + gain / loss)
  }

  private static func ema(_ values: [Double], period: Int) -> [Double] {
    guard let first = values.first else { return [] }
    let k = 2 / Double(period + 1)
    var result = [first]
    for value in values.dropFirst() { result.append(value * k + (result.last ?? value) * (1 - k)) }
    return result
  }

  /// MACD line and its signal line (12, 26, 9).
  var macd: (line: Double, signal: Double)? {
    guard closes.count > 35 else { return nil }
    let fast = Self.ema(closes, period: 12)
    let slow = Self.ema(closes, period: 26)
    let line = zip(fast, slow).map { $0 - $1 }
    let signal = Self.ema(line, period: 9)
    guard let lastLine = line.last, let lastSignal = signal.last else { return nil }
    return (lastLine, lastSignal)
  }

  /// Bollinger Bands (20-day average ± 2 standard deviations).
  var bollinger: (lower: Double, middle: Double, upper: Double)? {
    guard closes.count >= 20 else { return nil }
    let window = closes.suffix(20)
    let mean = window.reduce(0, +) / 20
    let deviation = sqrt(window.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / 20)
    return (mean - 2 * deviation, mean, mean + 2 * deviation)
  }

  /// Days until the next expected dividend.
  var daysToNextDividend: Int? {
    projectedDividends.first.map { Calendar.current.dateComponents([.day], from: .now, to: $0.date).day ?? 0 }
  }

  func formatted(_ value: Double) -> String {
    value.formatted(.currency(code: currency).precision(.fractionLength(value < 10 ? 2...4 : 2...2)))
  }
}

enum ChartRange: String, CaseIterable, Identifiable, Codable {
  case day = "1d"
  case week = "5d"
  case month = "1mo"
  case threeMonths = "3mo"
  case year = "1y"
  case fiveYears = "5y"

  var id: Self { self }

  var title: String {
    switch self {
    case .day: "1D"
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
    case .day: nil
    case .week: 5
    case .month: 22
    case .threeMonths: 64
    case .year: 260
    case .fiveYears: nil
    }
  }
}
