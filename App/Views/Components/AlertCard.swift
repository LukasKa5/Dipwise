import SwiftUI

/// One alert with its progress track and distance.
struct AlertCard: View {
  var alert: PriceAlert
  var quote: Quote?

  private var distance: Double? { quote.flatMap { alert.distance(for: $0) } }
  private var isClose: Bool { (distance ?? 1) < 0.035 }
  private var tint: Color { alert.kind.side == .sell ? Palette.green : Palette.amber }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 12) {
        TickerBadge(symbol: alert.symbol)
        VStack(alignment: .leading, spacing: 2) {
          Text(alert.symbol)
            .font(.headline)
          Text(alert.holding?.name ?? "")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Spacer()
        if let quote {
          VStack(alignment: .trailing, spacing: 2) {
            Text(quote.formatted(quote.price))
              .font(.headline)
              .monospacedDigit()
            ChangeBadge(change: quote.change)
              .font(.caption)
          }
        }
      }

      TargetTrack(progress: quote.map { alert.progress(for: $0) } ?? 0, isReached: !alert.isActive || distance == 0, tint: tint)

      HStack {
        Label(alert.summary(for: quote), systemImage: alert.kind.systemImage)
          .foregroundStyle(tint)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
        Spacer()
        status
      }
      .font(.footnote.weight(.semibold))

      if let depth = quote.flatMap({ alert.rule.zoneDepth(for: $0) }) {
        Text("Inside the zone · \(depth, format: .percent.precision(.fractionLength(0))) of the way through")
          .font(.caption.weight(.semibold))
          .foregroundStyle(tint)
      }

      if let shares = alert.plannedShares, let quote {
        Text("Plan: invest \(quote.formatted(alert.budget)) ≈ \(shares, format: .number.precision(.fractionLength(0...2))) shares")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      if !alert.note.isEmpty {
        Text("\u{201C}\(alert.note)\u{201D}")
          .font(.footnote)
          .italic()
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
    }
    .padding(18)
    .cardStyle()
    .contentShape(.rect)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(alert.holding?.name ?? alert.symbol), \(alert.summary(for: quote))")
    .accessibilityValue(distance.map { $0 == 0 ? "Reached" : "\($0.formatted(.percent.precision(.fractionLength(1)))) away" } ?? "")
  }

  @ViewBuilder
  private var status: some View {
    if !alert.isActive {
      Text(alert.isExpired ? "Expired" : "Reached")
        .foregroundStyle(.secondary)
    } else if distance == 0 {
      Text("Active now")
        .font(.caption.bold())
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15), in: .capsule)
    } else if isClose {
      Text("Almost there")
        .font(.caption.bold())
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.15), in: .capsule)
    } else if let distance {
      Text("\(distance, format: .percent.precision(.fractionLength(1))) away")
        .foregroundStyle(.secondary)
    }
  }
}
