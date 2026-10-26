import Foundation

enum AppGroup {
  static let id = "group.app.bitrig.lukaskaniansky.dipwise"

  static var defaults: UserDefaults {
    UserDefaults(suiteName: id) ?? .standard
  }
}
