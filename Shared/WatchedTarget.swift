import Foundation

/// A lightweight copy of an active alert, shared with widgets and Apple Watch.
struct WatchedTarget: Codable, Hashable, Identifiable {
  var id: UUID
  var symbol: String
  var name: String
  var rule: AlertRule
}

/// A followed stock, shared with widgets so they can offer it as a choice.
struct WatchedStock: Codable, Hashable, Identifiable {
  var symbol: String
  var name: String
  /// Shares owned, for the watch's portfolio. Nil or zero when only watched.
  var shares: Double?
  var averageCost: Double?
  var id: String { symbol }

  var isOwned: Bool { (shares ?? 0) > 0 }
}

/// Reads and writes the alert snapshot and cached quotes in the shared App Group.
enum TargetSnapshotStore {
  private static let targetsKey = "watchedTargets.v3"
  private static let quotesKey = "cachedQuotes.v3"
  private static let stocksKey = "watchedStocks.v1"
  private static let baseCurrencyKey = "baseCurrency.v1"
  private static let ratesKey = "exchangeRates.v1"

  /// The currency portfolio totals are shown in, chosen on iPhone.
  static func loadBaseCurrency() -> String {
    AppGroup.defaults.string(forKey: baseCurrencyKey) ?? "USD"
  }

  static func save(baseCurrency: String) {
    AppGroup.defaults.set(baseCurrency, forKey: baseCurrencyKey)
  }

  /// Multipliers from each currency into the base currency.
  static func loadRates() -> [String: Double] {
    (AppGroup.defaults.dictionary(forKey: ratesKey) as? [String: Double]) ?? [:]
  }

  static func save(rates: [String: Double]) {
    AppGroup.defaults.set(rates, forKey: ratesKey)
  }

  static func loadStocks() -> [WatchedStock] {
    guard let data = AppGroup.defaults.data(forKey: stocksKey) else { return [] }
    return (try? JSONDecoder().decode([WatchedStock].self, from: data)) ?? []
  }

  static func save(stocks: [WatchedStock]) {
    AppGroup.defaults.set(try? JSONEncoder().encode(stocks), forKey: stocksKey)
  }

  static func loadTargets() -> [WatchedTarget] {
    guard let data = AppGroup.defaults.data(forKey: targetsKey) else { return [] }
    return (try? JSONDecoder().decode([WatchedTarget].self, from: data)) ?? []
  }

  static func save(targets: [WatchedTarget]) {
    AppGroup.defaults.set(try? JSONEncoder().encode(targets), forKey: targetsKey)
  }

  static func loadQuotes() -> [String: Quote] {
    guard let data = AppGroup.defaults.data(forKey: quotesKey) else { return [:] }
    return (try? JSONDecoder().decode([String: Quote].self, from: data)) ?? [:]
  }

  static func save(quotes: [String: Quote]) {
    AppGroup.defaults.set(try? JSONEncoder().encode(quotes), forKey: quotesKey)
  }
}

/// A target paired with its latest price, sorted closest-first for glanceable surfaces.
struct TargetStatus: Identifiable, Hashable {
  var target: WatchedTarget
  var quote: Quote?

  var id: UUID { target.id }
  var distance: Double? { quote.flatMap { target.rule.distance(for: $0) } }
  var progress: Double { quote.map { target.rule.progress(for: $0) } ?? 0 }

  var summary: String {
    target.rule.summary { value in quote?.formatted(value) ?? value.formatted(.number.precision(.fractionLength(2))) }
  }

  static func sorted(targets: [WatchedTarget], quotes: [String: Quote]) -> [TargetStatus] {
    targets
      .map { TargetStatus(target: $0, quote: quotes[$0.symbol]) }
      .sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
  }
}
