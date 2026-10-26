import SwiftUI
import WidgetKit

/// Where the flock plans to buy: the stocks every Dipwise investor is waiting on, their shared buy zone, how close
/// the price is, and how eager the crowd is.
struct FlockZonesWidget: Widget {
  let kind = "FlockZonesWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: FlockWidgetProvider()) { entry in
      FlockZonesWidgetView(entry: entry)
    }
    .configurationDisplayName("Flock Buy Zones")
    .description("The stocks the flock is waiting to buy, their shared buy zone, and how close the price is.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

/// The flock's mood this week: how many investors lean bullish, and which stocks they're setting alerts on.
struct FlockMoodWidget: Widget {
  let kind = "FlockMoodWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: FlockWidgetProvider()) { entry in
      FlockMoodWidgetView(entry: entry)
    }
    .configurationDisplayName("Flock Mood")
    .description("How bullish the flock is this week, and the stocks everyone is setting alerts on.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct FlockWidgetEntry: TimelineEntry {
  var date: Date
  var snapshot: FlockSnapshot?
}

struct FlockWidgetProvider: TimelineProvider {
  func placeholder(in context: Context) -> FlockWidgetEntry {
    FlockWidgetEntry(date: .now, snapshot: .sample)
  }

  func getSnapshot(in context: Context, completion: @escaping (FlockWidgetEntry) -> Void) {
    completion(FlockWidgetEntry(date: .now, snapshot: FlockSnapshot.load() ?? (context.isPreview ? .sample : nil)))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<FlockWidgetEntry>) -> Void) {
    // The app saves a fresh snapshot whenever it hears from the flock, and reloads these widgets.
    let entry = FlockWidgetEntry(date: .now, snapshot: FlockSnapshot.load())
    completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(WidgetData.refresh * 2))))
  }
}

// MARK: - Buy zones

struct FlockZonesWidgetView: View {
  var entry: FlockWidgetEntry
  /// Lets the app preview a specific size.
  var previewFamily: WidgetFamily?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { previewFamily ?? environmentFamily }
  private var isPreview: Bool { previewFamily != nil }

  var body: some View {
    Group {
      if let snapshot = entry.snapshot, let top = snapshot.picks.first {
        switch family {
        case .systemSmall: small(top)
        default: list(snapshot, rows: family == .systemLarge ? 5 : 3)
        }
      } else {
        FlockWidgetEmpty(isPreview: isPreview)
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(URL(string: "dipwise://flock"))
  }

  private func small(_ pick: FlockSnapshot.Pick) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      WidgetHeader("Flock buys", isPreview: isPreview)
      Spacer(minLength: 2)
      HStack(spacing: 6) {
        WidgetBadge(symbol: pick.symbol, size: 22)
        Text(pick.symbol)
          .font(.subheadline.bold())
          .lineLimit(1)
      }
      Text(pick.isInZone ? String(localized: "In zone") : distanceText(pick.distance))
        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(pick.isInZone ? Brand.buy : .white)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(pick.isInZone ? "Inside the flock's buy zone" : "to the flock's buy zone")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Brand.buy)
        .lineLimit(2)
        .minimumScaleFactor(0.5)
      Spacer(minLength: 4)
      FlockZoneRuler(pick: pick)
      Text("\(pick.watchers) waiting")
        .font(.caption2.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
        .padding(.top, 5)
    }
  }

  private func list(_ snapshot: FlockSnapshot, rows: Int) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      WidgetHeader("Where the flock buys", isPreview: isPreview)
        .padding(.bottom, family == .systemLarge ? 10 : 6)
      VStack(spacing: family == .systemLarge ? 6 : 4) {
        ForEach(snapshot.picks.prefix(rows)) { pick in
          Link(destination: URL(string: "dipwise://stock/\(pick.symbol)")!) {
            row(pick)
          }
        }
      }
      .frame(maxHeight: .infinity, alignment: .top)
      if family == .systemLarge {
        Text("\(snapshot.investors.formatted()) investors in the flock · anonymous")
          .font(.caption2.weight(.medium))
          .foregroundStyle(.white.opacity(0.55))
          .padding(.top, 8)
      }
    }
  }

  private func row(_ pick: FlockSnapshot.Pick) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 8) {
        WidgetBadge(symbol: pick.symbol, size: 24)
        VStack(alignment: .leading, spacing: 1) {
          Text(pick.symbol)
            .font(.caption.bold())
            .lineLimit(1)
          Text("Flock buys \(compactPrice(pick.zoneLower, currency: pick.currency))–\(compactPrice(pick.zoneUpper, currency: pick.currency))")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Brand.buy)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        Spacer(minLength: 4)
        VStack(alignment: .trailing, spacing: 0) {
          Text(pick.isInZone ? String(localized: "In zone") : distanceText(pick.distance))
            .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
            .foregroundStyle(pick.isInZone ? Brand.buy : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
          Text("\(pick.conviction)% eager")
            .font(.caption2.weight(.medium))
            .foregroundStyle(.white.opacity(0.55))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
        }
        .fixedSize()
      }
      if family == .systemLarge {
        FlockZoneRuler(pick: pick)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, family == .systemLarge ? 9 : 0)
    .frame(maxHeight: .infinity)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 11, style: .continuous))
  }
}

