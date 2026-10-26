import Foundation

/// One member's portfolio as the flock sees it: which stocks, and what share of the portfolio each one is.
/// Never amounts, share counts, prices paid, or anything that identifies the person.
struct FlockPortfolio: Hashable, Sendable {
  struct Position: Hashable, Sendable {
    var symbol: String
    /// Share of the portfolio's value, 0–1.
    var weight: Double
  }

  var installID: String
  var positions: [Position]
  /// How today's holdings performed over the last 12 months.
  var yearReturn: Double?
  /// Annualized volatility of today's holdings, for the risk score.
  var volatility: Double?
  var updatedAt: Date

  var nickname: String { FlockInvestor.nickname(for: installID) }

  func weight(of symbol: String) -> Double? {
    positions.first { $0.symbol == symbol }?.weight
  }
}

/// A member adding to or trimming a position.
struct FlockMove: Hashable, Sendable, Identifiable {
  var installID: String
  var symbol: String
  var isBuy: Bool
  var date: Date

  var id: String { "\(installID)-\(symbol)-\(date.timeIntervalSince1970)" }
}

/// How much of the flock owns a stock, and how big a part of their portfolios it is.
struct OwnershipStat: Identifiable, Hashable {
  var symbol: String
  var holders: Int
  /// Share of all sharing members who own it, 0–1.
  var share: Double
  var averageWeight: Double

  var id: String { symbol }
}

/// Who added and who trimmed a stock over the last week.
struct FlowStat: Identifiable, Hashable {
  var symbol: String
  var buyers: Int
  var sellers: Int

  var id: String { symbol }
  var total: Int { buyers + sellers }
  var buyShare: Double { total == 0 ? 0.5 : Double(buyers) / Double(total) }
}

/// A member with a strong track record, shown anonymously.
struct FlockInvestor: Identifiable, Hashable {
  var portfolio: FlockPortfolio
  var moves: [FlockMove]

  var id: String { portfolio.installID }
  var nickname: String { portfolio.nickname }
  var yearReturn: Double { portfolio.yearReturn ?? 0 }

  /// 1 (steady) to 7 (wild), from how much today's holdings swing.
  var riskScore: Int {
    guard let volatility = portfolio.volatility else { return 4 }
    let steps: [Double] = [0.10, 0.15, 0.20, 0.25, 0.30, 0.40]
    return (steps.firstIndex { volatility < $0 } ?? steps.count) + 1
  }

  /// A friendly, stable name like "Owl 4821" that never reveals who it is.
  static func nickname(for installID: String) -> String {
    var hash: UInt64 = 5381
    for byte in installID.utf8 { hash = (hash &* 33) &+ UInt64(byte) }
    return "Owl \(1000 + hash % 9000)"
  }

  /// A stable hue for the member's owl, so the same investor always looks the same.
  var hue: Double { Self.hue(for: portfolio.installID) }

  static func hue(for installID: String) -> Double {
    var hash: UInt64 = 14695981039346656037
    for byte in installID.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
    return Double(hash % 360) / 360
  }
}

/// What the flock did the last times a stock dipped, and how those dips turned out.
struct DipBehavior: Hashable {
  /// Drops of 8% or more from a recent high in the last year.
  var dips: Int
  /// Of members who moved within a week of a dip, the share who bought.
  var boughtShare: Double
  var movers: Int
  /// The stock's average move in the month after each dip.
  var averageRebound: Double?
}

/// Turns anonymous portfolios and moves into the flock's insights. Pure functions, so they're easy to trust.
enum FlockInsights {
  static let minimumHoldings = 3
  /// Sharing members needed before ownership and buying-and-selling appear.
  static let minimumMembers = 20
  /// Members behind any single number, so no one can be singled out.
  static let minimumGroup = 5
  /// Sharing members needed before Top Investors appears, so a top ten means something.
  static let minimumMembersForLeaders = 50

  static func ownership(_ portfolios: [FlockPortfolio]) -> [OwnershipStat] {
    guard !portfolios.isEmpty else { return [] }
    var weights: [String: [Double]] = [:]
    for portfolio in portfolios {
      for position in portfolio.positions { weights[position.symbol, default: []].append(position.weight) }
    }
    return weights.map { symbol, values in
      OwnershipStat(symbol: symbol, holders: values.count, share: Double(values.count) / Double(portfolios.count),
                    averageWeight: values.reduce(0, +) / Double(values.count))
    }
    .sorted { $0.holders == $1.holders ? $0.averageWeight > $1.averageWeight : $0.holders > $1.holders }
  }

