import Charts
import SwiftUI

/// A tiny price line, green when up and red when down.
struct Sparkline: View {
  var values: [Double]

  var body: some View {
    let isUp = (values.last ?? 0) >= (values.first ?? 0)
    Chart(Array(values.enumerated()), id: \.offset) { index, value in
      LineMark(x: .value("Day", index), y: .value("Price", value))
        .foregroundStyle(isUp ? Palette.gain : Palette.loss)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        .interpolationMethod(.monotone)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: (values.min() ?? 0)...max(values.max() ?? 1, (values.min() ?? 0) + 0.0001))
    .accessibilityHidden(true)
  }
}
