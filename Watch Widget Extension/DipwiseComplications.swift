import SwiftUI
import WidgetKit

@main
struct DipwiseComplications: WidgetBundle {
  var body: some Widget {
    NearestPlanComplication()
    StreakComplication()
  }
}

struct PlanEntry: TimelineEntry {
  var date: Date
  var status: TargetStatus?
}

struct PlanProvider: TimelineProvider {
  func placeholder(in context: Context) -> PlanEntry {
    PlanEntry(date: .now, status: TargetStatus(
      target: WatchedTarget(id: UUID(), symbol: "NVDA", name: "NVIDIA", rule: AlertRule(kind: .buyZone, lower: 170, upper: 178)),
      quote: Quote(symbol: "NVDA", name: "NVIDIA", currency: "USD", price: 182.4, previousClose: 180, closes: [], updatedAt: .now)
    ))
  }

  func getSnapshot(in context: Context, completion: @escaping (PlanEntry) -> Void) {
    let status = TargetStatus.sorted(targets: TargetSnapshotStore.loadTargets(), quotes: TargetSnapshotStore.loadQuotes()).first
    completion(status == nil && context.isPreview ? placeholder(in: context) : PlanEntry(date: .now, status: status))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<PlanEntry>) -> Void) {
    Task {
      let targets = TargetSnapshotStore.loadTargets()
      var quotes = TargetSnapshotStore.loadQuotes()
      let fresh = await QuoteService().quotes(for: targets.map(\.symbol))
      if !fresh.isEmpty {
        quotes.merge(fresh) { _, new in new }
        TargetSnapshotStore.save(quotes: quotes)
      }
      let entry = PlanEntry(date: .now, status: TargetStatus.sorted(targets: targets, quotes: quotes).first)
      completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
    }
  }
}

/// The alert closest to triggering, on the watch face.
struct NearestPlanComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "NearestPlanComplication", provider: PlanProvider()) { entry in
      NearestPlanView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Nearest Plan")
    .description("The stock closest to your buy or sell zone.")
    .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
  }
}

private struct NearestPlanView: View {
  var entry: PlanEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    if let status = entry.status {
      let color = status.target.rule.kind.side.brandColor
      let distance = status.distance.map { $0 == 0 ? "Now" : $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—"
      switch family {
      case .accessoryRectangular:
        VStack(alignment: .leading, spacing: 2) {
          Text("\(status.target.symbol) · \(distance)")
            .font(.headline)
            .widgetAccentable()
          Text(status.summary)
            .font(.caption2)
            .lineLimit(1)
          Gauge(value: status.progress) { EmptyView() }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(color)
        }
      case .accessoryInline:
        Text("\(status.target.symbol) \(distance) to \(status.target.rule.kind.title.lowercased())")
      case .accessoryCorner:
        Text(status.target.symbol)
          .widgetCurvesContent()
          .widgetLabel {
            Gauge(value: status.progress) { Text(status.target.symbol) }
              .tint(color)
          }
      default:
        Gauge(value: status.progress) {
          Text(status.target.symbol)
        } currentValueLabel: {
          Text(status.target.symbol.prefix(4)).minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(color)
      }
    } else {
      Image(systemName: "scope")
    }
  }
}

struct StreakEntry: TimelineEntry {
  var date: Date
  var progress: ProgressSnapshot
}

struct StreakProvider: TimelineProvider {
  func placeholder(in context: Context) -> StreakEntry {
    StreakEntry(date: .now, progress: ProgressSnapshot(streak: 12, lastBrief: .now, level: 3, levelTitle: "Night Watcher"))
  }

  func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
    completion(StreakEntry(date: .now, progress: ProgressSnapshot.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
    let tomorrow = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400)).addingTimeInterval(60)
    completion(Timeline(entries: [StreakEntry(date: .now, progress: ProgressSnapshot.load())], policy: .after(tomorrow)))
  }
}

/// Your daily brief streak on the watch face.
struct StreakComplication: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "StreakComplication", provider: StreakProvider()) { entry in
      VStack(spacing: 0) {
        Image(systemName: "flame.fill")
          .foregroundStyle(entry.progress.briefDoneToday ? Brand.amber : .secondary)
        Text("\(entry.progress.streak)")
          .font(.headline)
      }
      .widgetAccentable()
      .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("Streak")
    .description("Your Dipwise daily brief streak.")
    .supportedFamilies([.accessoryCircular])
  }
}
