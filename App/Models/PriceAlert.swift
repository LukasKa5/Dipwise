import Foundation
import SwiftData

@Model
final class PriceAlert {
  var id: UUID = UUID()
  var kindRaw: String = AlertKind.buyZone.rawValue
  /// Zone low, or the single price level.
  var targetPrice: Double = 0
  var upperPrice: Double = 0
  var percent: Double = 0
  var averageDays: Int = 200
  var peakPrice: Double = 0
  var priceAtCreation: Double = 0
  /// Money the user plans to invest when a buy alert triggers.
  var budget: Double = 0
  var note: String = ""
  var createdAt: Date = Date.now
  var isActive: Bool = true
  /// Repeating alerts stay on and fire each time the condition is newly met.
  var repeats: Bool = false
  var expiresAt: Date?
  var conditionMet: Bool = false
  var triggerCount: Int = 0
  var triggeredAt: Date?
  var triggeredPrice: Double?
  var headsUpSentAt: Date?
  /// The anonymous flock record mirroring this alert, when shared.
  var flockRecordName: String?
  var holding: Holding?
  /// Dip Journal: what the user did after the alert fired.
  var journalActionRaw: String?
  var journalPrice: Double = 0
  var journalDate: Date?

  init(rule: AlertRule, priceAtCreation: Double, note: String = "") {
    self.priceAtCreation = priceAtCreation
    self.note = note
    self.rule = rule
    if rule.kind == .trailingStop { peakPrice = max(rule.peak, priceAtCreation) }
  }

  var kind: AlertKind {
    get {
      if let kind = AlertKind(rawValue: kindRaw) { return kind }
      // Alerts saved before zones existed.
      return kindRaw == "sellAbove" ? .priceAbove : .priceBelow
    }
    set { kindRaw = newValue.rawValue }
  }

  var rule: AlertRule {
    get {
      AlertRule(kind: kind, lower: targetPrice, upper: upperPrice, percent: percent, averageDays: averageDays, peak: peakPrice)
    }
    set {
      kind = newValue.kind
      targetPrice = newValue.lower
      upperPrice = newValue.upper
      percent = newValue.percent
      averageDays = newValue.averageDays
      peakPrice = newValue.peak
    }
  }

  var symbol: String { holding?.symbol ?? "" }

  func distance(for quote: Quote) -> Double? { rule.distance(for: quote) }
  func progress(for quote: Quote) -> Double { rule.progress(for: quote) }

  func summary(for quote: Quote?) -> String {
    rule.summary { value in quote?.formatted(value) ?? value.formatted(.number.precision(.fractionLength(2))) }
  }

  /// Approximate shares the budget buys at the zone's midpoint.
  var plannedShares: Double? {
    guard budget > 0, let price = rule.referencePrice, price > 0 else { return nil }
    return budget / price
  }

  var journalAction: JournalAction? {
    get { journalActionRaw.flatMap(JournalAction.init(rawValue:)) }
    set { journalActionRaw = newValue?.rawValue }
  }

  var isExpired: Bool { expiresAt.map { $0 < .now } ?? false }

  /// Re-arms a triggered alert so it watches again.
  func rearm(currentPrice: Double) {
    isActive = true
    conditionMet = false
    triggeredAt = nil
    triggeredPrice = nil
    headsUpSentAt = nil
    priceAtCreation = currentPrice
    if kind == .trailingStop { peakPrice = currentPrice }
    if isExpired { expiresAt = nil }
  }

  var watchedTarget: WatchedTarget {
    WatchedTarget(id: id, symbol: symbol, name: holding?.name ?? symbol, rule: rule)
  }
}