/// The flock's buy zone as a band on a short ruler, with today's price as a dot, like your own plans.
struct FlockZoneRuler: View {
  var pick: FlockSnapshot.Pick

  var body: some View {
    ZoneRuler(status: TargetStatus(
      target: WatchedTarget(id: UUID(), symbol: pick.symbol, name: pick.name, rule: AlertRule(kind: .buyZone, lower: pick.zoneLower, upper: pick.zoneUpper)),
      quote: Quote(symbol: pick.symbol, name: pick.name, currency: pick.currency, price: pick.price, previousClose: pick.price, closes: [], updatedAt: .now)
    ))
  }
}

// MARK: - Mood

struct FlockMoodWidgetView: View {
  var entry: FlockWidgetEntry
  /// Lets the app preview a specific size.
  var previewFamily: WidgetFamily?
  @Environment(\.widgetFamily) private var environmentFamily
  private var family: WidgetFamily { previewFamily ?? environmentFamily }
  private var isPreview: Bool { previewFamily != nil }

  var body: some View {
    Group {
      if let snapshot = entry.snapshot {
        if family == .systemMedium {
          HStack(spacing: 14) {
            mood(snapshot)
            trending(snapshot)
          }
        } else {
          mood(snapshot)
        }
      } else {
        FlockWidgetEmpty(isPreview: isPreview)
      }
    }
    .foregroundStyle(.white)
    .dipwiseWidgetBackground()
    .widgetURL(URL(string: "dipwise://flock"))
  }

  private func mood(_ snapshot: FlockSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      if family == .systemMedium {
        WidgetTitle(text: "Flock mood").frame(height: 24)
      } else {
        WidgetHeader("Flock mood", isPreview: isPreview)
      }
      Spacer(minLength: 2)
      Text(snapshot.bullShare, format: .percent.precision(.fractionLength(0)))
        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(snapshot.bullShare >= 0.5 ? Brand.buy : Brand.sell)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(snapshot.bullShare >= 0.5 ? "of the flock is bullish" : "of the flock is bearish")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.white.opacity(0.75))
        .lineLimit(2)
        .minimumScaleFactor(0.5)
      Spacer(minLength: 6)
      GeometryReader { geometry in
        HStack(spacing: 3) {
          Capsule().fill(Brand.buy).frame(width: max(6, (geometry.size.width - 3) * snapshot.bullShare))
          Capsule().fill(Brand.sell)
        }
      }
      .frame(height: 8)
      Text("\(snapshot.investors.formatted()) investors")
        .font(.caption2.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
        .padding(.top, 5)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func trending(_ snapshot: FlockSnapshot) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      WidgetHeader("Trending", isPreview: isPreview)
      ForEach(snapshot.trending.prefix(3)) { trend in
        HStack(spacing: 7) {
          WidgetBadge(symbol: trend.symbol, size: 22)
          VStack(alignment: .leading, spacing: 0) {
            Text(trend.symbol)
              .font(.caption.bold())
              .lineLimit(1)
            Text("\(trend.alertsThisWeek) alerts")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.6))
              .lineLimit(1)
              .minimumScaleFactor(0.5)
          }
          Spacer(minLength: 2)
          Text(trend.buyShare, format: .percent.precision(.fractionLength(0)))
            .font(.caption2.weight(.bold).monospacedDigit())
            .foregroundStyle(trend.buyShare >= 0.5 ? Brand.buy : Brand.sell)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background((trend.buyShare >= 0.5 ? Brand.buy : Brand.sell).opacity(0.18), in: .capsule)
            .fixedSize()
        }
        .frame(maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// Before the app has heard from the flock.
private struct FlockWidgetEmpty: View {
  var isPreview: Bool

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: -6) {
        WidgetOwl(size: 26, isAsleep: isPreview ? false : nil)
        WidgetOwl(size: 34, isAsleep: isPreview ? false : nil)
        WidgetOwl(size: 26, isAsleep: isPreview ? false : nil)
      }
      Text("Open Dipwise to see what the flock is doing.")
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .foregroundStyle(.white.opacity(0.75))
    }
  }
}
