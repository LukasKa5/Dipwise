import Charts
import SwiftUI

/// The signature Dipwise chart: a glowing line with a live-price dot, alert levels, and the owl perched at the dip.
struct DipChart: View {
  struct Level: Identifiable {
    var id = UUID()
    var price: Double
    var kind: TargetKind
    var label: String
  }

  var values: [Double]
  var lineColor: Color = Brand.mint
  var gridColor: Color = .white.opacity(0.08)
  var levels: [Level] = []
  var showsOwl = true
  var owlSize: CGFloat = 52

  private var points: [(offset: Int, element: Double)] {
    values.enumerated().map { ($0.offset, $0.element) }
  }

  private var dipIndex: Int? {
    // Perch on an interior low so the owl never sits on the live-price dot.
    guard values.count > 2 else { return nil }
    let interior = values.indices.dropFirst().dropLast()
    return interior.min { values[$0] < values[$1] }
  }

  var body: some View {
    Chart {
      ForEach(points, id: \.offset) { point in
        AreaMark(
          x: .value("Session", point.offset),
          yStart: .value("Floor", yDomain.lowerBound),
          yEnd: .value("Price", point.element)
        )
        .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.3), lineColor.opacity(0)], startPoint: .top, endPoint: .bottom))
        .interpolationMethod(.monotone)

        LineMark(x: .value("Session", point.offset), y: .value("Price", point.element))
          .foregroundStyle(lineColor)
          .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
          .interpolationMethod(.monotone)
          .shadow(color: lineColor.opacity(0.6), radius: 6)
      }

      ForEach(levels) { level in
        RuleMark(y: .value("Target", level.price))
          .foregroundStyle(Palette.amber.opacity(0.9))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
          .annotation(position: .top, alignment: .leading, spacing: 2) {
            Label(level.label, systemImage: level.kind.systemImage)
              .font(.caption2.bold())
              .foregroundStyle(Palette.amber)
              .labelStyle(.titleAndIcon)
          }
      }

      if let last = points.last {
        PointMark(x: .value("Session", last.offset), y: .value("Price", last.element))
          .symbolSize(420)
          .foregroundStyle(lineColor.opacity(0.22))
        PointMark(x: .value("Session", last.offset), y: .value("Price", last.element))
          .symbolSize(110)
          .foregroundStyle(lineColor)
        PointMark(x: .value("Session", last.offset), y: .value("Price", last.element))
          .symbolSize(24)
          .foregroundStyle(.white)
      }
    }
    .chartYScale(domain: yDomain)
    .chartXScale(domain: -0.5...(Double(max(points.count - 1, 1)) + 0.6))
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) {
        AxisGridLine().foregroundStyle(gridColor)
      }
    }
    .chartOverlay { proxy in
      GeometryReader { geometry in
        if showsOwl, let index = dipIndex,
           let plotFrame = proxy.plotFrame,
           let position = proxy.position(for: (x: index, y: values[index])) {
          let origin = geometry[plotFrame].origin
          OwlMark()
            .frame(width: owlSize, height: owlSize * 1.13)
            .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
            .position(x: origin.x + position.x, y: origin.y + position.y - owlSize * 0.53)
        }
      }
    }
    .accessibilityElement()
    .accessibilityLabel("Price chart")
    .accessibilityValue(summary)
  }

  private var yDomain: ClosedRange<Double> {
    let all = values + levels.map(\.price)
    guard let low = all.min(), let high = all.max(), low < high else {
      let value = values.first ?? 1
      return (value * 0.95)...(value * 1.05)
    }
    let range = high - low
    let headroom = showsOwl ? range * 0.55 : range * 0.15
    return (low - range * 0.18)...(high + headroom)
  }

  private var summary: String {
    guard let first = values.first, let last = values.last, let low = values.min() else { return "" }
    let change = (last / first - 1).formatted(.percent.precision(.fractionLength(1)))
    return "Changed \(change) over the period. Low \(low.formatted(.number.precision(.fractionLength(2)))), now \(last.formatted(.number.precision(.fractionLength(2))))."
  }
}
