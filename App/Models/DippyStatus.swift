import Foundation

/// The one line Dippy says under the portfolio chart: what is actually happening right now, in plain words.
/// It follows the market's day (before the bell, open, after the close, the weekend) and the user's own plans.
struct DippyStatus: Equatable {
  var text: String
  var systemImage: String
  /// True when Dippy is asleep and a tap wakes him.
  var canWake = false

  struct Plan: Equatable {
    var symbol: String
    var distance: Double
    var isSell: Bool
  }

  struct Mover: Equatable {
    var symbol: String
    var change: Double
  }

  static func make(at date: Date = .now, dayChange: Double?, leader: Mover?, closest: Plan?, isAwake: Bool) -> DippyStatus {
    let percent = { (value: Double) in value.formatted(.percent.precision(.fractionLength(1))) }
    let signed = { (value: Double) in value.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())) }
    let bell = MarketClock.nextChange(after: date)
    let wait = Duration.seconds(max(0, bell.timeIntervalSince(date))).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))

    switch MarketClock.phase(at: date) {
    case .open:
      if let closest, closest.distance == 0 {
        let zone = closest.isSell ? String(localized: "sell zone") : String(localized: "buy zone")
        return DippyStatus(text: String(localized: "\(closest.symbol) is in your \(zone) right now. Time to check your plan."), systemImage: "bell.badge.fill")
      }
      if let closest, closest.distance < 0.03 {
        let zone = closest.isSell ? String(localized: "sell zone") : String(localized: "buy zone")
        return DippyStatus(text: String(localized: "\(closest.symbol) is just \(percent(closest.distance)) from your \(zone). Dippy has his eyes on it."), systemImage: "scope")
      }
      if let dayChange, dayChange >= 0.01 {
        let lead = leader.map { String(localized: " \($0.symbol) leads with \(signed($0.change)).") } ?? ""
        return DippyStatus(text: String(localized: "A green day, \(signed(dayChange)) so far.") + lead, systemImage: "sun.max.fill")
      }
      if let dayChange, dayChange <= -0.01 {
        return DippyStatus(text: String(localized: "A red day, \(signed(dayChange)) so far. Dips are where your plans pay off."), systemImage: "heart.fill")
      }
      if let closest {
        return DippyStatus(text: String(localized: "Market's open and calm. \(closest.symbol) is your closest plan, \(percent(closest.distance)) to go."), systemImage: "binoculars.fill")
      }
      return DippyStatus(text: String(localized: "Market's open and calm. Add a buy zone and Dippy will watch it."), systemImage: "binoculars.fill")
    case .preMarket:
      return DippyStatus(text: String(localized: "The market opens in \(wait). Dippy is stretching his wings."), systemImage: "sunrise.fill")
    case .afterHours:
      if let dayChange {
        return DippyStatus(text: String(localized: "The market closed \(signed(dayChange)) for you today. Dippy is heading to bed."), systemImage: "sunset.fill")
      }
      return DippyStatus(text: String(localized: "The market has closed for today. Dippy is heading to bed."), systemImage: "sunset.fill")
    case .overnight, .weekend:
      if isAwake {
        return DippyStatus(text: String(localized: "You woke Dippy! He'll keep watch until the market opens in \(wait)."), systemImage: "binoculars.fill")
      }
      let isWeekend = MarketClock.phase(at: date) == .weekend
      return DippyStatus(text: isWeekend
                           ? String(localized: "It's the weekend and Dippy is asleep. Tap him to wake him up.")
                           : String(localized: "Markets are closed and Dippy is asleep. Tap him to wake him up."),
                         systemImage: "moon.zzz.fill", canWake: true)
    }
  }
}
