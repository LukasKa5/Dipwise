import Foundation

/// Fetches market data. Swap the implementation for a licensed data provider before scaling up.
struct QuoteService: Sendable {
  enum QuoteError: Error {
    case noData
  }

  private static let session: URLSession = {
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 12
    configuration.httpAdditionalHeaders = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)"]
    return URLSession(configuration: configuration)
  }()

  /// One year of daily data (or five years of weekly data) with dividends, delayed for free members.
  func quote(for symbol: String, fiveYears: Bool = false) async throws -> Quote {
    let delay = Self.effectiveDelay
    if let proxy = MarketData.proxyURL {
      return try await Self.proxied(Quote.self, proxy, "quote", ["symbol": symbol, "fiveYears": fiveYears ? "1" : "0", "delay": "\(Int(delay))"])
    }
    var quote = try await yahooQuote(for: symbol, fiveYears: fiveYears)
    // Yahoo is real-time for most US stocks, so hold the price back by the free delay, using today's 5-minute bars.
    if delay > 0, !fiveYears, MarketClock.isOpen(), let bars = try? await yahooIntraday(for: symbol),
       let index = bars.dates.lastIndex(where: { $0 <= Date.now.addingTimeInterval(-delay) }) {
      quote.price = bars.values[index]
      if !quote.closes.isEmpty { quote.closes[quote.closes.count - 1] = quote.price }
      quote.delay = delay
    }
    return quote
  }

  /// The delay that applies now. Screenshots with a frozen date are never delayed.
  private static var effectiveDelay: TimeInterval {
    #if DEBUG
    if marketingDate != nil { return 0 }
    #endif
    return MarketData.delay
  }

  private static let proxyDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    return decoder
  }()

  /// Calls your quote proxy, which answers in the app's own types.
  private static func proxied<T: Decodable>(_ type: T.Type, _ base: URL, _ path: String, _ query: [String: String]) async throws -> T {
    var components = URLComponents(url: base.appending(path: path), resolvingAgainstBaseURL: false)!
    components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
    let (data, response) = try await session.data(from: components.url!)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw QuoteError.noData }
    return try proxyDecoder.decode(T.self, from: data)
  }

  private func yahooQuote(for symbol: String, fiveYears: Bool) async throws -> Quote {
    var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")!
    components.queryItems = [
      URLQueryItem(name: "range", value: fiveYears ? "5y" : "1y"),
      URLQueryItem(name: "interval", value: fiveYears ? "1wk" : "1d"),
      URLQueryItem(name: "events", value: "div"),
    ]
    let (data, _) = try await Self.session.data(from: components.url!)
    let response = try JSONDecoder().decode(ChartResponse.self, from: data)
    guard let result = response.chart.result?.first else { throw QuoteError.noData }

    let meta = result.meta
    let rawCloses = result.indicators.quote.first?.close ?? []
    let timestamps = result.timestamp ?? []
    let rawOpens = result.indicators.quote.first?.open ?? []
    let rawVolumes = result.indicators.quote.first?.volume ?? []
    var closes: [Double] = []
    var dates: [Date] = []
    var opens: [Double] = []
    var volumes: [Double] = []
    for (index, close) in rawCloses.enumerated() {
      guard let close, index < timestamps.count else { continue }
      closes.append(close)
      dates.append(Date(timeIntervalSince1970: TimeInterval(timestamps[index])))
      opens.append((index < rawOpens.count ? rawOpens[index] : nil) ?? close)
      volumes.append((index < rawVolumes.count ? rawVolumes[index] : nil) ?? 0)
    }

    #if DEBUG
    // App Store screenshots: every capture shows the market as it closed on one chosen day.
    if let day = Self.marketingDate, let end = dates.lastIndex(where: { $0 < day }) {
      closes = Array(closes[...end])
      dates = Array(dates[...end])
      opens = Array(opens[...end])
      volumes = Array(volumes[...end])
    }
    #endif

    // London listings quote in pence; normalise to pounds.
    let isPence = meta.currency == "GBp" || meta.currency == "GBX"
    let scale = isPence ? 0.01 : 1
    var price = (meta.regularMarketPrice ?? closes.last ?? 0) * scale
    #if DEBUG
    if Self.marketingDate != nil, let last = closes.last { price = last }
    #endif
    closes = closes.map { $0 * scale }
    opens = opens.map { $0 * scale }
    guard price > 0 || !closes.isEmpty else { throw QuoteError.noData }
    if price == 0 { price = closes.last ?? 0 }
    if closes.isEmpty {
      closes = [price]
      dates = [.now]
    } else {
      closes[closes.count - 1] = price
    }
    let previous = closes.count >= 2 ? closes[closes.count - 2] : (meta.chartPreviousClose ?? price) * scale

    let dividends = (result.events?.dividends?.values.map { DividendPayment(date: Date(timeIntervalSince1970: TimeInterval($0.date)), amount: $0.amount * scale) } ?? [])
      .sorted { $0.date < $1.date }

    return Quote(
      symbol: meta.symbol,
      name: meta.longName ?? meta.shortName ?? meta.symbol,
      currency: isPence ? "GBP" : (meta.currency ?? "USD"),
      exchange: meta.fullExchangeName ?? meta.exchangeName ?? "",
      assetType: meta.instrumentType ?? "",
      price: price,
      previousClose: previous,
      closes: closes,
      dates: dates,
      dividends: dividends,
      opens: opens,
      volumes: volumes,
      updatedAt: .now
    )
  }

  #if DEBUG
  /// Launch with `-marketingDate 2026-10-13` to freeze quotes at that day's close, so every screenshot matches.
  /// Holds the following midnight in New York, so the given day's own bar is kept.
  static let marketingDate: Date? = {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "-marketingDate"), arguments.indices.contains(index + 1) else { return nil }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.timeZone = TimeZone(identifier: "America/New_York")
    return formatter.date(from: arguments[index + 1]).map { $0.addingTimeInterval(24 * 60 * 60) }
  }()
  #endif

  /// Today's prices in five-minute steps, ending at the free delay for free members.
  func intraday(for symbol: String) async throws -> (values: [Double], dates: [Date]) {
    let delay = Self.effectiveDelay
    if let proxy = MarketData.proxyURL {
      let series = try await Self.proxied(IntradayPayload.self, proxy, "intraday", ["symbol": symbol, "delay": "\(Int(delay))"])
      return (series.values, series.dates)
    }
    let bars = try await yahooIntraday(for: symbol)
    guard delay > 0 else { return bars }
    let cutoff = Date.now.addingTimeInterval(-delay)
    let kept = zip(bars.values, bars.dates).filter { $0.1 <= cutoff }
    guard kept.count > 1 else { throw QuoteError.noData }
    return (kept.map(\.0), kept.map(\.1))
  }

  private func yahooIntraday(for symbol: String) async throws -> (values: [Double], dates: [Date]) {
    var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")!
    components.queryItems = [URLQueryItem(name: "range", value: "1d"), URLQueryItem(name: "interval", value: "5m")]
    let (data, _) = try await Self.session.data(from: components.url!)
    let response = try JSONDecoder().decode(ChartResponse.self, from: data)
    guard let result = response.chart.result?.first else { throw QuoteError.noData }
    let scale = result.meta.currency == "GBp" || result.meta.currency == "GBX" ? 0.01 : 1
    let closes = result.indicators.quote.first?.close ?? []
    let timestamps = result.timestamp ?? []
    var values: [Double] = []
    var dates: [Date] = []
    for (index, close) in closes.enumerated() where index < timestamps.count {
      guard let close else { continue }
      values.append(close * scale)
      dates.append(Date(timeIntervalSince1970: TimeInterval(timestamps[index])))
    }
    guard values.count > 1 else { throw QuoteError.noData }
    return (values, dates)
  }

  /// Fetches several quotes concurrently, skipping any that fail.
  func quotes(for symbols: [String]) async -> [String: Quote] {
    await withTaskGroup(of: Quote?.self) { group in
      for symbol in Set(symbols) {
        group.addTask { try? await quote(for: symbol) }
      }
      var results: [String: Quote] = [:]
      for await quote in group {
        if let quote { results[quote.symbol] = quote }
      }
      return results
    }
  }

  /// How many units of `target` one unit of `source` buys.
  func exchangeRate(from source: String, to target: String) async -> Double? {
    guard source != target else { return 1 }
    if let proxy = MarketData.proxyURL {
      return try? await Self.proxied(RatePayload.self, proxy, "fx", ["from": source, "to": target]).rate
    }
    return try? await yahooQuote(for: "\(source)\(target)=X", fiveYears: false).price
  }

  func search(_ text: String) async throws -> [SymbolMatch] {
    if let proxy = MarketData.proxyURL {
      return try await Self.proxied([SymbolMatch].self, proxy, "search", ["q": text])
    }
    var components = URLComponents(string: "https://query1.finance.yahoo.com/v1/finance/search")!
    components.queryItems = [
      URLQueryItem(name: "q", value: text),
      URLQueryItem(name: "quotesCount", value: "12"),
      URLQueryItem(name: "newsCount", value: "0"),
    ]
    let (data, _) = try await Self.session.data(from: components.url!)
    let response = try JSONDecoder().decode(SearchResponse.self, from: data)
    let supported: Set<String> = ["EQUITY", "ETF", "CRYPTOCURRENCY", "INDEX", "MUTUALFUND"]
    return response.quotes
      .filter { supported.contains($0.quoteType ?? "") }
      .map { SymbolMatch(symbol: $0.symbol, name: $0.longname ?? $0.shortname ?? $0.symbol, exchange: $0.exchDisp ?? "", type: $0.typeDisp ?? "") }
  }
}

