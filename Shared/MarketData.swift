import Foundation

/// Where prices come from, and how fresh they are.
///
/// Everyone sees prices 15 minutes late for now: delayed data is far cheaper to license and has no per-user exchange
/// fees. Real-time for Pro is built in and switched off with `offersRealTime`, ready for when revenue covers those
/// fees. In production every request goes through your own quote proxy
/// (Backend/quote-proxy), which holds the data vendor's key and caches each stock once for everyone.
enum MarketData {
  /// Your deployed quote proxy, such as https://dipwise-quotes.yourname.workers.dev. Nil reads Yahoo Finance
  /// directly, which is fine for development but not licensed for a commercial app.
  static let proxyURL: URL? = nil

  /// How late prices are, for everyone while real-time is off, and for free members once it's on.
  static let freeDelay: TimeInterval = 15 * 60

  /// Whether Dipwise Pro includes real-time prices. Off at launch: turn it on once exchange display fees are
  /// licensed and paid for, and the proxy verifies Pro before serving real-time.
  static let offersRealTime = false

  private static let realTimeKey = "marketData.realTime"

  /// Real-time prices for Pro members, when offered. Stored in the App Group so widgets and background refreshes agree.
  static var isRealTime: Bool {
    get { offersRealTime && AppGroup.defaults.bool(forKey: realTimeKey) }
    set { AppGroup.defaults.set(newValue, forKey: realTimeKey) }
  }

  static var delay: TimeInterval { isRealTime ? 0 : freeDelay }
}
