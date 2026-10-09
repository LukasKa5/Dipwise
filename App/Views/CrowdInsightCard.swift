import SwiftUI

struct CrowdInsightCard: View {
  var insight: CrowdInsight

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text(insight.symbol)
          .font(.headline)
        Spacer()
        Image(systemName: "person.3.fill")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 14) {
        ZStack {
          Circle()
            .stroke(Palette.green.opacity(0.15), lineWidth: 8)
          Circle()
            .trim(from: 0, to: insight.holdersWithTarget)
            .stroke(Palette.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
            .rotationEffect(.degrees(-90))
          Text(insight.holdersWithTarget, format: .percent.precision(.fractionLength(0)))
            .font(.subheadline.bold())
            .monospacedDigit()
        }
        .frame(width: 64, height: 64)

        VStack(alignment: .leading, spacing: 2) {
          Text("Median target")
            .font(.caption)
            .foregroundStyle(.secondary)
          Text(insight.medianTarget, format: .currency(code: "USD"))
            .font(.title3.bold())
            .foregroundStyle(Palette.amber)
        }
      }

      Text(insight.summary)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 0)
    }
    .padding(18)
    .frame(width: 260, alignment: .leading)
    .frame(maxHeight: .infinity, alignment: .top)
    .cardStyle()
    .accessibilityElement(children: .combine)
  }
}