private struct IntradayPayload: Decodable {
  var values: [Double]
  var dates: [Date]
}

private struct RatePayload: Decodable {
  var rate: Double
}

struct SymbolMatch: Identifiable, Hashable, Codable {
  var id: String { symbol }
  var symbol: String
  var name: String
  var exchange: String
  var type: String
}

private struct ChartResponse: Decodable {
  struct Chart: Decodable {
    var result: [Result]?
  }
  struct Result: Decodable {
    var meta: Meta
    var timestamp: [Int]?
    var indicators: Indicators
    var events: Events?
  }
  struct Meta: Decodable {
    var symbol: String
    var currency: String?
    var regularMarketPrice: Double?
    var chartPreviousClose: Double?
    var longName: String?
    var shortName: String?
    var fullExchangeName: String?
    var exchangeName: String?
    var instrumentType: String?
  }
  struct Indicators: Decodable {
    var quote: [QuoteSeries]
  }
  struct QuoteSeries: Decodable {
    var close: [Double?]?
    var open: [Double?]?
    var volume: [Double?]?
  }
  struct Events: Decodable {
    var dividends: [String: Dividend]?
  }
  struct Dividend: Decodable {
    var amount: Double
    var date: Int
  }
  var chart: Chart
}

private struct SearchResponse: Decodable {
  struct Item: Decodable {
    var symbol: String
    var shortname: String?
    var longname: String?
    var exchDisp: String?
    var quoteType: String?
    var typeDisp: String?
  }
  var quotes: [Item]
}
