import Charts
import SwiftUI

struct PortfolioSummaryCard: View {
  var portfolio: Portfolio

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Portfolio Value")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.secondary)
        Text(portfolio.totalValue, format: .currency(code: "USD"))
          .font(.system(.largeTitle, design: .rounded, weight: .bold))
          .contentTransition(.numericText())
        ChangeBadge(change: portfolio.dayChange, caption: "today")
      }

      Chart(Array(portfolio.history.enumerated()), id: \.offset) { point in
        AreaMark(x: .value("Day", point.offset), yStart: .value("Floor", yDomain.lowerBound), yEnd: .value("Value", point.element))
          .foregroundStyle(
            LinearGradient(colors: [Palette.green.opacity(0.35), Palette.green.opacity(0)], startPoint: .top, endPoint: .bottom)
          )
          .interpolationMethod(.catmullRom)
        LineMark(x: .value("Day", point.offset), y: .value("Value", point.element))
          .foregroundStyle(Palette.green)
          .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
          .interpolationMethod(.catmullRom)
      }
      .chartYScale(domain: yDomain)
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .frame(height: 120)
      .accessibilityLabel("Portfolio value over the last 10 days")
    }
    .padding(20)
    .background(Palette.card, in: .rect(cornerRadius: 28))
  }

  private var yDomain: ClosedRange<Double> {
    let values = portfolio.history
    guard let low = values.min(), let high = values.max(), low < high else { return 0...1 }
    let padding = (high - low) * 0.15
    return (low - padding)...(high + padding)
  }
}

struct ChangeBadge: View {
  var change: Double
  var caption: String? = nil

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
        .font(.caption.bold())
      Text(change, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
      if let caption {
        Text(caption)
          .foregroundStyle(.secondary)
      }
    }
    .font(.subheadline.weight(.semibold))
    .foregroundStyle(change >= 0 ? Palette.green : .red)
  }
}
