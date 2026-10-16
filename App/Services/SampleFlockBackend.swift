#if DEBUG
import Foundation

/// Deterministic sample data so the flock screens can be designed before CloudKit is connected.
struct SampleFlockBackend: FlockBackend {
  var isSample: Bool { true }

  static let universe: [(String, Double)] = [
    ("NVDA", 182), ("TSLA", 375), ("AAPL", 247), ("MSFT", 512), ("AMZN", 222), ("META", 712), ("GOOGL", 245),
    ("PLTR", 178), ("AMD", 165), ("ASML", 980), ("NFLX", 1210), ("COIN", 330), ("O", 57), ("KO", 68),
    ("VOO", 610), ("BTC-USD", 121000), ("SHOP", 150), ("UBER", 96),
  ]

  func entries(for symbol: String, near price: Double) async throws -> [FlockEntry] {
    var generator = SeededGenerator(seed: symbol)
    return Self.makeEntries(price: price, generator: &generator)
  }

  func recentEntries(days: Int) async throws -> [(symbol: String, entry: FlockEntry)] {
    var result: [(String, FlockEntry)] = []
    for (symbol, price) in Self.universe {
      var generator = SeededGenerator(seed: symbol)
      let entries = Self.makeEntries(price: price, generator: &generator)
        .filter { Date.now.timeIntervalSince($0.createdAt) < Double(days) * 24 * 3600 }
      result += entries.map { (symbol, $0) }
    }
    return result
  }

  func votes(for symbol: String?, week: String) async throws -> FlockVotes {
    var generator = SeededGenerator(seed: (symbol ?? "all") + week)
    let total = Int.random(in: 80...900, using: &generator)
    let bullish = Int(Double(total) * Double.random(in: 0.35...0.75, using: &generator))
    return FlockVotes(bullish: bullish, bearish: total - bullish)
  }

  func related(to symbol: String, watchers: [String]) async throws -> [RelatedSymbol] {
    var generator = SeededGenerator(seed: symbol + "related")
    let candidates = Self.universe.map(\.0).filter { $0 != symbol }.shuffled(using: &generator).prefix(6)
    var overlap = Double.random(in: 0.45...0.7, using: &generator)
    return candidates.map { candidate in
      defer { overlap *= Double.random(in: 0.7...0.9, using: &generator) }
      return RelatedSymbol(symbol: candidate, overlap: overlap)
    }
  }

  func publish(symbol: String, rule: AlertRule, priceAtCreation: Double, installID: String) async throws -> String {
    UUID().uuidString
  }

  func withdraw(recordName: String) async throws {}
  func markTriggered(recordName: String, price: Double) async throws {}
  func vote(symbol: String, bullish: Bool, week: String, installID: String) async throws {}
  func publish(portfolio: FlockPortfolio) async throws {}
  func publish(move: FlockMove) async throws {}
  func withdrawPortfolio(installID: String) async throws {}

  /// A flock of about 500 members with realistic, overlapping portfolios.
  func portfolios() async throws -> [FlockPortfolio] {
    Self.members.map(\.portfolio)
  }

  func moves(days: Int) async throws -> [FlockMove] {
    let since = Date.now.addingTimeInterval(-Double(days) * 24 * 3600)
    return Self.members.flatMap(\.moves).filter { $0.date >= since }
  }

  private static let members: [(portfolio: FlockPortfolio, moves: [FlockMove])] = {
    var generator = SeededGenerator(seed: "flock-portfolios")
    // How likely each stock is to be in a portfolio: the big names more often.
    let popularity: [String: Double] = [
      "NVDA": 0.62, "AAPL": 0.55, "MSFT": 0.5, "VOO": 0.46, "AMZN": 0.42, "GOOGL": 0.38, "TSLA": 0.36, "META": 0.33,
      "PLTR": 0.24, "AMD": 0.22, "ASML": 0.12, "NFLX": 0.14, "COIN": 0.1, "O": 0.16, "KO": 0.15, "BTC-USD": 0.18,
      "SHOP": 0.08, "UBER": 0.1,
    ]
    let symbols = universe.map(\.0)
    return (0..<520).map { member in
      let installID = "sample-member-\(member)"
      var picked = symbols.filter { Double.random(in: 0...1, using: &generator) < (popularity[$0] ?? 0.1) }
      if picked.count < 2 { picked += ["VOO", "AAPL"].filter { !picked.contains($0) } }
      let raw = picked.map { _ in pow(Double.random(in: 0.05...1, using: &generator), 1.6) }
      let total = raw.reduce(0, +)
      let positions = zip(picked, raw).map { FlockPortfolio.Position(symbol: $0, weight: $1 / total) }.sorted { $0.weight > $1.weight }
      let concentration = positions.first?.weight ?? 0.3
      let skill = Double.random(in: -1...1, using: &generator) + Double.random(in: -1...1, using: &generator)
      let portfolio = FlockPortfolio(
        installID: installID,
        positions: positions,
        yearReturn: 0.11 + skill * 0.13 + concentration * Double.random(in: -0.1...0.35, using: &generator),
        volatility: 0.12 + concentration * 0.35 + Double.random(in: 0...0.12, using: &generator),
        updatedAt: .now.addingTimeInterval(-Double.random(in: 0...5, using: &generator) * 24 * 3600)
      )
      // About two moves a month, a little more often buying than selling, as long-term investors do.
      let moveCount = Int.random(in: 4...30, using: &generator)
      let moves = (0..<moveCount).map { _ in
        let symbol = picked.randomElement(using: &generator) ?? "VOO"
        let age = pow(Double.random(in: 0...1, using: &generator), 1.3) * 365 * 24 * 3600
        return FlockMove(installID: installID, symbol: symbol, isBuy: Double.random(in: 0...1, using: &generator) < 0.64,
                         date: .now.addingTimeInterval(-age))
      }
      return (portfolio, moves)
    }
  }()

