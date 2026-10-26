import Foundation

/// The behavior side of the profile: the traits and blind spots brokers track about their clients, worked out from
/// the user's own holdings, plans, decisions, and daily check-ins, and set against the flock.
struct InvestorBehavior {
  struct Trait: Identifiable {
    var id: String { title }
    var title: String
    var detail: String
    var systemImage: String
    /// 0–100.
    var score: Int
    /// The flock's average, when there's a crowd to compare with.
    var flockAverage: Int?
  }

  struct BlindSpot: Identifiable {
    var id: String { title }
    var title: String
    var detail: String
    var systemImage: String
    var isWarning: Bool
  }

  var traits: [Trait]
  var blindSpots: [BlindSpot]
  /// Check-ins where the user's mood went against the flock's, out of the days compared.
  var contrarianDays: Int
  var comparedDays: Int

  static func make(profile: InvestorProfile, summary: PortfolioSummary, holdings: [Holding], quotes: [String: Quote],
                   flock: [FlockPortfolio], sentiment: FlockSentiment?, checkIns: [FlockCheckIn]) -> InvestorBehavior {
    let percent = { (value: Double) in value.formatted(.percent.precision(.fractionLength(0))) }
    let clamp = { (value: Double) in Int(min(max(value, 0), 100).rounded()) }

    // The flock's averages, from members who share their mix.
    let members = flock.filter { !$0.positions.isEmpty }
    let hasCrowd = members.count >= FlockInsights.minimumMembers
    let flockRisk: Int? = hasCrowd ? clamp(members.compactMap(\.volatility).map { $0 / 0.45 * 100 }.average) : nil
    let flockSpread: Int? = hasCrowd ? clamp(members.map { member in
      let weights = member.positions.map(\.weight)
      return min(1 / max(weights.reduce(0) { $0 + $1 * $1 }, 0.0001), 15) / 15 * 100
    }.average) : nil
    let flockConviction: Int? = hasCrowd ? clamp(members.map { ($0.positions.map(\.weight).max() ?? 0) * 150 }.average) : nil

    let traits = [
      Trait(title: String(localized: "Patience"), detail: String(localized: "Plans before buying, and waits for the price"),
            systemImage: "hourglass", score: clamp(profile.planCoverage * 100), flockAverage: hasCrowd ? 41 : nil),
      Trait(title: String(localized: "Discipline"), detail: String(localized: "Acts when a planned alert fires"),
            systemImage: "checkmark.seal.fill", score: clamp((profile.dipBuyRate ?? 0.5) * 100), flockAverage: hasCrowd ? 56 : nil),
      Trait(title: String(localized: "Spread"), detail: String(localized: "How evenly money is spread across holdings"),
            systemImage: "circle.hexagongrid.fill", score: profile.diversificationScore, flockAverage: flockSpread),
      Trait(title: String(localized: "Risk appetite"), detail: String(localized: "How much the portfolio swings in a year"),
            systemImage: "flame.fill", score: clamp((profile.volatility ?? 0.2) / 0.45 * 100), flockAverage: flockRisk),
      Trait(title: String(localized: "Income focus"), detail: String(localized: "How much return comes as dividends"),
            systemImage: "leaf.fill", score: clamp(profile.dividendYield / 0.05 * 100), flockAverage: hasCrowd ? 28 : nil),
      Trait(title: String(localized: "Conviction"), detail: String(localized: "How much rides on the biggest position"),
            systemImage: "target", score: clamp(profile.largestWeight * 150), flockAverage: flockConviction),
    ]

    var spots: [BlindSpot] = []
    let positions = summary.positions
    let chased = positions.filter { $0.holding.averageCost > 0 && $0.quote.high52 > 0 && $0.holding.averageCost >= $0.quote.high52 * 0.95 }
    if !chased.isEmpty {
      spots.append(BlindSpot(
        title: String(localized: "You bought \(chased.map(\.holding.symbol).prefix(3).formatted(.list(type: .and))) near the yearly high"),
        detail: String(localized: "Brokers call this chasing: buying after a run-up. A buy zone below today's price lets you wait for a better entry."),
        systemImage: "arrow.up.right.circle.fill", isWarning: true))
    }
    let losers = positions.filter { ($0.holding.gain(at: $0.quote.price) ?? 0) <= -0.2 && ($0.holding.alerts ?? []).allSatisfy { !$0.isActive } }
    if !losers.isEmpty {
      spots.append(BlindSpot(
        title: String(localized: "\(losers.map(\.holding.symbol).prefix(3).formatted(.list(type: .and))) \(losers.count == 1 ? "is" : "are") down over 20% with no plan"),
        detail: String(localized: "Investors hold losing stocks about 1.5 times longer than winners, hoping to break even. Decide now: average down, set a stop, or let it go."),
        systemImage: "tortoise.fill", isWarning: true))
    }
    let winners = positions.filter { position in
      (position.holding.gain(at: position.quote.price) ?? 0) >= 0.5
        && !(position.holding.alerts ?? []).contains { $0.isActive && [.sellZone, .trailingStop, .profitTarget].contains($0.kind) }
    }
    if !winners.isEmpty {
      spots.append(BlindSpot(
        title: String(localized: "\(winners.map(\.holding.symbol).prefix(3).formatted(.list(type: .and))) gained over 50% with nothing protecting it"),
        detail: String(localized: "Big winners give back gains when nobody's watching. A trailing stop or a sell zone locks in part of the profit."),
        systemImage: "shield.lefthalf.filled", isWarning: true))
    }
    let missed = holdings.flatMap { $0.alerts ?? [] }.filter { alert in
      guard alert.kind.side == .buy, let price = alert.triggeredPrice, price > 0, let quote = quotes[alert.symbol] else { return false }
      return quote.price > price * 1.03 && (alert.journalAction == nil || alert.journalAction == .skipped)
    }
    if missed.count >= 2 {
      spots.append(BlindSpot(
        title: String(localized: "You skipped \(missed.count) buy alerts that are up since"),
        detail: String(localized: "Fear of buying in a dip is the most common reason plans fail. Next time, buy a small first part when the alert fires."),
        systemImage: "figure.walk.departure", isWarning: true))
    }
    if profile.largestWeight > 0.25, let symbol = profile.largestSymbol {
      spots.append(BlindSpot(
        title: String(localized: "\(symbol) is \(percent(profile.largestWeight)) of your portfolio"),
        detail: String(localized: "One bad quarter there moves everything. Brokers flag anything over 25% in one stock as concentrated."),
        systemImage: "chart.pie.fill", isWarning: true))
    }
    if spots.isEmpty {
      spots.append(BlindSpot(title: String(localized: "No blind spots right now"),
                             detail: String(localized: "Your plans cover your stocks and nothing is lopsided. Dippy checks again every day."),
                             systemImage: "checkmark.seal.fill", isWarning: false))
    }

    // Contrarian days: greedy while the flock was fearful, or fearful while it was greedy.
    let flockByDay = Dictionary(uniqueKeysWithValues: (sentiment?.days ?? []).map { ($0.day, $0.score) })
    let compared = checkIns.filter { flockByDay[$0.day] != nil }
    let contrarian = compared.filter { checkIn in
      let crowd = flockByDay[checkIn.day] ?? 50
      return (checkIn.feeling.rawValue >= 75 && crowd < 45) || (checkIn.feeling.rawValue <= 25 && crowd > 55)
    }

    return InvestorBehavior(traits: traits, blindSpots: spots, contrarianDays: contrarian.count, comparedDays: compared.count)
  }
}

private extension Array where Element == Double {
  var average: Double { isEmpty ? 0 : reduce(0, +) / Double(count) }
}
