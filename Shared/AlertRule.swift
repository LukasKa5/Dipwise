import Foundation

/// Whether an alert is about buying, selling, or just watching.
enum TradeSide: String, Codable {
  case buy
  case sell
  case watch
}

enum AlertKind: String, Codable, CaseIterable, Identifiable {
  case buyZone
  case sellZone
  case priceBelow
  case priceAbove
  case dropFromHigh
  case dailyMove
  case trailingStop
  case belowAverage

  var id: Self { self }

  var title: String {
    switch self {
    case .buyZone: "Buy zone"
    case .sellZone: "Sell zone"
    case .priceBelow: "Price below"
    case .priceAbove: "Price above"
    case .dropFromHigh: "Dip from high"
    case .dailyMove: "Big daily move"
    case .trailingStop: "Trailing stop"
    case .belowAverage: "Below average"
    }
  }

  var explanation: String {
    switch self {
    case .buyZone: "Alert when the price enters the range you'd happily buy in."
    case .sellZone: "Alert when the price reaches the range where you'd take profit."
    case .priceBelow: "Alert when the price falls to a level."
    case .priceAbove: "Alert when the price rises to a level."
    case .dropFromHigh: "Alert when the stock falls a set percentage below its 52-week high."
    case .dailyMove: "Alert when the stock moves up or down sharply in a single day."
    case .trailingStop: "Protect gains: alert when the price falls a set percentage from its peak since you set it."
    case .belowAverage: "Alert when the price drops below its long-term moving average."
    }
  }

  var systemImage: String {
    switch self {
    case .buyZone: "arrow.down.to.line.compact"
    case .sellZone: "arrow.up.to.line.compact"
    case .priceBelow: "arrow.down.to.line"
    case .priceAbove: "arrow.up.to.line"
    case .dropFromHigh: "chart.line.downtrend.xyaxis"
    case .dailyMove: "bolt.fill"
    case .trailingStop: "shield.lefthalf.filled"
    case .belowAverage: "waveform.path.ecg"
    }
  }

  var side: TradeSide {
    switch self {
    case .buyZone, .priceBelow, .dropFromHigh, .belowAverage: .buy
    case .sellZone, .priceAbove, .trailingStop: .sell
    case .dailyMove: .watch
    }
  }

  var isZone: Bool { self == .buyZone || self == .sellZone }
  var usesPercent: Bool { [.dropFromHigh, .dailyMove, .trailingStop].contains(self) }

  /// Smart alerts are part of Dipwise Pro.
  var requiresPro: Bool { [.dropFromHigh, .dailyMove, .trailingStop, .belowAverage].contains(self) }
}

/// A price condition the user wants to be told about.
struct AlertRule: Codable, Hashable {
  var kind: AlertKind
  /// Zone low, or the single price level.
  var lower: Double = 0
  /// Zone high.
  var upper: Double = 0
  /// Fraction for percentage rules, e.g. 0.1 for 10%.
  var percent: Double = 0
  var averageDays: Int = 200
  /// Highest price seen since a trailing stop was set.
  var peak: Double = 0

  /// The price that sets the alert off, when the rule has one.
  func triggerLevel(for quote: Quote) -> Double? {
    switch kind {
    case .buyZone: upper
    case .sellZone: lower
    case .priceBelow, .priceAbove: lower
    case .dropFromHigh: quote.high52 * (1 - percent)
    case .trailingStop: max(peak, quote.price) * (1 - percent)
    case .belowAverage: quote.movingAverage(days: averageDays)
    case .dailyMove: nil
    }
  }

  func isMet(by quote: Quote) -> Bool {
    switch kind {
    case .dailyMove:
      return abs(quote.change) >= percent
    case .sellZone, .priceAbove:
      return triggerLevel(for: quote).map { quote.price >= $0 } ?? false
    default:
      return triggerLevel(for: quote).map { quote.price <= $0 } ?? false
    }
  }

  /// How far the price still has to move, as a fraction (0 when met).
  func distance(for quote: Quote) -> Double? {
    guard quote.price > 0 else { return nil }
    if kind == .dailyMove {
      return max(0, percent - abs(quote.change))
    }
    guard let level = triggerLevel(for: quote) else { return nil }
    switch kind.side {
    case .sell where kind != .trailingStop:
      return max(0, (level - quote.price) / quote.price)
    default:
      return max(0, (quote.price - level) / quote.price)
    }
  }

  /// Progress toward triggering on a 0–1 scale, treating `span` away as the start.
  func progress(for quote: Quote, span: Double = 0.2) -> Double {
    guard let distance = distance(for: quote) else { return 0 }
    let reference = kind == .dailyMove ? max(percent, 0.01) : span
    return 1 - min(distance / reference, 1)
  }

  /// How deep the price is inside a zone, 0 at the entry edge and 1 at the far edge.
  func zoneDepth(for quote: Quote) -> Double? {
    guard kind.isZone, upper > lower else { return nil }
    let depth = kind == .buyZone ? (upper - quote.price) / (upper - lower) : (quote.price - lower) / (upper - lower)
    return depth < 0 ? nil : min(depth, 1)
  }

  /// A representative price for comparing with other investors.
  var referencePrice: Double? {
    switch kind {
    case .buyZone, .sellZone: (lower + upper) / 2
    case .priceBelow, .priceAbove: lower
    default: nil
    }
  }

  /// A plain-language description, like "Buy between $170 and $178".
  func summary(format: (Double) -> String) -> String {
    let percentText = percent.formatted(.percent.precision(.fractionLength(0)))
    switch kind {
    case .buyZone: return "Buy between \(format(lower)) and \(format(upper))"
    case .sellZone: return "Sell between \(format(lower)) and \(format(upper))"
    case .priceBelow: return "Buy below \(format(lower))"
    case .priceAbove: return "Sell above \(format(lower))"
    case .dropFromHigh: return "Buy after a \(percentText) dip from the high"
    case .dailyMove: return "A \(percentText) move in one day"
    case .trailingStop: return "Sell if it falls \(percentText) from its peak"
    case .belowAverage: return "Falls below its \(averageDays)-day average"
    }
  }
}