  private static func makeEntries(price: Double, generator: inout SeededGenerator) -> [FlockEntry] {
    let count = Int.random(in: 60...420, using: &generator)
    let investors = max(5, Int(Double(count) * 0.7))
    let dipCenter = Double.random(in: 0.03...0.12, using: &generator)
    // Alerts were set at earlier prices, so recent moves can carry a stock into the crowd's zone.
    let reference = price * (1 + Double.random(in: -0.04...0.10, using: &generator))
    let riseCenter = Double.random(in: 0.08...0.2, using: &generator)
    let buyBias = Double.random(in: 0.45...0.75, using: &generator)
    let kinds: [(AlertKind, Double)] = [
      (.buyZone, 0.30), (.priceBelow, 0.18), (.sellZone, 0.15), (.priceAbove, 0.10),
      (.dropFromHigh, 0.09), (.trailingStop, 0.07), (.dailyMove, 0.06), (.belowAverage, 0.05),
    ]
    var entries: [FlockEntry] = []
    for _ in 0..<count {
      var roll = Double.random(in: 0...1, using: &generator)
      var kind = AlertKind.buyZone
      for (candidate, weight) in kinds {
        roll -= weight
        if roll <= 0 { kind = candidate; break }
      }
      if kind.side == .sell, Double.random(in: 0...1, using: &generator) < buyBias - 0.4 { kind = .buyZone }

      let spread = (Double.random(in: -1...1, using: &generator) + Double.random(in: -1...1, using: &generator)) * 0.045
      let width = Double.random(in: 0.02...0.06, using: &generator)
      var lower = 0.0, upper = 0.0, percent = 0.0
      switch kind.side {
      case .buy:
        let center = reference * (1 - max(0.004, dipCenter + spread))
        lower = kind.isZone ? center * (1 - width / 2) : center
        upper = kind.isZone ? center * (1 + width / 2) : 0
      case .sell:
        let center = reference * (1 + max(0.004, riseCenter + spread))
        lower = kind.isZone ? center * (1 - width / 2) : center
        upper = kind.isZone ? center * (1 + width / 2) : 0
      case .watch:
        break
      }
      if kind.usesPercent { percent = [0.05, 0.08, 0.1, 0.15, 0.2].randomElement(using: &generator) ?? 0.1 }

      let age = pow(Double.random(in: 0...1, using: &generator), 1.6) * 60 * 24 * 3600
      let createdAt = Date.now.addingTimeInterval(-age)
      var triggeredAt: Date?
      var triggeredPrice: Double?
      if kind.side == .buy, age > 3 * 24 * 3600, Double.random(in: 0...1, using: &generator) < 0.3 {
        triggeredAt = createdAt.addingTimeInterval(age * Double.random(in: 0.2...0.9, using: &generator))
        triggeredPrice = (kind.isZone ? upper : (lower > 0 ? lower : price * 0.9)) * Double.random(in: 0.92...1.0, using: &generator)
      }
      entries.append(FlockEntry(
        kind: kind, lower: lower, upper: upper, percent: percent, createdAt: createdAt,
        triggeredAt: triggeredAt, triggeredPrice: triggeredPrice,
        installID: "sample-\(Int.random(in: 0..<investors, using: &generator))",
        isActive: triggeredAt == nil
      ))
    }
    return entries
  }
}

struct SeededGenerator: RandomNumberGenerator {
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
