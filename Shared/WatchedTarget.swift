import Foundation

/// A lightweight copy of an active alert, shared with widgets and Apple Watch.
struct WatchedTarget: Codable, Hashable, Identifiable {
  var id: UUID
  var symbol: String
  var name: String
  var kind: TargetKind
  var target: Double
}

/// Reads and writes the alert snapshot and cached quotes in the shared App Group.
enum TargetSnapshotStore {
  private static let targetsKey = "watchedTargets"
  private static let quotesKey = "cachedQuotes"

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
  var distance: Double? { quote.map { target.kind.distance(from: $0.price, to: target.target) } }
  var progress: Double { quote.map { target.kind.progress(from: $0.price, to: target.target) } ?? 0 }

  static func sorted(targets: [WatchedTarget], quotes: [String: Quote]) -> [TargetStatus] {
    targets
      .map { TargetStatus(target: $0, quote: quotes[$0.symbol]) }
      .sorted { ($0.distance ?? .infinity) < ($1.distance ?? .infinity) }
  }
}
