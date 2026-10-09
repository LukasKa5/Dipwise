import Foundation
import Observation

@Observable
final class Portfolio {
  var holdings: [Holding]
  var insights: [CrowdInsight]

  init(holdings: [Holding] = Portfolio.sampleHoldings, insights: [CrowdInsight] = Portfolio.sampleInsights) {
    self.holdings = holdings
    self.insights = insights
  }

  var totalValue: Double { holdings.reduce(0) { $0 + $1.value } }

  var dayChange: Double {
    let previous = holdings.reduce(0) { $0 + $1.value / (1 + $1.dayChange) }
    return previous == 0 ? 0 : totalValue / previous - 1
  }

  /// Combined value history, used for the summary chart.
  var history: [Double] {
    guard let count = holdings.map(\.history.count).min() else { return [] }
    return (0..<count).map { index in
      holdings.reduce(0) { $0 + $1.shares * $1.history[index] }
    }
  }

  /// Holdings sorted so the ones closest to their targets come first.
  var nearestTargets: [Holding] {
    holdings.sorted { $0.distanceToTarget < $1.distanceToTarget }
  }
}

extension Portfolio {
  static let sampleHoldings: [Holding] = [
    Holding(symbol: "NVDA", name: "NVIDIA", shares: 12, price: 182.40, dayChange: -0.031, target: 178, targetKind: .buyBelow,
            history: [196, 194, 197, 191, 188, 190, 185, 183, 186, 182.4]),
    Holding(symbol: "AAPL", name: "Apple", shares: 20, price: 241.10, dayChange: 0.008, target: 255, targetKind: .sellAbove,
            history: [228, 230, 229, 233, 236, 234, 238, 240, 239, 241.1]),
    Holding(symbol: "MSFT", name: "Microsoft", shares: 8, price: 512.30, dayChange: 0.004, target: 560, targetKind: .sellAbove,
            history: [498, 502, 505, 501, 507, 510, 506, 509, 511, 512.3]),
    Holding(symbol: "TSLA", name: "Tesla", shares: 10, price: 268.90, dayChange: -0.052, target: 230, targetKind: .buyBelow,
            history: [305, 298, 301, 290, 284, 287, 279, 275, 281, 268.9]),
  ]

  static let sampleInsights: [CrowdInsight] = [
    CrowdInsight(symbol: "NVDA", holdersWithTarget: 0.62, medianTarget: 175,
                 summary: "62% of holders are waiting to buy more below $175."),
    CrowdInsight(symbol: "AAPL", holdersWithTarget: 0.48, medianTarget: 260,
                 summary: "Your sell target is more patient than 71% of holders."),
  ]
}
