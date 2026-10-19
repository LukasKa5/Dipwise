import Foundation

/// What a broker learns about you from how you invest, worked out on your own device and shown to you in plain words:
/// your risk score, your style, how concentrated you are, how you behave when alerts fire, and how you compare
/// with the flock.
struct InvestorProfile {
  enum Style: String {
    case dipHunter, dividendBuilder, concentrated, steadyIndexer, growthChaser, balanced

    var title: String {
      switch self {
      case .dipHunter: String(localized: "Patient dip hunter")
      case .dividendBuilder: String(localized: "Dividend builder")
      case .concentrated: String(localized: "High-conviction investor")
      case .steadyIndexer: String(localized: "Steady indexer")
      case .growthChaser: String(localized: "Growth seeker")
      case .balanced: String(localized: "Balanced investor")
      }
    }

    var detail: String {
      switch self {
      case .dipHunter: String(localized: "You plan to buy below today's price and wait for it. Brokers see you as calm and price-aware.")
      case .dividendBuilder: String(localized: "A good part of your return comes as income. Brokers see a long-term, low-turnover investor.")
      case .concentrated: String(localized: "A few positions carry most of your portfolio. Brokers flag this as higher risk: one stock can move everything.")
      case .steadyIndexer: String(localized: "Broad funds make up much of what you own. Brokers see a disciplined, low-risk investor.")
      case .growthChaser: String(localized: "You hold fast-moving stocks. Brokers see a high-risk, high-reward profile.")
      case .balanced: String(localized: "Your money is spread out and your risk is moderate. Brokers see a balanced, long-term investor.")
      }
    }

    var systemImage: String {
      switch self {
      case .dipHunter: "scope"
      case .dividendBuilder: "leaf.fill"
      case .concentrated: "target"
      case .steadyIndexer: "chart.bar.fill"
      case .growthChaser: "bolt.fill"
      case .balanced: "scale.3d"
      }
    }
  }

  /// 1 (steady) to 7 (wild), from how much your holdings swing, like the scores brokers use.
  var riskScore: Int
  /// Annualized volatility of today's holdings.
  var volatility: Double?
  /// How today's holdings did over the last 12 months.
  var yearReturn: Double?
  var style: Style
  var positions: Int
  var largestSymbol: String?
  var largestWeight: Double
  /// How many equally sized positions your portfolio behaves like (1 / Σ weight²).
  var effectiveHoldings: Double
  var fundShare: Double
  var dividendYield: Double
  /// Of your buy alerts that fired and that you logged, the share where you bought.
  var dipBuyRate: Double?
  var loggedDecisions: Int
  /// Of fired buy alerts, the share whose price is higher today.
  var buyHitRate: Double?
  /// Share of watched stocks that have a buy or sell plan.
  var planCoverage: Double
  /// Where your 12-month result ranks in the flock, 0–1 (higher is better). Nil until the flock is large enough.
  var flockReturnPercentile: Double?
  /// Where your risk ranks in the flock, 0–1 (higher is riskier).
  var flockRiskPercentile: Double?

  /// A 0–100 diversification score, from the effective number of holdings.
  var diversificationScore: Int {
    min(100, Int((min(effectiveHoldings, 15) / 15 * 100).rounded()))
  }

