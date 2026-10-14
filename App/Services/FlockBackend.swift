import CloudKit
import Foundation

/// Where anonymous flock alerts and votes are stored and read from.
protocol FlockBackend: Sendable {
  var isSample: Bool { get }
  func entries(for symbol: String, near price: Double) async throws -> [FlockEntry]
  func recentEntries(days: Int) async throws -> [(symbol: String, entry: FlockEntry)]
  func votes(for symbol: String?, week: String) async throws -> FlockVotes
  func related(to symbol: String, watchers: [String]) async throws -> [RelatedSymbol]
  func publish(symbol: String, rule: AlertRule, priceAtCreation: Double, installID: String) async throws -> String
  func withdraw(recordName: String) async throws
  func markTriggered(recordName: String, price: Double) async throws
  func vote(symbol: String, bullish: Bool, week: String, installID: String) async throws
}

enum FlockConfiguration {
  /// The iCloud container for flock data. Set this (and the matching iCloud entitlement) once the app has a permanent bundle ID.
  static let containerID: String? = nil

  static func makeBackend() -> FlockBackend? {
    if let containerID {
      return CloudKitFlockBackend(containerID: containerID)
    }
    #if DEBUG
    // `-hideFlock` matches App Store builds, for screenshot captures.
    if ProcessInfo.processInfo.arguments.contains("-hideFlock") { return nil }
    return SampleFlockBackend()
    #else
    return nil
    #endif
  }

  /// A random, anonymous identifier for this install, used only to count unique investors.
  static var installID: String {
    let key = "flockInstallID"
    if let existing = UserDefaults.standard.string(forKey: key) { return existing }
    let id = UUID().uuidString
    UserDefaults.standard.set(id, forKey: key)
    return id
  }
}

/// Stores shared alerts and votes as anonymous records in the CloudKit public database.
struct CloudKitFlockBackend: FlockBackend {
  private static let alertType = "FlockAlert"
  private static let voteType = "FlockVote"
  let containerID: String

  var isSample: Bool { false }
  private var database: CKDatabase { CKContainer(identifier: containerID).publicCloudDatabase }

  private func records(_ predicate: NSPredicate, type: String = alertType, sortedByDate: Bool = false) async throws -> [CKRecord] {
    let query = CKQuery(recordType: type, predicate: predicate)
    if sortedByDate { query.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)] }
    let (results, _) = try await database.records(matching: query, resultsLimit: 1000)
    return results.compactMap { try? $0.1.get() }
  }

  private func entry(from record: CKRecord) -> FlockEntry? {
    guard let kindRaw = record["kind"] as? String, let kind = AlertKind(rawValue: kindRaw) else { return nil }
    return FlockEntry(
      kind: kind,
      lower: record["lower"] as? Double ?? 0,
      upper: record["upper"] as? Double ?? 0,
      percent: record["percent"] as? Double ?? 0,
      createdAt: record["createdAt"] as? Date ?? record.creationDate ?? .now,
      triggeredAt: record["triggeredAt"] as? Date,
      triggeredPrice: record["triggeredPrice"] as? Double,
      installID: record["installID"] as? String ?? record.recordID.recordName,
      isActive: (record["active"] as? Int ?? 1) == 1
    )
  }

  func entries(for symbol: String, near price: Double) async throws -> [FlockEntry] {
    try await records(NSPredicate(format: "symbol == %@", symbol)).compactMap(entry(from:))
  }

  func recentEntries(days: Int) async throws -> [(symbol: String, entry: FlockEntry)] {
    let since = Date.now.addingTimeInterval(-Double(days) * 24 * 3600) as NSDate
    return try await records(NSPredicate(format: "createdAt > %@", since), sortedByDate: true).compactMap { record in
      guard let symbol = record["symbol"] as? String, let entry = entry(from: record) else { return nil }
      return (symbol, entry)
    }
  }

  func votes(for symbol: String?, week: String) async throws -> FlockVotes {
    let predicate = symbol.map { NSPredicate(format: "symbol == %@ AND week == %@", $0, week) } ?? NSPredicate(format: "week == %@", week)
    let votes = try await records(predicate, type: Self.voteType)
    let bullish = votes.filter { ($0["bullish"] as? Int ?? 0) == 1 }.count
    return FlockVotes(bullish: bullish, bearish: votes.count - bullish)
  }

  func related(to symbol: String, watchers: [String]) async throws -> [RelatedSymbol] {
    let sample = Array(watchers.prefix(100))
    guard !sample.isEmpty else { return [] }
    let others = try await records(NSPredicate(format: "installID IN %@ AND active == 1", sample))
    var watchersBySymbol: [String: Set<String>] = [:]
    for record in others {
      guard let other = record["symbol"] as? String, other != symbol, let install = record["installID"] as? String else { continue }
      watchersBySymbol[other, default: []].insert(install)
    }
    return watchersBySymbol
      .map { RelatedSymbol(symbol: $0.key, overlap: Double($0.value.count) / Double(sample.count)) }
      .sorted { $0.overlap > $1.overlap }
      .prefix(8)
      .map { $0 }
  }

  func publish(symbol: String, rule: AlertRule, priceAtCreation: Double, installID: String) async throws -> String {
    let record = CKRecord(recordType: Self.alertType)
    record["symbol"] = symbol
    record["kind"] = rule.kind.rawValue
    record["lower"] = rule.lower
    record["upper"] = rule.upper
    record["percent"] = rule.percent
    record["priceAtCreation"] = priceAtCreation
    record["createdAt"] = Date.now
    record["active"] = 1
    record["installID"] = installID
    return try await database.save(record).recordID.recordName
  }

  func withdraw(recordName: String) async throws {
    try await database.deleteRecord(withID: CKRecord.ID(recordName: recordName))
  }

  func markTriggered(recordName: String, price: Double) async throws {
    let record = try await database.record(for: CKRecord.ID(recordName: recordName))
    record["triggeredAt"] = Date.now
    record["triggeredPrice"] = price
    record["active"] = 0
    _ = try await database.save(record)
  }

  func vote(symbol: String, bullish: Bool, week: String, installID: String) async throws {
    let id = CKRecord.ID(recordName: "vote-\(installID)-\(symbol)-\(week)")
    let record = (try? await database.record(for: id)) ?? CKRecord(recordType: Self.voteType, recordID: id)
    record["symbol"] = symbol
    record["week"] = week
    record["bullish"] = bullish ? 1 : 0
    record["installID"] = installID
    _ = try await database.save(record)
  }
}
