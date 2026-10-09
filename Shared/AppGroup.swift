import Foundation

enum AppGroup {
  static let id = "group.app.bitrig.new.15b8fdf3-82a6-4223-97a2-c5cc5f8ba55e"

  static var defaults: UserDefaults {
    UserDefaults(suiteName: id) ?? .standard
  }
}
