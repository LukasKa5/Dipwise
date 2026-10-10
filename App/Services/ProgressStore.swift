import Foundation
import Observation
import WidgetKit

/// Duolingo-style progress: daily streak, wisdom points (XP), levels, and counters for achievements.
@MainActor
@Observable
final class ProgressStore {
  enum Event {
    case brief
    case alertCreated
    case vote
    case journal
    case onboarding

    var points: Int {
      switch self {
      case .brief: 20
      case .alertCreated: 10
      case .vote: 5
      case .journal: 15
      case .onboarding: 50
      }
    }
  }

  struct Gain: Equatable {
    var points: Int
    var id = UUID()
  }

  private struct Stored: Codable {
    var checkIns: Set<String> = []
    var xp = 0
    var longestStreak = 0
    var votes = 0
    var journalEntries = 0
    var alertsCreated = 0
    var briefs = 0
    var lastBrief: Date?
  }

  private static let key = "progressStore.v1"
  private var stored: Stored
  /// The most recent XP gain, for celebratory animations.
  private(set) var lastGain: Gain?

  init() {
    if let data = UserDefaults.standard.data(forKey: Self.key),
       let decoded = try? JSONDecoder().decode(Stored.self, from: data) {
      stored = decoded
    } else {
      stored = Stored()
    }
  }

  // MARK: Streak

  private static func key(for date: Date) -> String {
    date.formatted(.iso8601.year().month().day())
  }

  var streak: Int {
    let calendar = Calendar.current
    var day = Date.now
    if !isActive(on: day) {
      guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), isActive(on: yesterday) else { return 0 }
      day = yesterday
    }
    var count = 0
    while isActive(on: day) {
      count += 1
      guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
      day = previous
    }
    return count
  }

  private func isActive(on date: Date) -> Bool {
    let key = Self.key(for: date)
    return stored.checkIns.contains(key)
  }

  func wasCheckedIn(on date: Date) -> Bool { stored.checkIns.contains(Self.key(for: date)) }

  var isBriefDoneToday: Bool { stored.lastBrief.map { Calendar.current.isDateInToday($0) } ?? false }
  var longestStreak: Int { max(stored.longestStreak, streak) }

  /// Marks today as done.
  private func checkIn() {
    stored.checkIns.insert(Self.key(for: .now))
    stored.longestStreak = max(stored.longestStreak, streak)
  }

  // MARK: XP and levels

  var xp: Int { stored.xp }
  var level: Int { xp / 250 + 1 }
  var levelProgress: Double { Double(xp % 250) / 250 }
  var pointsToNextLevel: Int { 250 - xp % 250 }

  var levelTitle: String {
    let titles = ["Owlet", "Fledgling", "Night Watcher", "Sharp Eye", "Patient Hunter", "Wise Owl", "Market Sage", "Grand Owl"]
    return titles[min(level - 1, titles.count - 1)]
  }

  func record(_ event: Event) {
    stored.xp += event.points
    switch event {
    case .brief:
      stored.briefs += 1
      stored.lastBrief = .now
      checkIn()
    case .alertCreated: stored.alertsCreated += 1
    case .vote: stored.votes += 1
    case .journal: stored.journalEntries += 1
    case .onboarding: checkIn()
    }
    lastGain = Gain(points: event.points)
    save()
  }

  // MARK: Counters

  var votes: Int { stored.votes }
  var journalEntries: Int { stored.journalEntries }
  var alertsCreated: Int { stored.alertsCreated }
  var briefs: Int { stored.briefs }

  private func save() {
    UserDefaults.standard.set(try? JSONEncoder().encode(stored), forKey: Self.key)
    ProgressSnapshot(streak: streak, lastBrief: stored.lastBrief, level: level, levelTitle: levelTitle).save()
    WidgetCenter.shared.reloadAllTimelines()
    Task { await NotificationManager.scheduleBriefReminders(streak: streak, skipToday: isBriefDoneToday) }
  }
}
