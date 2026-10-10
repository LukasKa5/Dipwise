import Foundation

/// Streak and level, shared with widgets and Apple Watch.
struct ProgressSnapshot: Codable, Hashable {
  var streak: Int
  var lastBrief: Date?
  var level: Int
  var levelTitle: String

  var briefDoneToday: Bool {
    lastBrief.map { Calendar.current.isDateInToday($0) } ?? false
  }

  private static let key = "progressSnapshot"

  static func load() -> ProgressSnapshot {
    guard let data = AppGroup.defaults.data(forKey: key),
          let snapshot = try? JSONDecoder().decode(ProgressSnapshot.self, from: data) else {
      return ProgressSnapshot(streak: 0, lastBrief: nil, level: 1, levelTitle: "Owlet")
    }
    return snapshot
  }

  func save() {
    AppGroup.defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
  }
}
