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
    // Refresh after midnight so "done today" resets.
    let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400)).addingTimeInterval(60)
    completion(Timeline(entries: [StreakEntry(date: .now, progress: ProgressSnapshot.load())], policy: .after(tomorrow)))
  }
}

struct StreakWidgetView: View {
  var entry: StreakEntry
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
        VStack(alignment: .leading, spacing: 6) {
          HStack(alignment: .top) {
            WidgetOwl(size: 46)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
              Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(liveStreak > 0 ? Brand.amber : .white.opacity(0.4))
              Text("\(liveStreak)")
                .font(.system(size: 30, weight: .heavy, design: .rounded))
            }
          }
          Spacer(minLength: 0)
          Text(progress.briefDoneToday ? "Brief done" : "Brief ready")
            .font(.headline)
          Text(progress.briefDoneToday ? "See you tomorrow" : "1 minute with Dippy")
            .font(.caption)
            .foregroundStyle(progress.briefDoneToday ? .white.opacity(0.6) : Brand.amber)
        }
        .foregroundStyle(.white)
      }
    }
    .dipwiseWidgetBackground(glow: progress.briefDoneToday ? nil : Brand.amber)
    .widgetURL(URL(string: "dipwise://brief"))
  }
}
