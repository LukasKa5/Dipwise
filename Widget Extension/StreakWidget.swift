import SwiftUI
import WidgetKit

/// Dippy with your streak and whether today's brief is done.
struct StreakWidget: Widget {
  let kind = "StreakWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
      StreakWidgetView(entry: entry)
    }
    .configurationDisplayName("Streak")
    .description("Your daily brief streak, with Dippy the owl.")
    .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
  }
}

struct StreakEntry: TimelineEntry {
  var date: Date
  var progress: ProgressSnapshot
}

struct StreakProvider: TimelineProvider {
  func placeholder(in context: Context) -> StreakEntry {
    StreakEntry(date: .now, progress: ProgressSnapshot(streak: 12, lastBrief: nil, level: 3, levelTitle: "Night Watcher"))
  }

  func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
    completion(StreakEntry(date: .now, progress: ProgressSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
    // A new pose for Dippy every few minutes, and a refresh after midnight so "done today" resets.
    let progress = ProgressSnapshot.load()
    let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400)).addingTimeInterval(60)
    let dates = WidgetData.livingDates(count: 24).filter { $0 < tomorrow }
    let entries = dates.map { StreakEntry(date: $0, progress: progress) }
    completion(Timeline(entries: entries, policy: .after(min(tomorrow, dates.last.map { $0.addingTimeInterval(WidgetData.rotation) } ?? tomorrow))))
  }
}

struct StreakWidgetView: View {
  var entry: StreakEntry
  var isPreview = false
  @Environment(\.widgetFamily) private var family

  private var progress: ProgressSnapshot { entry.progress }
  /// A streak still counts until the end of the day after the last brief.
  private var liveStreak: Int {
    guard let last = progress.lastBrief else { return 0 }
    let calendar = Calendar.current
    return calendar.isDateInToday(last) || calendar.isDateInYesterday(last) ? progress.streak : 0
  }

  var body: some View {
    Group {
      switch family {
      case .accessoryCircular:
        VStack(spacing: 0) {
          Image(systemName: "flame.fill")
          Text("\(liveStreak)").font(.headline)
        }
        .widgetAccentable()
      case .accessoryInline:
        Text("\(liveStreak)-day streak \(progress.briefDoneToday ? "· done" : "· brief ready")")
      default:
        small
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(URL(string: "dipwise://brief"))
  }

  /// Dippy sleeps at night like a real owl.
  private var isNight: Bool {
    let hour = Calendar.current.component(.hour, from: entry.date)
    return hour >= 22 || hour < 6
  }

  private var small: some View {
    let done = progress.briefDoneToday
    return VStack(spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Image(systemName: "flame.fill")
          .font(.subheadline)
          .foregroundStyle(liveStreak > 0 ? Brand.amber : .white.opacity(0.4))
        Text("\(liveStreak)")
          .font(.system(size: 22, weight: .bold, design: .rounded))
          .contentTransition(.numericText())
        Text(liveStreak == 1 ? "day" : "days")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.7))
        Spacer(minLength: 0)
      }
      Spacer(minLength: 0)
      WidgetOwl(size: 58, isAsleep: isPreview ? false : isNight && !done, pose: done ? .cheer : DippyPose.at(entry.date))
      Spacer(minLength: 4)
      weekDots
        .padding(.bottom, 5)
      Text(done ? "Brief done · see you tomorrow" : "Your brief is ready · 1 min")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(done ? Brand.buy : Brand.amber)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
  }

  /// The last seven days, filled for each day of the current streak.
  private var weekDots: some View {
    let filled = min(liveStreak, 7)
    return HStack(spacing: 5) {
      ForEach(0..<7, id: \.self) { day in
        Circle()
          .fill(day >= 7 - filled ? Brand.amber : .white.opacity(0.18))
          .frame(width: 7, height: 7)
      }
    }
    .accessibilityElement()
    .accessibilityLabel("\(liveStreak)-day streak")
  }
}
