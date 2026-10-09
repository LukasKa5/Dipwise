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
    let previous = history.dropLast().last ?? 0
    return previous == 0 ? 0 : totalValue / previous - 1
  }

  /// Combined value history, used for the summary chart.
  var history: [Double] {
    guard let count = holdings.map(\.history.count).min() else { return [] }
    return (0..<count).map { index in
      holdings.reduce(0) { $0 + $1.shares * $1.history[index] }
    }
  }

  /// The lowest point of the history, where the owl perches.
  var dip: (index: Int, value: Double)? {
    history.enumerated().min { $0.element < $1.element }.map { ($0.offset, $0.element) }
  }

  /// Holdings sorted so the ones closest to their targets come first.
  var nearestTargets: [Holding] {
    holdings.sorted { $0.distanceToTarget < $1.distanceToTarget }
  }

  var nearTargetCount: Int { holdings.filter(\.isNearTarget).count }
}

extension Portfolio {
  static let sampleHoldings: [Holding] = [
    Holding(symbol: "NVDA", name: "NVIDIA", shares: 12, target: 178, targetKind: .buyBelow,
            history: [191, 188, 184, 179, 175.5, 177, 180, 183, 185.2, 182.4]),
    Holding(symbol: "AAPL", name: "Apple", shares: 20, target: 255, targetKind: .sellAbove,
            history: [236, 233, 229, 226, 224, 227, 231, 235, 243, 247.3]),
    Holding(symbol: "MSFT", name: "Microsoft", shares: 8, target: 560, targetKind: .sellAbove,
            history: [505, 500, 494, 489, 486, 491, 498, 503, 508, 512.3]),
    Holding(symbol: "TSLA", name: "Tesla", shares: 10, target: 230, targetKind: .buyBelow,
            history: [292, 284, 276, 268, 259, 262, 270, 276, 281, 279.6]),
  ]

  static let sampleInsights: [CrowdInsight] = [
    CrowdInsight(symbol: "NVDA", holdersWithTarget: 0.62, medianTarget: 175,
                 summary: "62% of holders are waiting to buy more below $175."),
    CrowdInsight(symbol: "AAPL", holdersWithTarget: 0.48, medianTarget: 260,
                 summary: "Your sell target is more patient than 71% of holders."),
    CrowdInsight(symbol: "TSLA", holdersWithTarget: 0.55, medianTarget: 240,
                 summary: "Most holders plan to buy the dip around $240."),
  ]
}
