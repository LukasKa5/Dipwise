import Foundation

/// Projects dividend income year by year and works out what it takes to reach a monthly income goal.
/// Simple on purpose: the portfolio grows by `growth` a year (dividends grow with it, so the yield stays the same),
/// the user adds `monthly` every month, and dividends are reinvested or paid out.
struct IncomePlan: Equatable {
  /// Today's portfolio value and yearly dividend income, in the base currency.
  var value: Double
  var yield: Double
  var monthly: Double
  var growth: Double
  var reinvests: Bool
  var goalPerMonth: Double
  var targetYear: Int
  var startYear = Calendar.current.component(.year, from: .now)

  struct Year: Identifiable, Equatable {
    var year: Int
    var value: Double
    /// Dividend income in that year, per month.
    var perMonth: Double
    var id: Int { year }
  }

  /// Income for every year until the goal is reached, or 40 years at most.
  func projection(monthly: Double? = nil, years: Int = 40) -> [Year] {
    let monthly = monthly ?? self.monthly
    var value = self.value
    var result: [Year] = []
    for offset in 0...years {
      let income = value * yield
      result.append(Year(year: startYear + offset, value: value, perMonth: income / 12))
      value = value * (1 + growth) + monthly * 12 + (reinvests ? income : 0)
    }
    return result
  }

  var currentPerMonth: Double { value * yield / 12 }
  var progress: Double { goalPerMonth > 0 ? min(1, currentPerMonth / goalPerMonth) : 0 }

  /// The first year income reaches the goal at the current pace, if within 40 years.
  var yearReached: Int? {
    projection().first { $0.perMonth >= goalPerMonth }?.year
  }

  /// What to invest each month to reach the goal by the target year.
  var monthlyNeeded: Double? {
    let years = targetYear - startYear
    guard years > 0, goalPerMonth > 0, yield > 0 else { return nil }
    let reaches = { (monthly: Double) in (projection(monthly: monthly, years: years).last?.perMonth ?? 0) >= goalPerMonth }
    if reaches(0) { return 0 }
    var low = 0.0, high = 100.0
    while !reaches(high) {
      high *= 2
      if high > 10_000_000 { return nil }
    }
    for _ in 0..<40 {
      let middle = (low + high) / 2
      if reaches(middle) { high = middle } else { low = middle }
    }
    return (high / 5).rounded(.up) * 5
  }
}
