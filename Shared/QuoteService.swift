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

  func quote(for symbol: String, range: ChartRange = .month) async throws -> Quote {
    var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)")!
    components.queryItems = [
      URLQueryItem(name: "range", value: range.rawValue),
      URLQueryItem(name: "interval", value: range.interval),
    ]
    let (data, _) = try await Self.session.data(from: components.url!)
    let response = try JSONDecoder().decode(ChartResponse.self, from: data)
    guard let result = response.chart.result?.first else { throw QuoteError.noData }

    let closes = (result.indicators.quote.first?.close ?? []).compactMap { $0 }
    let meta = result.meta
    let price = meta.regularMarketPrice ?? closes.last ?? 0
    guard price > 0 else { throw QuoteError.noData }
    var series = closes
    if !series.isEmpty { series[series.count - 1] = price } else { series = [price] }
    let previous = series.count >= 2 ? series[series.count - 2] : (meta.chartPreviousClose ?? price)

    return Quote(
      symbol: meta.symbol,
      name: meta.longName ?? meta.shortName ?? meta.symbol,
      currency: meta.currency ?? "USD",
      price: price,
      previousClose: previous,
      closes: series,
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
    var indicators: Indicators
  }
  struct Meta: Decodable {
    var symbol: String
    var currency: String?
    var regularMarketPrice: Double?
    var chartPreviousClose: Double?
    var longName: String?
    var shortName: String?
  }
  struct Indicators: Decodable {
    var quote: [QuoteSeries]
  }
  struct QuoteSeries: Decodable {
    var close: [Double?]?
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
