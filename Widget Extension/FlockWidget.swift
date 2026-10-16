import SwiftUI
import WidgetKit

/// What the flock is buying: stocks trading in the crowd's buy zone, and the crowd's mood.
struct FlockWidget: Widget {
  let kind = "FlockWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: FlockProvider()) { entry in
      FlockWidgetView(entry: entry)
    }
    .configurationDisplayName("The Flock")
    .description("Stocks the Dipwise crowd is buying right now, and how bullish everyone feels.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct FlockWidgetEntry: TimelineEntry {
  var date: Date
  var snapshot: FlockSnapshot?
  /// Which pick the small widget features; it moves on every few minutes.
  var index = 0
}

struct FlockProvider: TimelineProvider {
  func placeholder(in context: Context) -> FlockWidgetEntry {
    FlockWidgetEntry(date: .now, snapshot: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (FlockWidgetEntry) -> Void) {
    completion(FlockWidgetEntry(date: .now, snapshot: FlockSnapshot.load() ?? (context.isPreview ? .sample : nil)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FlockWidgetEntry>) -> Void) {
    Task {
      var snapshot = FlockSnapshot.load()
      // Fresh prices, so "in the crowd's zone" is true right now.
      if var current = snapshot, !current.picks.isEmpty {
        let quotes = await WidgetData.quotes(for: current.picks.map(\.symbol))
        for index in current.picks.indices {
          if let quote = quotes[current.picks[index].symbol] { current.picks[index].price = quote.price }
        }
        current.picks.sort { ($0.isInZone ? 0 : 1, -$0.conviction) < ($1.isInZone ? 0 : 1, -$1.conviction) }
        snapshot = current
      }
      let entries = WidgetData.livingDates().enumerated().map { FlockWidgetEntry(date: $1, snapshot: snapshot, index: $0) }
      completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(WidgetData.refresh))))
    }
  }
}

struct FlockWidgetView: View {
  var entry: FlockWidgetEntry
  /// Lets the app preview a specific size.
  var previewFamily: WidgetFamily?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { previewFamily ?? environmentFamily }
  private var isPreview: Bool { previewFamily != nil }

  var body: some View {
    Group {
      if let snapshot = entry.snapshot, !snapshot.picks.isEmpty {
        if family == .systemMedium { medium(snapshot) } else { small(snapshot) }
      } else {
        VStack(spacing: 8) {
          FlockOwls(date: entry.date, isPreview: isPreview)
          Text("Open Dipwise to meet the flock")
            .font(.caption.weight(.semibold))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.75))
        }
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(URL(string: "dipwise://flock"))
  }

  // MARK: Small

