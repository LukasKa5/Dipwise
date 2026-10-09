import SwiftUI

struct CrowdInsightCard: View {
  var insight: CrowdInsight

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Gauge(value: insight.holdersWithTarget) {
        Text(insight.symbol)
      } currentValueLabel: {
        Text(insight.holdersWithTarget, format: .percent.precision(.fractionLength(0)))
          .font(.caption.bold())
      }
      .gaugeStyle(.accessoryCircularCapacity)
      .tint(Palette.green)

      VStack(alignment: .leading, spacing: 4) {
        Text(insight.symbol)
          .font(.headline)
        Text(insight.summary)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        Text("Median target \(insight.medianTarget, format: .currency(code: "USD"))")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Palette.amber)
      }
      Spacer(minLength: 0)
    }
    .padding(18)
    .background(Palette.card, in: .rect(cornerRadius: 22))
    .accessibilityElement(children: .combine)
  }
}