  static func make(summary: PortfolioSummary, holdings: [Holding], quotes: [String: Quote], flock: [FlockPortfolio]) -> InvestorProfile? {
    let positions = summary.positions
    guard !positions.isEmpty else { return nil }
    let snapshot = FlockInsights.snapshot(installID: "me", holdings: holdings.map { ($0.symbol, $0.shares) }, quotes: quotes)
    let volatility = snapshot?.volatility
    let steps: [Double] = [0.10, 0.15, 0.20, 0.25, 0.30, 0.40]
    let risk = volatility.map { volatility in (steps.firstIndex { volatility < $0 } ?? steps.count) + 1 } ?? 4

    let weights = positions.map(\.weight)
    let effective = 1 / max(weights.reduce(0) { $0 + $1 * $1 }, 0.0001)
    let fundShare = positions.filter { ["ETF", "MUTUALFUND"].contains($0.quote.assetType.uppercased()) }.reduce(0) { $0 + $1.weight }
    let income = positions.reduce(0) { $0 + $1.annualDividend }
    let dividendYield = summary.totalValue > 0 ? income / summary.totalValue : 0

    // Behavior, from fired buy alerts and the journal.
    let alerts = holdings.flatMap { $0.alerts ?? [] }
    let firedBuys = alerts.filter { $0.triggeredAt != nil && $0.kind.side == .buy }
    let logged = firedBuys.compactMap(\.journalAction)
    let dipBuyRate = logged.count >= 2 ? Double(logged.filter { $0 == .bought }.count) / Double(logged.count) : nil
    let judged = firedBuys.compactMap { alert -> Bool? in
      guard let price = alert.triggeredPrice, price > 0, let quote = quotes[alert.symbol] else { return nil }
      return quote.price > price
    }
    let hitRate = judged.count >= 2 ? Double(judged.filter { $0 }.count) / Double(judged.count) : nil
    let planned = holdings.filter { holding in (holding.alerts ?? []).contains { $0.isActive && $0.kind.isZone } }.count
    let buyPlans = alerts.filter { $0.isActive && $0.kind == .buyZone }.count

    let largest = positions.first
    let style: Style = {
      if (largest?.weight ?? 0) >= 0.4 { return .concentrated }
      if fundShare >= 0.5 { return .steadyIndexer }
      if dividendYield >= 0.025 { return .dividendBuilder }
      if buyPlans >= max(2, holdings.count / 2) || (dipBuyRate ?? 0) >= 0.6 { return .dipHunter }
      if risk >= 6 { return .growthChaser }
      return .balanced
    }()

    // Rankings within the flock, only once there's a real crowd.
    let others = flock.filter { $0.yearReturn != nil && $0.volatility != nil }
    let ranked = others.count >= FlockInsights.minimumMembers
    let returnPercentile = ranked ? snapshot?.yearReturn.map { mine in Double(others.filter { ($0.yearReturn ?? 0) < mine }.count) / Double(others.count) } : nil
    let riskPercentile = ranked ? volatility.map { mine in Double(others.filter { ($0.volatility ?? 0) < mine }.count) / Double(others.count) } : nil

    return InvestorProfile(
      riskScore: risk, volatility: volatility, yearReturn: snapshot?.yearReturn, style: style,
      positions: positions.count, largestSymbol: largest?.holding.symbol, largestWeight: largest?.weight ?? 0,
      effectiveHoldings: effective, fundShare: fundShare, dividendYield: dividendYield,
      dipBuyRate: dipBuyRate, loggedDecisions: logged.count, buyHitRate: hitRate,
      planCoverage: holdings.isEmpty ? 0 : Double(planned) / Double(holdings.count),
      flockReturnPercentile: returnPercentile, flockRiskPercentile: riskPercentile
    )
  }

  /// The plain-language list of what a broker could tell about you.
  var observations: [String] {
    var lines: [String] = []
    if let symbol = largestSymbol {
      lines.append(String(localized: "Your biggest position is \(symbol), at \(largestWeight.formatted(.percent.precision(.fractionLength(0)))) of your portfolio."))
    }
    if positions >= 2 {
      lines.append(String(localized: "Your \(positions) positions behave like \(effectiveHoldings.formatted(.number.precision(.fractionLength(1)))) equal ones."))
    }
    if let volatility {
      lines.append(String(localized: "Your portfolio swings about \(volatility.formatted(.percent.precision(.fractionLength(0)))) in a typical year."))
    }
    if dividendYield > 0.003 {
      lines.append(String(localized: "Dividends pay you about \(dividendYield.formatted(.percent.precision(.fractionLength(1)))) a year."))
    }
    if let dipBuyRate {
      lines.append(String(localized: "When a buy alert fires, you buy \(dipBuyRate.formatted(.percent.precision(.fractionLength(0)))) of the time."))
    }
    if let buyHitRate {
      lines.append(String(localized: "\(buyHitRate.formatted(.percent.precision(.fractionLength(0)))) of your fired buy alerts are higher today."))
    }
    lines.append(String(localized: "\(planCoverage.formatted(.percent.precision(.fractionLength(0)))) of your stocks have a plan."))
    return lines
  }
}
