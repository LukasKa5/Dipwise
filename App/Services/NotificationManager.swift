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

  static func post(_ events: [AlertEngine.Event]) async {
    for event in events {
      let content = UNMutableNotificationContent()
      let symbol = event.alert.symbol
      let price = event.quote.formatted(event.quote.price)
      let target = event.quote.formatted(event.alert.targetPrice)
      switch (event.kind, event.alert.kind) {
      case (.reached, .buyBelow):
        content.title = "\(symbol) dipped below \(target)"
        content.body = "Now \(price). This is the dip you were waiting for."
      case (.reached, .sellAbove):
        content.title = "\(symbol) rose above \(target)"
        content.body = "Now \(price). Your sell target is here."
      case (.approaching, _):
        let distance = event.alert.distance(from: event.quote.price).formatted(.percent.precision(.fractionLength(1)))
        content.title = "\(symbol) is \(distance) from your target"
        content.body = "Now \(price). \(event.alert.kind.title) \(target)."
      }
      if !event.alert.note.isEmpty {
        content.body += " Your note: \u{201C}\(event.alert.note)\u{201D}"
      }
      content.sound = event.kind == .reached ? .default : nil
      content.interruptionLevel = event.kind == .reached ? .timeSensitive : .active
      content.threadIdentifier = symbol
      content.userInfo = ["symbol": symbol]
      let request = UNNotificationRequest(identifier: "\(event.alert.id)-\(event.kind)", content: content, trigger: nil)
      try? await UNUserNotificationCenter.current().add(request)
    }
  }

  static func sendTest() async {
    let content = UNMutableNotificationContent()
    content.title = "NVDA dipped below $178.00"
    content.body = "Now $177.42. This is the dip you were waiting for."
    content.sound = .default
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
    try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "test", content: content, trigger: trigger))
  }
}
