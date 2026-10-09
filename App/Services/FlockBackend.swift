import CloudKit
import Foundation

/// Where anonymous flock alerts are stored and read from.
protocol FlockBackend: Sendable {
  var isSample: Bool { get }
  func targets(for symbol: String) async throws -> (buy: [Double], sell: [Double])
  func trending() async throws -> [TrendingSymbol]
  func publish(symbol: String, kind: TargetKind, target: Double, priceAtCreation: Double) async throws -> String
  func withdraw(recordName: String) async throws
}

enum FlockConfiguration {
  /// The iCloud container for flock data. Set this (and the matching iCloud entitlement) once the app has a permanent bundle ID.
  static let containerID: String? = nil

  static func makeBackend() -> FlockBackend? {
    if let containerID {
      return CloudKitFlockBackend(containerID: containerID)
    }
    #if DEBUG
    return SampleFlockBackend()
    #else
    return nil
    #endif
  }
}

/// Stores each shared alert as an anonymous record in the CloudKit public database.
struct CloudKitFlockBackend: FlockBackend {
  private static let recordType = "FlockAlert"
  let containerID: String

  var isSample: Bool { false }
  private var database: CKDatabase { CKContainer(identifier: containerID).publicCloudDatabase }

  func targets(for symbol: String) async throws -> (buy: [Double], sell: [Double]) {
    let predicate = NSPredicate(format: "symbol == %@ AND active == 1", symbol)
    let query = CKQuery(recordType: Self.recordType, predicate: predicate)
    let (results, _) = try await database.records(matching: query, desiredKeys: ["kind", "target"], resultsLimit: 1000)
    var buy: [Double] = []
    var sell: [Double] = []
    for case .success(let record) in results.map(\.1) {
      guard let target = record["target"] as? Double else { continue }
      if record["kind"] as? String == TargetKind.sellAbove.rawValue { sell.append(target) } else { buy.append(target) }
    }
    return (buy, sell)
  }

  func trending() async throws -> [TrendingSymbol] {
    let since = Date.now.addingTimeInterval(-7 * 24 * 3600) as NSDate
    let query = CKQuery(recordType: Self.recordType, predicate: NSPredicate(format: "createdAt > %@", since))
    query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
    let (results, _) = try await database.records(matching: query, desiredKeys: ["symbol", "kind"], resultsLimit: 1000)
    var counts: [String: (total: Int, buy: Int)] = [:]
    for case .success(let record) in results.map(\.1) {
      guard let symbol = record["symbol"] as? String else { continue }
      let isBuy = record["kind"] as? String != TargetKind.sellAbove.rawValue
      counts[symbol, default: (0, 0)].total += 1
      if isBuy { counts[symbol, default: (0, 0)].buy += 1 }
    }
    return counts
      .map { TrendingSymbol(symbol: $0.key, newAlerts: $0.value.total, buyShare: Double($0.value.buy) / Double($0.value.total)) }
      .sorted { $0.newAlerts > $1.newAlerts }
      .prefix(10)
      .map { $0 }
  }

  func publish(symbol: String, kind: TargetKind, target: Double, priceAtCreation: Double) async throws -> String {
    let record = CKRecord(recordType: Self.recordType)
    record["symbol"] = symbol
    record["kind"] = kind.rawValue
    record["target"] = target
    record["priceAtCreation"] = priceAtCreation
    record["createdAt"] = Date.now
    record["active"] = 1
    return try await database.save(record).recordID.recordName
  }

  func withdraw(recordName: String) async throws {
    try await database.deleteRecord(withID: CKRecord.ID(recordName: recordName))
  }
}

#if DEBUG
/// Deterministic sample data so the flock screens can be designed before CloudKit is connected.
struct SampleFlockBackend: FlockBackend {
  var isSample: Bool { true }

  func targets(for symbol: String) async throws -> (buy: [Double], sell: [Double]) {
    var generator = SeededGenerator(seed: symbol)
    let price = TargetSnapshotStore.loadQuotes()[symbol]?.price ?? 100
    let total = Int.random(in: 40...320, using: &generator)
    let buyShare = Double.random(in: 0.45...0.75, using: &generator)
    let dipCenter = Double.random(in: 0.05...0.12, using: &generator)
    let riseCenter = Double.random(in: 0.08...0.18, using: &generator)
    var buy: [Double] = []
    var sell: [Double] = []
    for _ in 0..<total {
      let spread = (Double.random(in: -1...1, using: &generator) + Double.random(in: -1...1, using: &generator)) * 0.05
      if Double.random(in: 0...1, using: &generator) < buyShare {
        buy.append(price * (1 - max(0.005, dipCenter + spread)))
      } else {
        sell.append(price * (1 + max(0.005, riseCenter + spread)))
      }
    }
    return (buy, sell)
  }

  func trending() async throws -> [TrendingSymbol] {
    [("NVDA", 412, 0.71), ("TSLA", 356, 0.64), ("AAPL", 298, 0.52), ("PLTR", 241, 0.58), ("AMD", 187, 0.69), ("MSFT", 154, 0.47)]
      .map { TrendingSymbol(symbol: $0.0, newAlerts: $0.1, buyShare: $0.2) }
  }

  func publish(symbol: String, kind: TargetKind, target: Double, priceAtCreation: Double) async throws -> String {
    UUID().uuidString
  }

  func withdraw(recordName: String) async throws {}
}

private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64

  init(seed: String) {
    state = seed.utf8.reduce(1469598103934665603) { ($0 ^ UInt64($1)) &* 1099511628211 }
  }

  mutating func next() -> UInt64 {
    state &+= 0x9E3779B97F4A7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
    z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
    return z ^ (z >> 31)
  }
}
#endif
