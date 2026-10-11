import Foundation

/// A badge earned through good investing habits.
struct Achievement: Identifiable {
  var id: String
  var title: String
  var detail: String
  /// Why this habit matters, shown when the badge is tapped.
  var explanation: String
  var systemImage: String
  var current: Double
  var goal: Double
  var unit: String = ""

  var progress: Double { goal == 0 ? 0 : min(1, current / goal) }
  var isUnlocked: Bool { progress >= 1 }

  var progressLabel: String {
    if isUnlocked { return "Unlocked" }
    if goal == 1 { return "Not yet" }
    return "\(Int(current.rounded(.down))) of \(Int(goal))\(unit.isEmpty ? "" : " \(unit)")"
  }

  /// Every achievement and how close the user is to it.
  @MainActor
  static func all(progress: ProgressStore, holdings: [Holding], quotes: [String: Quote]) -> [Achievement] {
    let alerts = holdings.flatMap { $0.alerts ?? [] }
    let smartKinds = Set(alerts.filter { $0.kind.requiresPro }.map(\.kind)).count
    let hasFullPlan = holdings.contains { $0.buyZone != nil && $0.sellZone != nil }
    let caughtDip = alerts.contains { $0.kind.side == .buy && $0.triggeredAt != nil }
    let oldestActiveDays = alerts.filter(\.isActive).map { Date.now.timeIntervalSince($0.createdAt) / 86_400 }.max() ?? 0
    let earnsDividends = holdings.contains { $0.isOwned && (quotes[$0.symbol]?.trailingAnnualDividend ?? 0) > 0 }

    return [
      Achievement(id: "first-plan", title: "First Plan", detail: "Set your first alert.",
                  explanation: "Every good investment starts with a plan. Deciding your price before the market moves keeps emotions out of it.",
                  systemImage: "scope", current: Double(progress.alertsCreated), goal: 1),
      Achievement(id: "full-plan", title: "Full Plan", detail: "Set a buy zone and a sell zone on the same stock.",
                  explanation: "Knowing where you'd buy more and where you'd take profit turns a hunch into a complete plan.",
                  systemImage: "arrow.up.and.down", current: hasFullPlan ? 1 : 0, goal: 1),
      Achievement(id: "toolkit", title: "Smart Toolkit", detail: "Use three different kinds of smart alerts.",
                  explanation: "Trend, momentum, and position alerts each catch different moments. Using several means fewer surprises.",
                  systemImage: "sparkles", current: Double(smartKinds), goal: 3, unit: "kinds"),
      Achievement(id: "diversified", title: "Diversified", detail: "Watch five different stocks.",
                  explanation: "Spreading attention across several companies means one bad day doesn't define your portfolio.",
                  systemImage: "square.grid.2x2.fill", current: Double(holdings.count), goal: 5, unit: "stocks"),
      Achievement(id: "dip-catcher", title: "Dip Catcher", detail: "Have one of your buy alerts fire.",
                  explanation: "Your patience paid off: the price came to you instead of you chasing it.",
                  systemImage: "checkmark.seal.fill", current: caughtDip ? 1 : 0, goal: 1),
      Achievement(id: "patient", title: "Patient Owl", detail: "Keep an alert waiting for 30 days.",
                  explanation: "The best prices rarely arrive on schedule. Letting a plan wait is a superpower most investors lack.",
                  systemImage: "hourglass", current: oldestActiveDays, goal: 30, unit: "days"),
      Achievement(id: "streak-7", title: "On Fire", detail: "Reach a 7-day streak.",
                  explanation: "A daily one-minute check-in builds the habit of reviewing your plan calmly instead of reacting.",
                  systemImage: "flame.fill", current: Double(progress.longestStreak), goal: 7, unit: "days"),
      Achievement(id: "streak-30", title: "Unstoppable", detail: "Reach a 30-day streak.",
                  explanation: "A month of daily check-ins. You're investing with routine, not emotion.",
                  systemImage: "bolt.fill", current: Double(progress.longestStreak), goal: 30, unit: "days"),
      Achievement(id: "flock-voice", title: "Flock Voice", detail: "Vote on 10 stocks with the flock.",
                  explanation: "Your votes make the crowd's mood more accurate for everyone, including you.",
                  systemImage: "person.3.fill", current: Double(progress.votes), goal: 10, unit: "votes"),
      Achievement(id: "journal", title: "Journal Keeper", detail: "Log 5 decisions in your Dip Journal.",
                  explanation: "Writing down what you did, and later seeing how it worked out, is the fastest way to improve.",
                  systemImage: "book.closed.fill", current: Double(progress.journalEntries), goal: 5, unit: "entries"),
      Achievement(id: "income", title: "Income Seeker", detail: "Own a stock that pays dividends.",
                  explanation: "Dividends pay you to wait. Reinvested, they've historically made up a big part of long-term returns.",
                  systemImage: "leaf.fill", current: earnsDividends ? 1 : 0, goal: 1),
      Achievement(id: "wise", title: "Wise Owl", detail: "Reach level 6.",
                  explanation: "Earned through steady habits: briefs, plans, votes, and journaling. Dipp is proud.",
                  systemImage: "graduationcap.fill", current: Double(progress.level), goal: 6, unit: "levels"),
    ]
  }
}
