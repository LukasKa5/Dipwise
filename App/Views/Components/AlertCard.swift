import SwiftUI

/// One price target with its progress track and distance.
struct AlertCard: View {
  var alert: PriceAlert
  var quote: Quote?

  private var distance: Double? { quote.map { alert.distance(from: $0.price) } }
  private var isClose: Bool { (distance ?? 1) < 0.035 }

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

      TargetTrack(progress: quote.map { alert.progress(from: $0.price) } ?? 0, isReached: !alert.isActive)

      HStack {
        Label("\(alert.kind.title) \(quote?.formatted(alert.targetPrice) ?? alert.targetPrice.formatted())", systemImage: alert.kind.systemImage)
          .foregroundStyle(Palette.amber)
        Spacer()
        if !alert.isActive {
          Text("Reached")
            .foregroundStyle(Palette.amber)
        } else if isClose {
          Text("Almost there")
            .font(.caption.bold())
            .foregroundStyle(Palette.amber)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Palette.amber.opacity(0.15), in: .capsule)
        } else if let distance {
          Text("\(distance, format: .percent.precision(.fractionLength(1))) away")
            .foregroundStyle(.secondary)
        }
      }
      .font(.footnote.weight(.semibold))

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
    .accessibilityLabel("\(alert.holding?.name ?? alert.symbol), \(alert.kind.title) \(alert.targetPrice.formatted())")
    .accessibilityValue(distance.map { "\($0.formatted(.percent.precision(.fractionLength(1)))) away" } ?? "")
  }
}
