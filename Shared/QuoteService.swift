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

  /// One year of daily data (or five years of weekly data) with dividends.
  func quote(for symbol: String, fiveYears: Bool = false) async throws -> Quote {
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
    var closes: [Double] = []
    var dates: [Date] = []
    for (index, close) in rawCloses.enumerated() {
      guard let close, index < timestamps.count else { continue }
      closes.append(close)
      dates.append(Date(timeIntervalSince1970: TimeInterval(timestamps[index])))
    }

    // London listings quote in pence; normalise to pounds.
    let isPence = meta.currency == "GBp" || meta.currency == "GBX"
    let scale = isPence ? 0.01 : 1
    var price = (meta.regularMarketPrice ?? closes.last ?? 0) * scale
    closes = closes.map { $0 * scale }
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
      updatedAt: .now
    )
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
    return try? await quote(for: "\(source)\(target)=X").price
  }

  func search(_ text: String) async throws -> [SymbolMatch] {
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

struct SymbolMatch: Identifiable, Hashable {
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
