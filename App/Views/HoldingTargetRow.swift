import SwiftUI

struct HoldingTargetRow: View {
  var holding: Holding

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        TickerBadge(symbol: holding.symbol)
        VStack(alignment: .leading, spacing: 2) {
          Text(holding.symbol)
            .font(.headline)
          Text(holding.name)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(holding.price, format: .currency(code: "USD"))
            .font(.headline)
            .monospacedDigit()
          ChangeBadge(change: holding.dayChange)
            .font(.caption)
        }
      }

      TargetTrack(progress: holding.targetProgress)

      HStack {
        Label(holding.targetDescription, systemImage: holding.targetKind == .buyBelow ? "arrow.down.to.line" : "arrow.up.to.line")
          .foregroundStyle(Palette.amber)
        Spacer()
        if holding.isNearTarget {
          Text("Almost there")
            .font(.caption.bold())
            .foregroundStyle(Palette.amber)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Palette.amber.opacity(0.15), in: .capsule)
        } else {
          Text("\(holding.distanceToTarget, format: .percent.precision(.fractionLength(1))) away")
            .foregroundStyle(.secondary)
        }
      }
      .font(.footnote.weight(.semibold))
    }
    .padding(18)
    .cardStyle()
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(holding.name), \(holding.price.formatted(.currency(code: "USD")))")
    .accessibilityValue("\(holding.targetDescription), \(holding.distanceToTarget.formatted(.percent.precision(.fractionLength(1)))) away")
  }
}

/// A track showing how close the price is to its target, ending in an amber target marker.
private struct TargetTrack: View {
  var progress: Double

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width - 22
      ZStack(alignment: .leading) {
        Capsule()
          .fill(.quaternary)
          .frame(height: 8)
        Capsule()
          .fill(LinearGradient(colors: [Palette.amber.opacity(0.35), Palette.amber], startPoint: .leading, endPoint: .trailing))
          .frame(width: max(8, width * progress + 11), height: 8)
        Circle()
          .fill(Palette.card)
          .stroke(Palette.amber, lineWidth: 3)
          .frame(width: 16, height: 16)
          .offset(x: width * progress + 3)
        Image(systemName: "scope")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(Palette.amber)
          .frame(width: 22, height: 22)
          .offset(x: width)
      }
      .frame(maxHeight: .infinity)
    }
    .frame(height: 22)
    .accessibilityHidden(true)
  }
}

private struct TickerBadge: View {
  var symbol: String

  var body: some View {
    Text(symbol.prefix(1))
      .font(.title3.bold())
      .foregroundStyle(Palette.mint)
      .frame(width: 44, height: 44)
      .background(Palette.nightGradient, in: .rect(cornerRadius: 13))
  }
}
