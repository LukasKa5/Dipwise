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
    if isUnlocked { return String(localized: "Unlocked") }
    if goal == 1 { return String(localized: "Not yet") }
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
      Achievement(id: "first-plan", title: String(localized: "First Plan"), detail: String(localized: "Set your first alert."),
                  explanation: String(localized: "Every good investment starts with a plan. Deciding your price before the market moves keeps emotions out of it."),
                  systemImage: "scope", current: Double(progress.alertsCreated), goal: 1),
      Achievement(id: "full-plan", title: String(localized: "Full Plan"), detail: String(localized: "Set a buy zone and a sell zone on the same stock."),
                  explanation: String(localized: "Knowing where you'd buy more and where you'd take profit turns a hunch into a complete plan."),
                  systemImage: "arrow.up.and.down", current: hasFullPlan ? 1 : 0, goal: 1),
      Achievement(id: "toolkit", title: String(localized: "Smart Toolkit"), detail: String(localized: "Use three different kinds of smart alerts."),
                  explanation: String(localized: "Trend, momentum, and position alerts each catch different moments. Using several means fewer surprises."),
                  systemImage: "sparkles", current: Double(smartKinds), goal: 3, unit: "kinds"),
      Achievement(id: "diversified", title: String(localized: "Diversified"), detail: String(localized: "Watch five different stocks."),
                  explanation: String(localized: "Spreading attention across several companies means one bad day doesn't define your portfolio."),
                  systemImage: "square.grid.2x2.fill", current: Double(holdings.count), goal: 5, unit: "stocks"),
      Achievement(id: "dip-catcher", title: String(localized: "Dip Catcher"), detail: String(localized: "Have one of your buy alerts fire."),
                  explanation: String(localized: "Your patience paid off: the price came to you instead of you chasing it."),
                  systemImage: "checkmark.seal.fill", current: caughtDip ? 1 : 0, goal: 1),
      Achievement(id: "patient", title: String(localized: "Patient Owl"), detail: String(localized: "Keep an alert waiting for 30 days."),
                  explanation: String(localized: "The best prices rarely arrive on schedule. Letting a plan wait is a superpower most investors lack."),
                  systemImage: "hourglass", current: oldestActiveDays, goal: 30, unit: "days"),
      Achievement(id: "streak-7", title: String(localized: "On Fire"), detail: String(localized: "Reach a 7-day streak."),
                  explanation: String(localized: "A daily one-minute check-in builds the habit of reviewing your plan calmly instead of reacting."),
                  systemImage: "flame.fill", current: Double(progress.longestStreak), goal: 7, unit: "days"),
      Achievement(id: "streak-30", title: String(localized: "Unstoppable"), detail: String(localized: "Reach a 30-day streak."),
                  explanation: String(localized: "A month of daily check-ins. You're investing with routine, not emotion."),
                  systemImage: "bolt.fill", current: Double(progress.longestStreak), goal: 30, unit: "days"),
      Achievement(id: "flock-voice", title: String(localized: "Flock Voice"), detail: String(localized: "Vote on 10 stocks with the flock."),
                  explanation: String(localized: "Your votes make the crowd's mood more accurate for everyone, including you."),
                  systemImage: "person.3.fill", current: Double(progress.votes), goal: 10, unit: "votes"),
      Achievement(id: "journal", title: String(localized: "Journal Keeper"), detail: String(localized: "Log 5 decisions in your Dip Journal."),
                  explanation: String(localized: "Writing down what you did, and later seeing how it worked out, is the fastest way to improve."),
                  systemImage: "book.closed.fill", current: Double(progress.journalEntries), goal: 5, unit: "entries"),
      Achievement(id: "income", title: String(localized: "Income Seeker"), detail: String(localized: "Own a stock that pays dividends."),
                  explanation: String(localized: "Dividends pay you to wait. Reinvested, they've historically made up a big part of long-term returns."),
                  systemImage: "leaf.fill", current: earnsDividends ? 1 : 0, goal: 1),
      Achievement(id: "wise", title: String(localized: "Wise Owl"), detail: String(localized: "Reach level 6."),
                  explanation: String(localized: "Earned through steady habits: briefs, plans, votes, and journaling. Dippy is proud."),
                  systemImage: "graduationcap.fill", current: Double(progress.level), goal: 6, unit: "levels"),
    ]
  }
}
