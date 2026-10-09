import Foundation

/// Aggregated, anonymous alert levels other Dipwise users have set for one symbol.
struct FlockStats: Equatable {
  struct Bin: Identifiable, Equatable {
    /// Lower edge of the bin, as a fraction away from the current price (e.g. -0.10).
    var lowerOffset: Double
    var buyCount: Int
    var sellCount: Int

    var id: Double { lowerOffset }
    var midOffset: Double { lowerOffset + FlockStats.binWidth / 2 }
    var total: Int { buyCount + sellCount }
  }

  static let binWidth = 0.025
  static let offsetRange = -0.30...0.30
  /// Below this many alerts, statistics would be misleading and could identify individuals.
  static let minimumSample = 5

  var symbol: String
  var currentPrice: Double
  var buyTargets: [Double]
  var sellTargets: [Double]
  var isSample = false

  var watcherCount: Int { buyTargets.count + sellTargets.count }
  var hasEnoughData: Bool { watcherCount >= Self.minimumSample }
  var buyShare: Double { watcherCount == 0 ? 0 : Double(buyTargets.count) / Double(watcherCount) }

  var medianBuy: Double? { Self.median(buyTargets) }
  var medianSell: Double? { Self.median(sellTargets) }

  var bins: [Bin] {
    let lower = Self.offsetRange.lowerBound
    let count = Int(((Self.offsetRange.upperBound - lower) / Self.binWidth).rounded())
    var bins = (0..<count).map { Bin(lowerOffset: lower + Double($0) * Self.binWidth, buyCount: 0, sellCount: 0) }
    func index(for target: Double) -> Int? {
      guard currentPrice > 0 else { return nil }
      let offset = target / currentPrice - 1
      guard Self.offsetRange.contains(offset) else { return nil }
      return min(count - 1, Int((offset - lower) / Self.binWidth))
    }
    for target in buyTargets { if let i = index(for: target) { bins[i].buyCount += 1 } }
    for target in sellTargets { if let i = index(for: target) { bins[i].sellCount += 1 } }
    return bins
  }

  /// The price level where the most alerts cluster.
  var crowdedLevel: Double? {
    guard let bin = bins.max(by: { $0.total < $1.total }), bin.total > 0 else { return nil }
    return currentPrice * (1 + bin.midOffset)
  }

  /// How many alerts sit within `band` of the current price.
  func alertsNearPrice(band: Double = 0.05) -> Int {
    (buyTargets + sellTargets).filter { abs($0 / currentPrice - 1) <= band }.count
  }

  /// Share of same-side targets that are less extreme than `target` (how patient the user is).
  func patience(of target: Double, kind: TargetKind) -> Double? {
    let peers = kind == .buyBelow ? buyTargets : sellTargets
    guard peers.count >= Self.minimumSample else { return nil }
    let lessPatient = kind == .buyBelow ? peers.filter { $0 > target }.count : peers.filter { $0 < target }.count
    return Double(lessPatient) / Double(peers.count)
  }

  private static func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let sorted = values.sorted()
    let middle = sorted.count / 2
    return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
  }
}

struct TrendingSymbol: Identifiable, Equatable {
  var symbol: String
  var newAlerts: Int
  var buyShare: Double

  var id: String { symbol }
}
