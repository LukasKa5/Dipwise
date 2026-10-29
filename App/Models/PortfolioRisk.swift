import Foundation

/// How risky today's portfolio has been over the past year, from its own daily history: how much it swings, its
/// worst fall and worst day, how much it moves with the market (beta), what a 20% market drop would likely cost, and
/// how concentrated it is. The numbers professional investors check first, in plain language.
struct PortfolioRisk {
  /// Annualized volatility of daily returns.
  var volatility: Double
  /// The deepest fall from a peak over the year, as a negative fraction.
  var maxDrawdown: Double
  /// The worst single day, as a negative fraction.
  var worstDay: Double
  /// How much the portfolio moves for each 1% the benchmark moves, when the benchmark's history is available.
  var beta: Double?
  /// The benchmark's own annualized volatility, for comparison.
  var benchmarkVolatility: Double?
  /// The likely loss if the benchmark fell 20%, in the base currency.
  var crashLoss: Double?
  /// The largest position and its share of the portfolio.
  var largest: (symbol: String, weight: Double)?
  /// The three largest positions' combined share.
  var topThreeWeight: Double

  static func make(summary: PortfolioSummary, benchmark: Quote?) -> PortfolioRisk? {
    let history = summary.history(sessions: 260).values
    guard history.count > 30 else { return nil }
    let returns = dailyReturns(history)
    let positions = summary.positions

    var peak = history[0]
    var maxDrawdown = 0.0
    for value in history {
      peak = max(peak, value)
      if peak > 0 { maxDrawdown = min(maxDrawdown, value / peak - 1) }
    }

    var beta: Double?
    var benchmarkVolatility: Double?
    if let benchmark, benchmark.closes.count > 30 {
      let market = dailyReturns(benchmark.closes)
      let count = min(returns.count, market.count)
      let mine = Array(returns.suffix(count))
      let theirs = Array(market.suffix(count))
      let variance = Self.variance(theirs)
      if variance > 0 {
        beta = covariance(mine, theirs) / variance
        benchmarkVolatility = annualized(theirs)
      }
    }

    let total = summary.totalValue
    return PortfolioRisk(
      volatility: annualized(returns),
      maxDrawdown: maxDrawdown,
      worstDay: returns.min() ?? 0,
      beta: beta,
      benchmarkVolatility: benchmarkVolatility,
      crashLoss: beta.map { total * max(0, $0) * 0.2 },
      largest: positions.first.map { ($0.holding.symbol, $0.weight) },
      topThreeWeight: positions.prefix(3).reduce(0) { $0 + $1.weight }
    )
  }

  /// One sentence on what matters most, the way a good advisor would put it.
  var verdict: String {
    if let largest, largest.weight >= 0.35 {
      return String(localized: "\(largest.symbol) is \(largest.weight.formatted(.percent.precision(.fractionLength(0)))) of your portfolio. One stock decides most of your result, good or bad.")
    }
    if let beta, beta >= 1.25 {
      return String(localized: "Your portfolio moves about \(beta.formatted(.number.precision(.fractionLength(1))))× as much as the market. Expect bigger swings both ways.")
    }
    if let beta, beta <= 0.75 {
      return String(localized: "Your portfolio moves less than the market. Calmer in a sell-off, but it may lag in a rally.")
    }
    return String(localized: "Your risk is close to the market's. Your plans and zones do the rest.")
  }

  private static func dailyReturns(_ values: [Double]) -> [Double] {
    zip(values, values.dropFirst()).compactMap { previous, next in previous > 0 ? next / previous - 1 : nil }
  }

  private static func mean(_ values: [Double]) -> Double {
    values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
  }

  private static func variance(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let average = mean(values)
    return values.reduce(0) { $0 + ($1 - average) * ($1 - average) } / Double(values.count - 1)
  }

  private static func covariance(_ a: [Double], _ b: [Double]) -> Double {
    guard a.count == b.count, a.count > 1 else { return 0 }
    let meanA = mean(a), meanB = mean(b)
    return zip(a, b).reduce(0) { $0 + ($1.0 - meanA) * ($1.1 - meanB) } / Double(a.count - 1)
  }

  private static func annualized(_ returns: [Double]) -> Double {
    variance(returns).squareRoot() * 252.0.squareRoot()
  }
}
