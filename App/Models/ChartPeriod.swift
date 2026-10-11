import Foundation

/// A preset chart range or a custom date span the user picked.
enum ChartPeriod: Hashable {
  case preset(ChartRange)
  case custom(ClosedRange<Date>)

  var title: String {
    switch self {
    case .preset(let range): range.title
    case .custom(let span):
      "\(span.lowerBound.formatted(.dateTime.day().month(.abbreviated)))–\(span.upperBound.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits)))"
    }
  }

  var isCustom: Bool {
    if case .custom = self { return true }
    return false
  }

  /// Periods of a day or less are drawn from intraday prices.
  var isIntraday: Bool {
    switch self {
    case .preset(let range): range == .day
    case .custom(let span): span.upperBound.timeIntervalSince(span.lowerBound) < 2 * 86_400
    }
  }

  /// Whether the period reaches further back than one year of daily data.
  func needsLongHistory(earliestDaily: Date?) -> Bool {
    switch self {
    case .preset(let range): return range == .fiveYears
    case .custom(let span): return span.lowerBound < (earliestDaily ?? .now)
    }
  }

  /// The part of a price series that falls in this period.
  func slice(values: [Double], dates: [Date]) -> (values: [Double], dates: [Date]) {
    switch self {
    case .preset(let range):
      guard let sessions = range.sessions else { return (values, dates) }
      return (Array(values.suffix(sessions)), Array(dates.suffix(sessions)))
    case .custom(let span):
      guard dates.count == values.count else { return (values, dates) }
      let pairs = zip(values, dates).filter { span.contains($0.1) || Calendar.current.isDate($0.1, inSameDayAs: span.upperBound) }
      return (pairs.map(\.0), pairs.map(\.1))
    }
  }
}
