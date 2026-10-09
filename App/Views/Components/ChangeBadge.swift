import SwiftUI

struct ChangeBadge: View {
  var change: Double
  var caption: String? = nil
  var positiveColor: Color = Palette.green
  var negativeColor: Color = Palette.loss

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
        .font(.caption.weight(.heavy))
      Text(change, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
        .monospacedDigit()
      if let caption {
        Text(caption)
          .foregroundStyle(.secondary)
      }
    }
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(change >= 0 ? positiveColor : negativeColor)
    .accessibilityElement(children: .combine)
  }
}
