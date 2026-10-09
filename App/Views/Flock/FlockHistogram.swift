import Charts
import SwiftUI

/// Where the flock's alerts sit relative to today's price.
struct FlockHistogram: View {
  var stats: FlockStats
  var userTargets: [Double] = []

  var body: some View {
    Chart {
      ForEach(stats.bins) { bin in
        BarMark(x: .value("Distance", bin.midOffset), y: .value("Alerts", bin.buyCount), width: .ratio(0.8))
          .foregroundStyle(by: .value("Type", "Buy"))
          .cornerRadius(3)
        BarMark(x: .value("Distance", bin.midOffset), y: .value("Alerts", bin.sellCount), width: .ratio(0.8))
          .foregroundStyle(by: .value("Type", "Sell"))
          .cornerRadius(3)
      }
      RuleMark(x: .value("Distance", 0))
        .foregroundStyle(.primary.opacity(0.6))
        .lineStyle(StrokeStyle(lineWidth: 1.5))
        .annotation(position: .top) {
          Text("Now")
            .font(.caption2.bold())
            .foregroundStyle(.secondary)
        }
      ForEach(userTargets, id: \.self) { target in
        RuleMark(x: .value("Distance", target / stats.currentPrice - 1))
          .foregroundStyle(Palette.green)
          .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 3]))
          .annotation(position: .top) {
            Image(systemName: "person.fill")
              .font(.caption2.bold())
              .foregroundStyle(.white)
              .padding(4)
              .background(Palette.green, in: .circle)
              .accessibilityLabel("Your target")
          }
      }
    }
    .chartForegroundStyleScale(["Buy": Palette.amber, "Sell": Palette.green])
    .chartXScale(domain: FlockStats.offsetRange)
    .chartXAxis {
      AxisMarks(values: [-0.3, -0.2, -0.1, 0, 0.1, 0.2, 0.3]) { value in
        AxisGridLine()
        AxisValueLabel {
          if let offset = value.as(Double.self) {
            Text(offset, format: .percent.precision(.fractionLength(0)).sign(strategy: offset == 0 ? .never : .always()))
          }
        }
      }
    }
    .chartLegend(position: .bottom, alignment: .leading)
    .accessibilityElement()
    .accessibilityLabel("Distribution of flock alerts")
    .accessibilityValue("\(stats.buyTargets.count) buy targets below the price and \(stats.sellTargets.count) sell targets above it.")
  }
}