  static func flows(_ moves: [FlockMove], days: Int = 7, now: Date = .now) -> [FlowStat] {
    let since = now.addingTimeInterval(-Double(days) * 24 * 3600)
    let recent = moves.filter { $0.date >= since && $0.date <= now }
    return Dictionary(grouping: recent, by: \.symbol).map { symbol, items in
      FlowStat(symbol: symbol,
               buyers: Set(items.filter(\.isBuy).map(\.installID)).count,
               sellers: Set(items.filter { !$0.isBuy }.map(\.installID)).count)
    }
    .filter { $0.total >= 3 }
    .sorted { $0.total > $1.total }
  }

  /// Members with enough holdings and a known 12-month result, best first.
  static func leaders(_ portfolios: [FlockPortfolio], moves: [FlockMove], limit: Int = 20) -> [FlockInvestor] {
    let movesByMember = Dictionary(grouping: moves, by: \.installID)
    return portfolios
      .filter { $0.positions.count >= minimumHoldings && $0.yearReturn != nil }
      .sorted { ($0.yearReturn ?? 0) > ($1.yearReturn ?? 0) }
      .prefix(limit)
      .map { FlockInvestor(portfolio: $0, moves: (movesByMember[$0.installID] ?? []).sorted { $0.date > $1.date }) }
  }

  /// Finds the stock's dips in its price history and what the flock did around each one.
  static func dipBehavior(symbol: String, closes: [Double], dates: [Date], moves: [FlockMove]) -> DipBehavior? {
    guard closes.count == dates.count, closes.count > 40 else { return nil }
    var dipStarts: [Int] = []
    var index = 20
    while index < closes.count {
      let high = closes[(index - 20)..<index].max() ?? closes[index]
      if high > 0, closes[index] / high - 1 <= -0.08 {
        dipStarts.append(index)
        index += 15
      } else {
        index += 1
      }
    }
    guard !dipStarts.isEmpty else { return DipBehavior(dips: 0, boughtShare: 0.5, movers: 0, averageRebound: nil) }
    let symbolMoves = moves.filter { $0.symbol == symbol }
    var buyers = Set<String>()
    var sellers = Set<String>()
    var rebounds: [Double] = []
    for start in dipStarts {
      let from = dates[start]
      let to = from.addingTimeInterval(7 * 24 * 3600)
      for move in symbolMoves where move.date >= from && move.date <= to {
        if move.isBuy { buyers.insert(move.installID + "\(start)") } else { sellers.insert(move.installID + "\(start)") }
      }
      let later = start + 21
      if later < closes.count, closes[start] > 0 { rebounds.append(closes[later] / closes[start] - 1) }
    }
    let movers = buyers.count + sellers.count
    return DipBehavior(
      dips: dipStarts.count,
      boughtShare: movers == 0 ? 0.5 : Double(buyers.count) / Double(movers),
      movers: movers,
      averageRebound: rebounds.isEmpty ? nil : rebounds.reduce(0, +) / Double(rebounds.count)
    )
  }

  /// The user's own portfolio, ready to share: weights, the 12-month result of today's holdings, and their volatility.
  static func snapshot(installID: String, holdings: [(symbol: String, shares: Double)], quotes: [String: Quote]) -> FlockPortfolio? {
    let values = holdings.compactMap { holding -> (String, Double, Quote)? in
      guard holding.shares > 0, let quote = quotes[holding.symbol], quote.price > 0 else { return nil }
      return (holding.symbol, holding.shares * quote.price, quote)
    }
    let total = values.reduce(0) { $0 + $1.1 }
    guard total > 0 else { return nil }
    let positions = values.map { FlockPortfolio.Position(symbol: $0.0, weight: $0.1 / total) }.sorted { $0.weight > $1.weight }

    // Weighted 12-month return of today's holdings.
    var yearReturn = 0.0
    var covered = 0.0
    for (_, value, quote) in values {
      guard let first = quote.closes.first, first > 0, quote.closes.count > 200 else { continue }
      let weight = value / total
      yearReturn += weight * (quote.price / first - 1)
      covered += weight
    }

    // Annualized volatility of the weighted daily returns over the last 60 sessions.
    let sessions = 60
    var daily = [Double](repeating: 0, count: sessions)
    var volatilityCovered = 0.0
    for (_, value, quote) in values {
      let closes = Array(quote.closes.suffix(sessions + 1))
      guard closes.count == sessions + 1 else { continue }
      let weight = value / total
      volatilityCovered += weight
      for day in 0..<sessions where closes[day] > 0 {
        daily[day] += weight * (closes[day + 1] / closes[day] - 1)
      }
    }
    let mean = daily.reduce(0, +) / Double(sessions)
    let variance = daily.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(sessions - 1)

    return FlockPortfolio(
      installID: installID,
      positions: positions,
      yearReturn: covered >= 0.6 ? yearReturn / covered : nil,
      volatility: volatilityCovered >= 0.6 ? (variance.squareRoot() * (252.0).squareRoot()) / volatilityCovered : nil,
      updatedAt: .now
    )
  }
}
