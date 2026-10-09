import Foundation

/// Alert preferences, read from UserDefaults so background refreshes can use them too.
enum AlertSettings {
  static let headsUpEnabledKey = "headsUpEnabled"
  static let headsUpThresholdKey = "headsUpThreshold"
  static let shareWithFlockKey = "shareWithFlock"
  static let isProKey = "isProCached"

  static var headsUpEnabled: Bool {
    UserDefaults.standard.object(forKey: headsUpEnabledKey) as? Bool ?? true
  }

  static var headsUpThreshold: Double {
    let value = UserDefaults.standard.double(forKey: headsUpThresholdKey)
    return value > 0 ? value : 0.03
  }

  static var shareWithFlock: Bool {
    UserDefaults.standard.object(forKey: shareWithFlockKey) as? Bool ?? true
  }

  static var isPro: Bool {
    UserDefaults.standard.bool(forKey: isProKey)
  }
}

enum FreeTier {
  static let maxActiveAlerts = 3
}
