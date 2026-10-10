import SwiftUI
import WidgetKit

struct NearTargetsWidgetView: View {
  var entry: TargetsEntry
  @Environment(\.widgetFamily) private var family

  var body: some View {
    Group {
      switch family {
      case .accessoryRectangular: rectangular
      case .accessoryCircular: circular
      case .accessoryInline: inline
      case .systemMedium: medium
      default: small
      }
    }
    .containerBackground(for: .widget) {
      if family == .systemSmall || family == .systemMedium {
        Brand.nightGradient
      } else {
        Color.clear
      }
    }
    .widgetURL(entry.statuses.first.map { URL(string: "dipwise://stock/\($0.target.symbol)")! } ?? URL(string: "dipwise://alerts"))
  }

  // MARK: Home Screen

  @ViewBuilder
  private var small: some View {
    if let status = entry.statuses.first {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(status.target.symbol)
            .font(.headline)
          Spacer()
          OwlMark().frame(width: 26)
        }
        Spacer(minLength: 0)
        Text(distanceText(status))
          .font(.system(size: 30, weight: .bold, design: .rounded))
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        Text("to \(status.target.rule.kind.title.lowercased())")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.65))
        WidgetTrack(progress: status.progress)
        Text(status.summary)
          .font(.caption2.weight(.semibold))
          .foregroundStyle(Brand.amber)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
      .foregroundStyle(.white)
    } else {
      emptyState
    }
  }

  @ViewBuilder
  private var medium: some View {
    if entry.statuses.isEmpty {
      emptyState
    } else {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Near your targets")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white.opacity(0.65))
          Spacer()
          OwlMark().frame(width: 20)
        }
        ForEach(entry.statuses.prefix(3)) { status in
          Link(destination: URL(string: "dipwise://stock/\(status.target.symbol)")!) {
            HStack(spacing: 10) {
              Text(status.target.symbol)
                .font(.subheadline.bold())
                .frame(width: 58, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
              WidgetTrack(progress: status.progress)
              Text(distanceText(status))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle((status.distance ?? 1) < 0.035 ? Brand.amber : .white)
                .frame(width: 58, alignment: .trailing)
            }
          }
        }
        Spacer(minLength: 0)
      }
      .foregroundStyle(.white)
    }
  }

  private var emptyState: some View {
    VStack(spacing: 8) {
      OwlMark().frame(height: 50)
      Text("Add a price target in Dipwise")
        .font(.caption.weight(.semibold))
        .multilineTextAlignment(.center)
        .foregroundStyle(.white.opacity(0.8))
    }
  }

  // MARK: Lock Screen

  @ViewBuilder
  private var rectangular: some View {
    if let status = entry.statuses.first {
      VStack(alignment: .leading, spacing: 2) {
        Text("\(status.target.symbol) · \(status.target.rule.kind.title)")
          .font(.headline)
          .widgetAccentable()
        Text(status.summary)
          .font(.subheadline)
        Gauge(value: status.progress) { EmptyView() }
          .gaugeStyle(.accessoryLinearCapacity)
      }
    } else {
      Text("No price targets")
    }
  }

  @ViewBuilder
  private var circular: some View {
    if let status = entry.statuses.first {
      Gauge(value: status.progress) {
        Text(status.target.symbol)
      } currentValueLabel: {
        Text(status.target.symbol.prefix(4))
          .minimumScaleFactor(0.5)
      }
      .gaugeStyle(.accessoryCircularCapacity)
    } else {
      Image(systemName: "scope")
    }
  }

  private var inline: some View {
    if let status = entry.statuses.first {
      Text("\(status.target.symbol) \(distanceText(status)) to target")
    } else {
      Text("Dipwise: no targets")
    }
  }

  // MARK: Helpers

  private func distanceText(_ status: TargetStatus) -> String {
    guard let distance = status.distance else { return "—" }
    return distance == 0 ? "Now" : distance.formatted(.percent.precision(.fractionLength(1)))
  }

}

private struct WidgetTrack: View {
  var progress: Double

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(.white.opacity(0.15))
        Capsule()
          .fill(LinearGradient(colors: [Brand.amber.opacity(0.4), Brand.amber], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(6, geometry.size.width * progress))
      }
    }
    .frame(height: 6)
  }
}
