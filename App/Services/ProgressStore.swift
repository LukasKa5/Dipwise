import Foundation
import Observation
import WidgetKit

/// Duolingo-style progress: daily streak with freezes, wisdom points (XP), levels, and counters for achievements.
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
    var frozenDays: Set<String> = []
    var xp = 0
    var freezes = 0
    var freezeRefillMonth = ""
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
    return stored.checkIns.contains(key) || stored.frozenDays.contains(key)
  }

  func wasCheckedIn(on date: Date) -> Bool { stored.checkIns.contains(Self.key(for: date)) }
  func wasFrozen(on date: Date) -> Bool { stored.frozenDays.contains(Self.key(for: date)) }

  var isBriefDoneToday: Bool { stored.lastBrief.map { Calendar.current.isDateInToday($0) } ?? false }
  var longestStreak: Int { max(stored.longestStreak, streak) }
  var freezes: Int { stored.freezes }

  /// Marks today as done. A missed day is covered by a streak freeze when one is available.
  private func checkIn(isPro: Bool) {
    let calendar = Calendar.current
    let today = Date.now
    refillFreezes(isPro: isPro)
    if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
       let dayBefore = calendar.date(byAdding: .day, value: -2, to: today),
       !isActive(on: yesterday), isActive(on: dayBefore), stored.freezes > 0 {
      stored.freezes -= 1
      stored.frozenDays.insert(Self.key(for: yesterday))
    }
    let wasNew = stored.checkIns.insert(Self.key(for: today)).inserted
    if wasNew, streak > 0, streak.isMultiple(of: 7) {
      // Every week of streak earns a freeze, up to two.
      stored.freezes = min(2, stored.freezes + 1)
    }
    stored.longestStreak = max(stored.longestStreak, streak)
  }

  private func refillFreezes(isPro: Bool) {
    let month = Date.now.formatted(.dateTime.year().month(.twoDigits))
    if isPro, stored.freezeRefillMonth != month {
      stored.freezes = 2
      stored.freezeRefillMonth = month
    }
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

  func record(_ event: Event, isPro: Bool = AlertSettings.isPro) {
    stored.xp += event.points
    switch event {
    case .brief:
      stored.briefs += 1
      stored.lastBrief = .now
      checkIn(isPro: isPro)
    case .alertCreated: stored.alertsCreated += 1
    case .vote: stored.votes += 1
    case .journal: stored.journalEntries += 1
    case .onboarding: checkIn(isPro: isPro)
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
