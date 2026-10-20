import Foundation

/// Where prices come from, and how fresh they are.
///
/// Free members see prices 15 minutes late; Dipwise Pro is real-time. Delayed data is far cheaper to license, and
/// real-time is a clear reason to upgrade. In production every request goes through your own quote proxy
/// (Backend/quote-proxy), which holds the data vendor's key and caches each stock once for everyone.
enum MarketData {
  /// Your deployed quote proxy, such as https://dipwise-quotes.yourname.workers.dev. Nil reads Yahoo Finance
  /// directly, which is fine for development but not licensed for a commercial app.
  static let proxyURL: URL? = nil

  /// How late free members see prices.
  static let freeDelay: TimeInterval = 15 * 60

  private static let realTimeKey = "marketData.realTime"

  /// Real-time prices are part of Dipwise Pro. Stored in the App Group so widgets and background refreshes agree.
  static var isRealTime: Bool {
    get { AppGroup.defaults.bool(forKey: realTimeKey) }
    set { AppGroup.defaults.set(newValue, forKey: realTimeKey) }
  }

  static var delay: TimeInterval { isRealTime ? 0 : freeDelay }
}
