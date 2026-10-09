import SwiftUI

struct HoldingTargetRow: View {
  var holding: Holding

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
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

      VStack(alignment: .leading, spacing: 8) {
        ProgressView(value: holding.targetProgress)
          .tint(Palette.amber)
          .accessibilityLabel("Progress toward target")
        HStack {
          Label(targetDescription, systemImage: holding.targetKind == .buyBelow ? "arrow.down.to.line" : "arrow.up.to.line")
            .foregroundStyle(Palette.amber)
          Spacer()
          Text("\(holding.distanceToTarget, format: .percent.precision(.fractionLength(1))) away")
            .foregroundStyle(.secondary)
        }
        .font(.footnote.weight(.semibold))
      }
    }
    .padding(18)
    .background(Palette.card, in: .rect(cornerRadius: 22))
    .accessibilityElement(children: .combine)
  }

  private var targetDescription: String {
    let price = holding.target.formatted(.currency(code: "USD"))
    switch holding.targetKind {
    case .buyBelow: return "Buy below \(price)"
    case .sellAbove: return "Sell above \(price)"
    }
  }
}
