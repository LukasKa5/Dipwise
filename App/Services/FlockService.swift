import Foundation
import Observation

/// Loads anonymous flock statistics and shares the user's own alerts when they opt in.
@MainActor
@Observable
final class FlockService {
  private let backend = FlockConfiguration.makeBackend()
  private(set) var stats: [String: FlockStats] = [:]
  private(set) var trending: [TrendingSymbol] = []
  private(set) var loadingSymbols: Set<String> = []

  var isAvailable: Bool { backend != nil }
  var isSample: Bool { backend?.isSample ?? false }

  func load(symbol: String, currentPrice: Double) async {
    guard let backend, currentPrice > 0, !loadingSymbols.contains(symbol) else { return }
    loadingSymbols.insert(symbol)
    defer { loadingSymbols.remove(symbol) }
    if let targets = try? await backend.targets(for: symbol) {
      stats[symbol] = FlockStats(symbol: symbol, currentPrice: currentPrice, buyTargets: targets.buy, sellTargets: targets.sell, isSample: backend.isSample)
    }
  }

  func loadTrending() async {
    guard let backend else { return }
    if let result = try? await backend.trending() {
      trending = result
    }
  }

  func share(_ alert: PriceAlert) async {
    guard let backend, AlertSettings.shareWithFlock, alert.flockRecordName == nil else { return }
    alert.flockRecordName = try? await backend.publish(
      symbol: alert.symbol, kind: alert.kind, target: alert.targetPrice, priceAtCreation: alert.priceAtCreation
    )
  }

  func withdraw(_ alert: PriceAlert) async {
    guard let backend, let recordName = alert.flockRecordName else { return }
    try? await backend.withdraw(recordName: recordName)
    alert.flockRecordName = nil
  }
}
