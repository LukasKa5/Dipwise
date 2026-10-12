import Foundation
import Observation
import SwiftData

/// Investor goals asked during onboarding; they choose the starter plan.
enum InvestorStyle: String, CaseIterable, Identifiable {
  case dips
  case income
  case protect
  case calm
  case other

  var id: Self { self }

  var title: String {
    switch self {
    case .dips: "Buy dips smartly"
    case .income: "Grow dividend income"
    case .protect: "Protect my gains"
    case .calm: "Invest calmly, without stress"
    case .other: "Something else"
    }
  }

  var systemImage: String {
    switch self {
    case .dips: "arrow.down.to.line.compact"
    case .income: "leaf.fill"
    case .protect: "shield.lefthalf.filled"
    case .calm: "moon.stars.fill"
    case .other: "ellipsis.bubble.fill"
    }
  }

  var owlReply: String {
    switch self {
    case .dips: "A dip hunter! I'll watch for bargains."
    case .income: "Slow and steady. I love it."
    case .protect: "Smart. I'll guard your gains."
    case .calm: "Hoo! That's exactly what I'm for."
    case .other: "Tell me more! I'm all ears. Well, tufts."
    }
  }
}

/// State for the onboarding flow, which ends by creating the user's first watchlist and plan.
@MainActor
@Observable
final class OnboardingModel {
  static let suggestions = ["AAPL", "NVDA", "MSFT", "TSLA", "AMZN", "GOOGL", "META", "VOO", "KO", "O", "AMD", "NFLX"]

  var styles: Set<InvestorStyle> = []
  var lastStyle: InvestorStyle?
  var otherGoal = ""
  var selected: [String] = []
  var quotes: [String: Quote] = [:]
  var zoneLower = 0.0
  var zoneUpper = 0.0
  var vote: Bool?
  var smartKinds: Set<AlertKind> = []
  /// Little tasks in the tour that teach a feature and earn XP.
  private(set) var completedMissions: Set<String> = []
  private(set) var missionCelebration = 0
  static let missionPoints = 10

  var earnedXP: Int { completedMissions.count * Self.missionPoints }

  func complete(_ mission: String) {
    guard !completedMissions.contains(mission) else { return }
    completedMissions.insert(mission)
    missionCelebration += 1
  }

  /// Popular smart alerts offered during the tour.
  static let suggestedSmart: [AlertKind] = [.rsiOversold, .trailingStop, .dropFromHigh, .goldenCross, .volumeSpike, .dividendSoon]

  var focusSymbol: String? { selected.first }
  var focusQuote: Quote? { focusSymbol.flatMap { quotes[$0] } }

  func loadQuotes() async {
    guard quotes.isEmpty else { return }
    quotes = await QuoteService().quotes(for: Self.suggestions)
  }

  func toggle(style: InvestorStyle) {
    if styles.contains(style) {
      styles.remove(style)
      lastStyle = styles.first
    } else {
      styles.insert(style)
      lastStyle = style
    }
  }

  func toggle(_ symbol: String) {
    if let index = selected.firstIndex(of: symbol) {
      selected.remove(at: index)
    } else if selected.count < 5 {
      selected.append(symbol)
    }
  }

  /// Suggests a buy zone 5–10% below today's price for the focus stock.
  func prepareZone() {
    guard let quote = focusQuote, zoneLower == 0 else { return }
    let step: Double = quote.price >= 1000 ? 1 : 0.05
    zoneLower = (quote.price * 0.90 / step).rounded() * step
    zoneUpper = (quote.price * 0.95 / step).rounded() * step
  }

  /// Creates the chosen stocks, a buy zone for the focus stock, and starter zones for the rest within the free limit.
  func commit(context: ModelContext, quoteStore: QuoteStore, isPro: Bool) -> [PriceAlert] {
    UserDefaults.standard.set(styles.map(\.rawValue), forKey: AlertSettings.investorStyleKey)
    if !otherGoal.isEmpty { UserDefaults.standard.set(otherGoal, forKey: "investorGoalNote") }
    var created: [PriceAlert] = []
    let existing = Set(((try? context.fetch(FetchDescriptor<Holding>())) ?? []).map(\.symbol))
    for symbol in selected where !existing.contains(symbol) {
      guard let quote = quotes[symbol] else { continue }
      quoteStore.store(quote)
      let holding = Holding(symbol: symbol, name: quote.name)
      context.insert(holding)
      let canAdd = isPro || AlertLimits.activeAlertCount(in: context) + created.count < FreeTier.maxActiveAlerts
      guard canAdd else { continue }
      let rule: AlertRule
      if symbol == focusSymbol, zoneUpper > zoneLower {
        rule = AlertRule(kind: .buyZone, lower: zoneLower, upper: zoneUpper)
      } else {
        let step: Double = quote.price >= 1000 ? 1 : 0.05
        rule = AlertRule(kind: .buyZone, lower: (quote.price * 0.88 / step).rounded() * step, upper: (quote.price * 0.94 / step).rounded() * step)
      }
      let alert = PriceAlert(rule: rule, priceAtCreation: quote.price)
      alert.holding = holding
      context.insert(alert)
      created.append(alert)
    }
    try? context.save()
    return created
  }

  /// Adds the smart alerts picked in the tour to the focus stock (they're part of Pro).
  func commitSmartAlerts(context: ModelContext) {
    guard let symbol = focusSymbol, let quote = quotes[symbol], !smartKinds.isEmpty else { return }
    let holdings = (try? context.fetch(FetchDescriptor<Holding>())) ?? []
    guard let holding = holdings.first(where: { $0.symbol == symbol }) else { return }
    for kind in smartKinds where !holding.activeAlerts.contains(where: { $0.kind == kind }) {
      let alert = PriceAlert(rule: AlertRule.defaults(for: kind, price: quote.price, cost: holding.averageCost), priceAtCreation: quote.price)
      alert.holding = holding
      alert.prime(with: quote)
      context.insert(alert)
    }
    try? context.save()
  }
}
