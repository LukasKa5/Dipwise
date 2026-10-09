import Charts
import SwiftUI

/// The signature "night watch" card: portfolio value over a chart with the owl perched in the dip.
struct HeroCard: View {
  var portfolio: Portfolio

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      VStack(alignment: .leading, spacing: 6) {
        Text(DayPeriod(date: .now).greeting)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.65))
        Text(portfolio.totalValue, format: .currency(code: "USD"))
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .minimumScaleFactor(0.6)
          .lineLimit(1)
        ChangeBadge(change: portfolio.dayChange, caption: "today", positiveColor: Palette.mint)
      }

      chart

      HStack(spacing: 10) {
        HeroStat(value: "\(portfolio.holdings.count)", label: "Targets", systemImage: "scope", tint: Palette.mint)
        HeroStat(value: "\(portfolio.nearTargetCount)", label: "Close", systemImage: "bell.badge.fill", tint: Palette.glowAmber)
        HeroStat(value: "\(portfolio.insights.count)", label: "Insights", systemImage: "person.3.fill", tint: .white)
      }
    }
    .padding(22)
    .background {
      ZStack {
        Palette.nightGradient
        RadialGradient(colors: [Palette.mint.opacity(0.18), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 320)
      }
    }
    .clipShape(.rect(cornerRadius: 32))
    .overlay {
      RoundedRectangle(cornerRadius: 32)
        .strokeBorder(.white.opacity(0.08))
    }
    .shadow(color: Palette.nightBottom.opacity(0.25), radius: 24, y: 12)
    .environment(\.colorScheme, .dark)
  }

  private var points: [(offset: Int, element: Double)] {
    Array(portfolio.history.enumerated()).map { ($0.offset, $0.element) }
  }

  private var chart: some View {
    Chart {
      ForEach(points, id: \.offset) { point in
        AreaMark(
          x: .value("Day", point.offset),
          yStart: .value("Floor", yDomain.lowerBound),
          yEnd: .value("Value", point.element)
        )
        .foregroundStyle(
          LinearGradient(colors: [Palette.mint.opacity(0.32), Palette.mint.opacity(0)], startPoint: .top, endPoint: .bottom)
        )
        .interpolationMethod(.catmullRom)

        LineMark(x: .value("Day", point.offset), y: .value("Value", point.element))
          .foregroundStyle(Palette.mint)
          .lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
          .interpolationMethod(.catmullRom)
          .shadow(color: Palette.mint.opacity(0.7), radius: 8)
      }

      if let last = points.last {
        PointMark(x: .value("Day", last.offset), y: .value("Value", last.element))
          .symbolSize(520)
          .foregroundStyle(Palette.mint.opacity(0.22))
        PointMark(x: .value("Day", last.offset), y: .value("Value", last.element))
          .symbolSize(140)
          .foregroundStyle(Palette.mint)
        PointMark(x: .value("Day", last.offset), y: .value("Value", last.element))
          .symbolSize(30)
          .foregroundStyle(.white)
      }
    }
    .chartYScale(domain: yDomain)
    .chartXScale(domain: -0.3...(Double(max(points.count - 1, 1)) + 0.4))
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(values: .automatic(desiredCount: 4)) {
        AxisGridLine().foregroundStyle(.white.opacity(0.08))
      }
    }
    .chartOverlay { proxy in
      GeometryReader { geometry in
        if let dip = portfolio.dip,
           let plotFrame = proxy.plotFrame,
           let position = proxy.position(for: (x: dip.index, y: dip.value)) {
          let origin = geometry[plotFrame].origin
          OwlMark()
            .frame(width: 54, height: 60)
            .shadow(color: .black.opacity(0.35), radius: 6, y: 4)
            .position(x: origin.x + position.x, y: origin.y + position.y - 28)
        }
      }
    }
    .frame(height: 190)
    .accessibilityElement()
    .accessibilityLabel("Portfolio value over the last 10 days")
    .accessibilityValue(chartSummary)
  }

  private var yDomain: ClosedRange<Double> {
    let values = portfolio.history
    guard let low = values.min(), let high = values.max(), low < high else { return 0...1 }
    let range = high - low
    // Extra room below keeps the owl and fill grounded; extra above leaves space for the live dot.
    return (low - range * 0.25)...(high + range * 0.9)
  }

  private var chartSummary: String {
    guard let first = portfolio.history.first, let low = portfolio.dip?.value else { return "" }
    let format = FloatingPointFormatStyle<Double>.Currency(code: "USD")
    return "Started at \(first.formatted(format)), dipped to \(low.formatted(format)), now \(portfolio.totalValue.formatted(format))"
  }
}

private struct HeroStat: View {
  var value: String
  var label: String
  var systemImage: String
  var tint: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
      Text(value)
        .font(.title3.bold())
        .foregroundStyle(.white)
      Text(label)
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.6))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(.white.opacity(0.07), in: .rect(cornerRadius: 18))
    .accessibilityElement(children: .combine)
  }
}
