import Foundation

/// A badge earned through good investing habits.
struct Achievement: Identifiable {
  var id: String
  var title: String
  var detail: String
  var systemImage: String
  var progress: Double

  var isUnlocked: Bool { progress >= 1 }

  /// Every achievement and how close the user is to it.
  @MainActor
  static func all(progress: ProgressStore, holdings: [Holding], quotes: [String: Quote]) -> [Achievement] {
    let alerts = holdings.flatMap { $0.alerts ?? [] }
    func ratio(_ value: Int, of goal: Int) -> Double { min(1, Double(value) / Double(goal)) }
    let maxBuyTiers = holdings.map { holding in holding.activeAlerts.filter { $0.kind == .buyZone }.count }.max() ?? 0
    let hasFullPlan = holdings.contains { $0.buyZone != nil && $0.sellZone != nil }
    let caughtDip = alerts.contains { $0.kind.side == .buy && $0.triggeredAt != nil }
    let oldestActiveDays = alerts.filter(\.isActive).map { Date.now.timeIntervalSince($0.createdAt) / 86_400 }.max() ?? 0
    let earnsDividends = holdings.contains { $0.isOwned && (quotes[$0.symbol]?.trailingAnnualDividend ?? 0) > 0 }

    return [
      Achievement(id: "first-plan", title: "First Plan", detail: "Set your first alert", systemImage: "scope", progress: ratio(progress.alertsCreated, of: 1)),
      Achievement(id: "full-plan", title: "Full Plan", detail: "Set a buy zone and a sell zone on one stock", systemImage: "arrow.up.and.down", progress: hasFullPlan ? 1 : 0),
      Achievement(id: "ladder", title: "Ladder Builder", detail: "Plan three buy tiers on one stock", systemImage: "chart.bar.fill", progress: ratio(maxBuyTiers, of: 3)),
      Achievement(id: "diversified", title: "Diversified", detail: "Watch five stocks", systemImage: "square.grid.2x2.fill", progress: ratio(holdings.count, of: 5)),
      Achievement(id: "dip-catcher", title: "Dip Catcher", detail: "Have a buy alert fire", systemImage: "checkmark.seal.fill", progress: caughtDip ? 1 : 0),
      Achievement(id: "patient", title: "Patient Owl", detail: "Keep an alert waiting for 30 days", systemImage: "hourglass", progress: min(1, oldestActiveDays / 30)),
      Achievement(id: "streak-7", title: "On Fire", detail: "Reach a 7-day streak", systemImage: "flame.fill", progress: ratio(progress.longestStreak, of: 7)),
      Achievement(id: "streak-30", title: "Unstoppable", detail: "Reach a 30-day streak", systemImage: "bolt.fill", progress: ratio(progress.longestStreak, of: 30)),
      Achievement(id: "flock-voice", title: "Flock Voice", detail: "Vote 10 times", systemImage: "person.3.fill", progress: ratio(progress.votes, of: 10)),
      Achievement(id: "journal", title: "Journal Keeper", detail: "Log 5 decisions in your Dip Journal", systemImage: "book.closed.fill", progress: ratio(progress.journalEntries, of: 5)),
      Achievement(id: "income", title: "Income Seeker", detail: "Own a stock that pays dividends", systemImage: "leaf.fill", progress: earnsDividends ? 1 : 0),
      Achievement(id: "wise", title: "Wise Owl", detail: "Reach level 6", systemImage: "graduationcap.fill", progress: min(1, Double(progress.level) / 6)),
    ]
  }
}