  private func small(_ snapshot: FlockSnapshot) -> some View {
    let pick = snapshot.picks[entry.index % snapshot.picks.count]
    return VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 6) {
        FlockOwls(date: entry.date, size: 15, isPreview: isPreview)
        Text("The flock")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white.opacity(0.8))
        Spacer(minLength: 0)
      }
      Spacer(minLength: 4)
      HStack(spacing: 6) {
        WidgetBadge(symbol: pick.symbol, size: 24)
        Text(pick.symbol)
          .font(.headline)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      Text(pick.isInZone ? "In the crowd's buy zone" : "\(pick.distance.formatted(.percent.precision(.fractionLength(1)))) above the zone")
        .font(.caption.weight(.semibold))
        .foregroundStyle(pick.isInZone ? Brand.buy : Brand.amber)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .padding(.top, 3)
      Spacer(minLength: 6)
      ConvictionBar(conviction: pick.conviction)
      HStack {
        Text("\(pick.conviction) conviction")
        Spacer(minLength: 2)
        Text("\(pick.watchers) watching")
      }
      .font(.system(size: 10, weight: .semibold).monospacedDigit())
      .foregroundStyle(.white.opacity(0.65))
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      .padding(.top, 5)
    }
    .id(pick.symbol)
    .transition(.opacity.combined(with: .scale(scale: 0.96)))
    .widgetURL(URL(string: "dipwise://stock/\(pick.symbol)"))
  }

  // MARK: Medium

  private func medium(_ snapshot: FlockSnapshot) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 6) {
        FlockOwls(date: entry.date, size: 18, isPreview: isPreview)
        Text("The flock")
          .font(.subheadline.weight(.bold))
        Text("\(snapshot.bullShare.formatted(.percent.precision(.fractionLength(0)))) bullish")
          .font(.system(.title3, design: .rounded).weight(.bold))
          .foregroundStyle(snapshot.bullShare >= 0.5 ? Brand.buy : Brand.sell)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        MoodBar(bullShare: snapshot.bullShare)
        Spacer(minLength: 0)
        Text("\(snapshot.investors.formatted()) investors")
          .font(.system(size: 10, weight: .semibold))
          .foregroundStyle(.white.opacity(0.6))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      .frame(width: 104, alignment: .leading)
      VStack(spacing: 4) {
        ForEach(snapshot.picks.prefix(3)) { pick in
          Link(destination: URL(string: "dipwise://stock/\(pick.symbol)")!) {
            HStack(spacing: 7) {
              WidgetBadge(symbol: pick.symbol, size: 22)
              VStack(alignment: .leading, spacing: 1) {
                Text(pick.symbol)
                  .font(.caption.bold())
                  .lineLimit(1)
                Text(pick.isInZone ? "In buy zone" : "\(pick.distance.formatted(.percent.precision(.fractionLength(1)))) above")
                  .font(.system(size: 10, weight: .semibold))
                  .foregroundStyle(pick.isInZone ? Brand.buy : Brand.amber)
                  .lineLimit(1)
              }
              Spacer(minLength: 2)
              ConvictionRing(conviction: pick.conviction)
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 10, style: .continuous))
          }
        }
      }
    }
  }
}

/// Three owls of the flock, each in its own pose.
private struct FlockOwls: View {
  var date: Date
  var size: CGFloat = 26
  var isPreview: Bool

  var body: some View {
    HStack(alignment: .bottom, spacing: -size * 0.25) {
      WidgetOwl(size: size * 0.8, isAsleep: isPreview ? false : nil, pose: DippyPose.at(date, seed: 4))
      LivingDippy(size: size, date: date, seed: 0, isPreview: isPreview)
        .zIndex(1)
      WidgetOwl(size: size * 0.8, isAsleep: isPreview ? false : nil, pose: DippyPose.at(date, seed: 6))
    }
  }
}

/// How eager the crowd is, as an amber bar.
private struct ConvictionBar: View {
  var conviction: Int

  var body: some View {
    WidgetTrack(progress: Double(conviction) / 100, color: Brand.amber)
      .accessibilityLabel("Crowd conviction \(conviction) out of 100")
  }
}

/// Conviction as a small ring with the score inside.
private struct ConvictionRing: View {
  var conviction: Int

  var body: some View {
    ZStack {
      Circle().stroke(.white.opacity(0.15), lineWidth: 3)
      Circle()
        .trim(from: 0, to: Double(conviction) / 100)
        .stroke(Brand.amber, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(-90))
      Text("\(conviction)")
        .font(.system(size: 9, weight: .bold, design: .rounded))
    }
    .frame(width: 26, height: 26)
    .accessibilityLabel("Conviction \(conviction)")
  }
}

/// The crowd's bullish and bearish votes as one green and red bar.
private struct MoodBar: View {
  var bullShare: Double

  var body: some View {
    GeometryReader { geometry in
      HStack(spacing: 2) {
        Capsule().fill(Brand.buy).frame(width: max(4, geometry.size.width * bullShare - 1))
        Capsule().fill(Brand.sell)
      }
    }
    .frame(height: 6)
    .accessibilityLabel("\(bullShare.formatted(.percent.precision(.fractionLength(0)))) of the flock expects stocks to rise")
  }
}
