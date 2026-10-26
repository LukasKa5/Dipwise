import Foundation
import UIKit
import UserNotifications

/// Instant alerts: the user's price-level alerts live on the quote proxy too, which checks them every minute while
/// the market is open and sends a push the moment one is reached, instead of waiting for iOS to wake the app.
/// The app's own background check stays as a backup. Needs `MarketData.proxyURL` and the push entitlement.
@MainActor
enum PushAlerts {
  private static let tokenKey = "push.deviceToken"
  private static let syncedKey = "push.syncedAlertIDs"

  static var isEnabled: Bool { MarketData.proxyURL != nil }

  /// Alerts the proxy watches, so the app doesn't notify about them a second time.
  static var syncedIDs: Set<UUID> {
    Set((UserDefaults.standard.stringArray(forKey: syncedKey) ?? []).compactMap(UUID.init))
  }

  /// Asks iOS for a push token once notifications are allowed. Called at launch and after permission is granted.
  static func register() {
    guard isEnabled else { return }
    Task {
      guard await NotificationManager.authorizationStatus() == .authorized else { return }
      UIApplication.shared.registerForRemoteNotifications()
    }
  }

  static func didRegister(token: Data) {
    UserDefaults.standard.set(token.map { String(format: "%02x", $0) }.joined(), forKey: tokenKey)
    sync(targets: TargetSnapshotStore.loadTargets(), quotes: TargetSnapshotStore.loadQuotes())
  }

  /// Sends the current price-level alerts to the proxy, replacing what it had for this device.
  static func sync(targets: [WatchedTarget], quotes: [String: Quote]) {
    guard isEnabled, let base = MarketData.proxyURL, let token = UserDefaults.standard.string(forKey: tokenKey) else { return }
    let alerts: [ServerAlert] = targets.compactMap { target in
      guard let quote = quotes[target.symbol], let level = target.rule.triggerLevel(for: quote), level > 0 else { return nil }
      let text = Self.text(for: target, quote: quote)
      return ServerAlert(id: target.id.uuidString, symbol: target.symbol, below: target.rule.triggersBelow, level: level,
                         title: text.title, body: text.body, currency: quote.currency)
    }
    UserDefaults.standard.set(alerts.map(\.id), forKey: syncedKey)
    let payload = Registration(token: token, environment: environment, locale: Locale.current.identifier, alerts: alerts)
    var request = URLRequest(url: base.appending(path: "devices"))
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONEncoder().encode(payload)
    Task { _ = try? await URLSession.shared.data(for: request) }
  }

  /// The notification's words, written on the device in the user's language. `{price}` is filled in by the proxy.
  private static func text(for target: WatchedTarget, quote: Quote) -> (title: String, body: String) {
    let rule = target.rule
    let symbol = target.symbol
    let range = "\(quote.formatted(rule.lower))–\(quote.formatted(rule.upper))"
    switch rule.kind {
    case .buyZone: return (String(localized: "\(symbol) entered your buy zone"), String(localized: "Now {price}, inside \(range)."))
    case .sellZone: return (String(localized: "\(symbol) reached your sell zone"), String(localized: "Now {price}, inside \(range)."))
    case .priceBelow: return (String(localized: "\(symbol) dipped below \(quote.formatted(rule.lower))"), String(localized: "Now {price}. This is the dip you were waiting for."))
    case .priceAbove: return (String(localized: "\(symbol) rose above \(quote.formatted(rule.lower))"), String(localized: "Now {price}. Your target is here."))
    default:
      let summary = rule.summary { quote.formatted($0) }
      return ("\(symbol) · \(rule.kind.title)", String(localized: "Now {price}. \(summary)."))
    }
  }

  /// Sandbox for simulator and development-signed builds, production for TestFlight and the App Store.
  private static var environment: String {
    #if targetEnvironment(simulator)
    return "sandbox"
    #else
    guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
          let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .isoLatin1) else { return "production" }
    return text.contains("<key>aps-environment</key>\n\t\t<string>production</string>") ? "production" : "sandbox"
    #endif
  }

  private struct Registration: Encodable {
    var token: String
    var environment: String
    var locale: String
    var alerts: [ServerAlert]
  }

  private struct ServerAlert: Encodable {
    var id: String
    var symbol: String
    var below: Bool
    var level: Double
    var title: String
    var body: String
    var currency: String
  }
}
