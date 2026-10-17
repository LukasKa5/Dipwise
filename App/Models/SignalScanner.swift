import Foundation

/// A technical signal showing on one of the user's stocks today.
struct MarketSignal: Identifiable {
  var symbol: String
  var kind: AlertKind
  var headline: String
  var detail: String

  var id: String { "\(symbol)-\(kind.rawValue)" }
}

/// Scans quotes for signals that match Dipwise's smart alerts.
enum SignalScanner {
  static func signals(for holdings: [Holding], quotes: [String: Quote]) -> [MarketSignal] {
    holdings.flatMap { holding -> [MarketSignal] in
      guard let quote = quotes[holding.symbol] else { return [] }
      return scan(quote)
    }
  }

  static func scan(_ quote: Quote) -> [MarketSignal] {
    var signals: [MarketSignal] = []
    let symbol = quote.symbol
    func add(_ kind: AlertKind, _ headline: String, _ detail: String) {
      signals.append(MarketSignal(symbol: symbol, kind: kind, headline: headline, detail: detail))
    }

    if let rsi = quote.rsi() {
      if rsi <= 30 { add(.rsiOversold, String(localized: "Oversold"), String(localized: "RSI is \(Int(rsi)). Selling may be overdone.")) }
      if rsi >= 70 { add(.rsiOverbought, String(localized: "Overbought"), String(localized: "RSI is \(Int(rsi)). Buying may be overheated.")) }
    }
    if let cross = recentCross(quote) {
      add(cross ? .goldenCross : .deathCross, cross ? String(localized: "Golden cross") : String(localized: "Death cross"),
          cross ? String(localized: "The 50-day average crossed above the 200-day recently.") : String(localized: "The 50-day average crossed below the 200-day recently."))
    }
    if let bands = quote.bollinger {
      if quote.price <= bands.lower { add(.bollingerLow, String(localized: "At the lower band"), String(localized: "Price is at the bottom of its normal range.")) }
      if quote.price >= bands.upper { add(.bollingerHigh, String(localized: "At the upper band"), String(localized: "Price is at the top of its normal range.")) }
    }
    if quote.closes.count > 30 {
      if quote.price <= quote.previousLow { add(.newLow, String(localized: "New 52-week low"), String(localized: "The lowest price in a year.")) }
      if quote.price >= quote.previousHigh { add(.newHigh, String(localized: "New 52-week high"), String(localized: "The highest price in a year.")) }
    }
    if let ratio = quote.volumeRatio, ratio >= 2 {
      add(.volumeSpike, String(localized: "Volume spike"), "\(ratio.formatted(.number.precision(.fractionLength(1))))× the usual number of shares traded.")
    }
    if abs(quote.change) >= 0.04 {
      add(.dailyMove, quote.change > 0 ? String(localized: "Big jump") : String(localized: "Big drop"), String(localized: "Moved \(quote.change.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))) today."))
    }
    if quote.drawdownFromHigh <= -0.2 {
      add(.dropFromHigh, String(localized: "Deep dip"), "\(abs(quote.drawdownFromHigh).formatted(.percent.precision(.fractionLength(0)))) below its 52-week high.")
    }
    if let macd = recentMACDFlip(quote) {
      add(macd ? .macdBullish : .macdBearish, macd ? String(localized: "Momentum turning up") : String(localized: "Momentum turning down"), String(localized: "MACD crossed its signal line in the last few days."))
    }
    return signals
  }

  /// True for a golden cross and false for a death cross within the last ten sessions.
  private static func recentCross(_ quote: Quote) -> Bool? {
    let closes = quote.closes
    guard closes.count >= 211 else { return nil }
    func average(_ days: Int, endingAt end: Int) -> Double {
      closes[(end - days + 1)...end].reduce(0, +) / Double(days)
    }
    let last = closes.count - 1
    let now = average(50, endingAt: last) - average(200, endingAt: last)
    let before = average(50, endingAt: last - 10) - average(200, endingAt: last - 10)
    if now > 0 && before <= 0 { return true }
    if now < 0 && before >= 0 { return false }
    return nil
  }

  private static func recentMACDFlip(_ quote: Quote) -> Bool? {
    guard quote.closes.count > 40, let now = quote.macd else { return nil }
    var earlier = quote
    earlier.closes = Array(quote.closes.dropLast(3))
    guard let before = earlier.macd else { return nil }
    let nowUp = now.line > now.signal
    let beforeUp = before.line > before.signal
    return nowUp == beforeUp ? nil : nowUp
  }
}
