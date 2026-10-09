import Foundation

struct CrowdInsight: Identifiable {
  var id: String { symbol }
  var symbol: String
  var holdersWithTarget: Double
  var medianTarget: Double
  var summary: String
}
