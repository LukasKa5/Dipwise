import Foundation
import UserNotifications

/// Requests permission for and delivers Dipwise's price alerts.
enum NotificationManager {
  static func authorizationStatus() async -> UNAuthorizationStatus {
    await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
  }

  @discardableResult
  static func requestAuthorization() async -> Bool {
    (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
  }

  static func content(for event: AlertEngine.Event) -> UNMutableNotificationContent {
    let content = UNMutableNotificationContent()
    let alert = event.alert
    let quote = event.quote
    let symbol = alert.symbol
    let price = quote.formatted(quote.price)
    let rule = alert.rule
    let percent = rule.percent.formatted(.percent.precision(.fractionLength(0)))

    switch event.kind {
    case .approaching:
      let distance = (alert.distance(for: quote) ?? 0).formatted(.percent.precision(.fractionLength(1)))
      content.title = "\(symbol) is \(distance) from your \(alert.kind.title.lowercased())"
      content.body = "Now \(price). \(alert.summary(for: quote))."
    case .reached:
      switch alert.kind {
      case .buyZone:
        content.title = "\(symbol) entered your buy zone"
        content.body = "Now \(price), inside \(quote.formatted(rule.lower))–\(quote.formatted(rule.upper))."
        if let shares = alert.plannedShares {
          content.body += " Your plan: about \(shares.formatted(.number.precision(.fractionLength(0...2)))) shares."
        }
      case .sellZone:
        content.title = "\(symbol) reached your sell zone"
        content.body = "Now \(price), inside \(quote.formatted(rule.lower))–\(quote.formatted(rule.upper))."
      case .priceBelow:
        content.title = "\(symbol) dipped below \(quote.formatted(rule.lower))"
        content.body = "Now \(price). This is the dip you were waiting for."
      case .priceAbove:
        content.title = "\(symbol) rose above \(quote.formatted(rule.lower))"
        content.body = "Now \(price). Your target is here."
      case .trailingStop:
        content.title = "\(symbol) hit your \(percent) trailing stop"
        content.body = "Now \(price), down from its peak of \(quote.formatted(rule.peak))."
      case .stopLoss:
        content.title = "\(symbol) hit your stop loss"
        content.body = "Now \(price), \(percent) below your cost of \(quote.formatted(rule.lower))."
      case .profitTarget:
        content.title = "\(symbol) reached your profit target"
        content.body = "Now \(price), up \(percent) from your cost. Time to take some profit?"
      default:
        content.title = "\(symbol) · \(alert.kind.title)"
        content.body = "Now \(price). \(alert.summary(for: quote))."
      }
    }
    if !alert.note.isEmpty {
      content.body += " Your note: \u{201C}\(alert.note)\u{201D}"
    }
    content.sound = event.kind == .reached ? .default : nil
    content.interruptionLevel = event.kind == .reached && !AlertSettings.quietHours ? .timeSensitive : .active
    content.threadIdentifier = symbol
    content.userInfo = ["symbol": symbol]
    return content
  }

  static func post(_ events: [AlertEngine.Event]) async {
    for event in events {
      let request = UNNotificationRequest(identifier: "\(event.alert.id)-\(event.kind)-\(event.alert.triggerCount)", content: content(for: event), trigger: nil)
      try? await UNUserNotificationCenter.current().add(request)
    }
  }

  /// Tells the user a flock investor they follow added to or trimmed a position.
  static func post(followed moves: [FlockMove]) async {
    for move in moves.prefix(5) {
      let content = UNMutableNotificationContent()
      let name = FlockInvestor.nickname(for: move.installID)
      content.title = move.isBuy ? "\(name) bought \(move.symbol)" : "\(name) trimmed \(move.symbol)"
      content.body = move.isBuy ? String(localized: "An investor you follow added to \(move.symbol). Tap to see their portfolio.") : String(localized: "An investor you follow sold some \(move.symbol). Tap to see their portfolio.")
      content.threadIdentifier = "flock-\(move.installID)"
      content.userInfo = ["symbol": move.symbol]
      let request = UNNotificationRequest(identifier: "flock-\(move.id)", content: content, trigger: nil)
      try? await UNUserNotificationCenter.current().add(request)
    }
  }

  /// Schedules the daily brief reminder for the next week, skipping today once the brief is done.
  static func scheduleBriefReminders(streak: Int, skipToday: Bool) async {
    let center = UNUserNotificationCenter.current()
    let identifiers = (0..<8).map { "brief-\($0)" }
    center.removePendingNotificationRequests(withIdentifiers: identifiers)
    guard AlertSettings.briefReminderEnabled else { return }
    let minutes = AlertSettings.briefReminderMinutes
    let calendar = Calendar.current
    for offset in 0..<8 {
      guard let day = calendar.date(byAdding: .day, value: offset, to: .now) else { continue }
      if offset == 0 && skipToday { continue }
      var components = calendar.dateComponents([.year, .month, .day], from: day)
      components.hour = minutes / 60
      components.minute = minutes % 60
      guard let date = calendar.date(from: components), date > .now else { continue }
      let content = UNMutableNotificationContent()
      if streak > 0 {
        content.title = "Keep your streak going"
        content.body = "Your daily brief is ready. One minute with the owl keeps your plan sharp."
      } else {
        content.title = "Your daily brief is ready"
        content.body = "See how your stocks moved and how close they are to your zones."
      }
      content.sound = .default
      content.userInfo = ["brief": true]
      let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
      try? await center.add(UNNotificationRequest(identifier: "brief-\(offset)", content: content, trigger: trigger))
    }
  }

  /// Reminds the user two days before their free trial turns into a paid subscription.
  static func scheduleTrialReminder(daysUntilEnd: Int) async {
    guard daysUntilEnd > 2 else { return }
    let content = UNMutableNotificationContent()
    content.title = "Your Dipwise Pro trial ends in 2 days"
    content.body = "Keep it and Dippy keeps watching everything. Cancel any time in Settings."
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval((daysUntilEnd - 2) * 86_400), repeats: false)
    try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "trial-reminder", content: content, trigger: trigger))
  }

  static func sendTest() async {
    let content = UNMutableNotificationContent()
    content.title = "NVDA entered your buy zone"
    content.body = "Now $177.42, inside $170.00–$178.00. Your plan: about 5.7 shares."
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
    try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
  }
}
