#if DEBUG
import Foundation
import SwiftData

/// Development only: `-demoPortfolio` replaces everything with the demo portfolio used for App Store screenshots,
/// with buy zones and a few logged decisions so every screen has realistic content.
enum DemoPortfolio {
  static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-demoPortfolio") }

  /// Prices on the frozen screenshot day (October 13, 2026), so average costs give the same returns every time.
  private static let holdings: [(String, String, Double, Double)] = [
    ("NVDA", "NVIDIA Corporation", 120, 141.06), ("AAPL", "Apple Inc.", 60, 210.66), ("AMZN", "Amazon.com, Inc.", 50, 159.62),
    ("GOOGL", "Alphabet Inc.", 40, 218.38), ("MSFT", "Microsoft Corporation", 30, 335.46), ("VOO", "Vanguard S&P 500 ETF", 25, 441.69),
    ("META", "Meta Platforms, Inc.", 12, 470.68), ("TSLA", "Tesla, Inc.", 10, 231.62),
  ]
  private static let zones: [(String, Double, Double)] = [
    ("AMZN", 236.20, 249.30), ("NVDA", 206.35, 217.80), ("AAPL", 306.30, 323.35), ("META", 668.65, 705.80),
  ]
  /// Where the demo investor would take some profit.
  private static let sellZones: [(String, Double, Double)] = [("NVDA", 255.00, 268.00), ("MSFT", 585.00, 600.00)]

  @MainActor
  static func install(in context: ModelContext) {
    guard isRequested else { return }
    for holding in (try? context.fetch(FetchDescriptor<Holding>())) ?? [] { context.delete(holding) }
    var bySymbol: [String: Holding] = [:]
    for (index, item) in holdings.enumerated() {
      let holding = Holding(symbol: item.0, name: item.1, shares: item.2, averageCost: item.3)
      holding.addedAt = .now.addingTimeInterval(-Double(200 - index) * 86_400)
      context.insert(holding)
      bySymbol[item.0] = holding
    }
    for zone in zones {
      let alert = PriceAlert(rule: AlertRule(kind: .buyZone, lower: zone.1, upper: zone.2), priceAtCreation: zone.2 * 1.08)
      alert.holding = bySymbol[zone.0]
      context.insert(alert)
    }
    for zone in sellZones {
      let alert = PriceAlert(rule: AlertRule(kind: .sellZone, lower: zone.1, upper: zone.2), priceAtCreation: zone.1 * 0.9)
      alert.holding = bySymbol[zone.0]
      context.insert(alert)
    }
    // Past dips: three bought, one held, so the profile has habits to show.
    let past: [(String, Double, Double, JournalAction, Double)] = [
      ("NVDA", 120, 128, .bought, 60), ("MSFT", 395, 410, .bought, 90), ("GOOGL", 160, 168, .bought, 120), ("TSLA", 280, 300, .held, 40),
    ]
    for item in past {
      let alert = PriceAlert(rule: AlertRule(kind: .buyZone, lower: item.1, upper: item.2), priceAtCreation: item.2 * 1.1)
      alert.holding = bySymbol[item.0]
      alert.isActive = false
      alert.triggeredAt = .now.addingTimeInterval(-item.4 * 86_400)
      alert.triggeredPrice = item.2
      alert.journalAction = item.3
      context.insert(alert)
    }
    try? context.save()
  }
}
#endif
