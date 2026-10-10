import Foundation

/// Decides which alerts have been reached or are getting close, and updates their state.
enum AlertEngine {
  struct Event {
    enum Kind {
      case reached
      case approaching
    }

    var kind: Kind
    var alert: PriceAlert
    var quote: Quote
  }

  /// Evaluates active alerts against the latest quotes. Mutates alert state and returns what to notify about.
  static func evaluate(_ alerts: [PriceAlert], quotes: [String: Quote], headsUpThreshold: Double?, now: Date = .now) -> [Event] {
    var events: [Event] = []
    for alert in alerts where alert.isActive {
      guard let quote = quotes[alert.symbol] else { continue }
      if alert.isExpired {
        alert.isActive = false
        continue
      }
      if alert.kind == .trailingStop {
        alert.peakPrice = max(alert.peakPrice, quote.price)
      }

      let isMet = alert.rule.isMet(by: quote)
      if isMet && !alert.conditionMet {
        alert.conditionMet = true
        alert.triggerCount += 1
        alert.triggeredAt = now
        alert.triggeredPrice = quote.price
        if !alert.repeats { alert.isActive = false }
        events.append(Event(kind: .reached, alert: alert, quote: quote))
      } else if !isMet {
        if alert.conditionMet {
          // The price left the condition, so a repeating alert can fire again.
          alert.conditionMet = false
          alert.headsUpSentAt = nil
        }
        if let headsUpThreshold, alert.kind != .dailyMove, alert.headsUpSentAt == nil,
           let distance = alert.distance(for: quote), distance <= headsUpThreshold {
          alert.headsUpSentAt = now
          events.append(Event(kind: .approaching, alert: alert, quote: quote))
        }
      }
    }
    return events
  }
}
