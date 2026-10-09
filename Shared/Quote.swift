import Foundation

struct Quote: Codable, Hashable {
  var symbol: String
  var name: String
  var currency: String
  var price: Double
  var previousClose: Double
  /// Daily closes, oldest first.
  var closes: [Double]
  var updatedAt: Date

  var change: Double {
    previousClose == 0 ? 0 : price / previousClose - 1
  }

  func formatted(_ value: Double) -> String {
    value.formatted(.currency(code: currency).precision(.fractionLength(value < 10 ? 2...4 : 2...2)))
  }
}

enum ChartRange: String, CaseIterable, Identifiable, Codable {
  case month = "1mo"
  case threeMonths = "3mo"
  case year = "1y"
  case fiveYears = "5y"

  var id: Self { self }

  var title: String {
    switch self {
    case .month: "1M"
    case .threeMonths: "3M"
    case .year: "1Y"
    case .fiveYears: "5Y"
    }
  }

  var interval: String {
    switch self {
    case .month, .threeMonths: "1d"
    case .year: "1d"
    case .fiveYears: "1wk"
    }
  }
}
