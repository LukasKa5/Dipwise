import Charts
import SwiftUI

/// The signature Dipwise chart: scrub to read values, with the owl perched at a dip.
/// Scrub close to the owl and it flies to another dip.
struct InteractiveChart: View {
  struct Level: Identifiable {
    var id = UUID()
    var price: Double
    var side: TradeSide
    var label: String
  }

  struct Zone: Identifiable {
    var id = UUID()
    var range: ClosedRange<Double>
    var side: TradeSide
    var label: String
    var isCrowd = false
  }

  var values: [Double]
  var dates: [Date]
  /// Defaults to green when the period is up and red when it's down.
  var lineColor: Color?
  var gridColor: Color = .secondary.opacity(0.18)
  var levels: [Level] = []
  var zones: [Zone] = []
  var showsOwl = true
  var owlSize: CGFloat = 52
  /// Nil follows the market clock, like everywhere else in the app.
  var owlMood: OwlMood? = nil
  @Binding var selectedIndex: Int?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var perchIndex: Int?
  @State private var flights = 0
  @State private var flightDirection = 1.0
  @State private var landed = false

  private var points: [(offset: Int, element: Double)] {
    values.enumerated().map { ($0.offset, $0.element) }
  }

  /// Local lows where the owl can perch, excluding the live-price end.
  private var perches: [Int] {
    guard values.count > 4 else { return [] }
    let window = max(2, values.count / 12)
    return values.indices.dropFirst().dropLast(2).filter { index in
      let lower = max(0, index - window)
      let upper = min(values.count - 1, index + window)
      return values[lower...upper].min() == values[index]
    }
  }

  /// The lowest local dip, or the lowest point before today when the series is too short for dips.
  private var defaultPerch: Int? {
    if let dip = perches.min(by: { values[$0] < values[$1] }) { return dip }
    guard values.count >= 2 else { return nil }
    return values.indices.dropLast().min { values[$0] < values[$1] }
  }

  /// Dippy watches the finger as it scrubs.
  private var gaze: CGSize {
    guard let selectedIndex, let perch = perchIndex ?? defaultPerch else { return .zero }
    let dx = Double(selectedIndex - perch) / Double(max(values.count / 4, 1))
    let dy = values.indices.contains(selectedIndex) && values[selectedIndex] > values[perch] ? -0.5 : 0.3
    return CGSize(width: max(-1, min(1, dx)), height: dy)
  }

  private var trendColor: Color {
    if let lineColor { return lineColor }
    guard let first = values.first, let last = values.last else { return Palette.gain }
    return last >= first ? Palette.gain : Palette.loss
  }

  var body: some View {
    let lineColor = trendColor
    return Chart {
      ForEach(zones) { zone in
        RectangleMark(
          xStart: .value("Start", -0.5),
          xEnd: .value("End", Double(max(points.count - 1, 1)) + 0.6),
          yStart: .value("Low", zone.range.lowerBound),
          yEnd: .value("High", zone.range.upperBound)
        )
        .foregroundStyle(zone.isCrowd ? Palette.crowd.opacity(0.18) : zone.side.color.opacity(0.18))
        .annotation(position: .overlay, alignment: .leading) {
          Text(zone.label)
            .font(.caption2.bold())
            .foregroundStyle(zone.isCrowd ? Palette.crowd : zone.side.color)
            .padding(.leading, 4)
        }
      }

      ForEach(points, id: \.offset) { point in
        AreaMark(
          x: .value("Session", point.offset),
          yStart: .value("Floor", yDomain.lowerBound),
          yEnd: .value("Price", point.element)
        )
        .foregroundStyle(LinearGradient(colors: [lineColor.opacity(0.16), lineColor.opacity(0)], startPoint: .top, endPoint: .bottom))
        .interpolationMethod(.monotone)

        LineMark(x: .value("Session", point.offset), y: .value("Price", point.element))
          .foregroundStyle(lineColor)
          .lineStyle(StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
          .interpolationMethod(.monotone)
      }

      ForEach(levels) { level in
        RuleMark(y: .value("Level", level.price))
          .foregroundStyle(level.side.color.opacity(0.9))
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 5]))
          .annotation(position: .top, alignment: .trailing, spacing: 2) {
            Text(level.label)
              .font(.caption2.bold())
              .foregroundStyle(level.side.color)
          }
      }

      if let selectedIndex, values.indices.contains(selectedIndex) {
        RuleMark(x: .value("Selected", selectedIndex))
          .foregroundStyle(.primary.opacity(0.35))
          .lineStyle(StrokeStyle(lineWidth: 1))
        PointMark(x: .value("Selected", selectedIndex), y: .value("Price", values[selectedIndex]))
          .symbolSize(140)
          .foregroundStyle(.primary)
      } else if let last = points.last {
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
    .chartXSelection(value: $selectedIndex)
    .chartOverlay { proxy in
      GeometryReader { geometry in
        if showsOwl, let index = perchIndex ?? defaultPerch, values.indices.contains(index),
           let plotFrame = proxy.plotFrame,
           let position = proxy.position(for: (x: index, y: values[index])) {
          let origin = geometry[plotFrame].origin
          LivelyOwl(lookOffset: gaze, hopsOnTap: false, mood: owlMood)
            .frame(width: owlSize, height: owlSize * 1.15)
            .offset(landed || reduceMotion ? .zero : CGSize(width: owlSize * 2, height: -owlSize * 3))
            .opacity(landed || reduceMotion ? 1 : 0)
            .owlFlight(trigger: flights, direction: flightDirection, height: 60, isEnabled: !reduceMotion)
            .shadow(color: .black.opacity(0.3), radius: 5, y: 3)
            .position(x: origin.x + position.x, y: origin.y + position.y - owlSize * 0.57)
            .allowsHitTesting(false)
        }
      }
    }
    .sensoryFeedback(.selection, trigger: selectedIndex)
    .onChange(of: selectedIndex) { _, index in
      if let index { scareOwl(near: index) }
    }
    .onChange(of: values) { perchIndex = nil }
    .onAppear {
      // Dippy flies in and lands on the dip the first time the chart appears.
      guard !landed, !reduceMotion, showsOwl, (owlMood ?? (MarketClock.isOpen() || OwlWake.shared.isAwake ? .calm : .sleeping)) != .sleeping else {
        landed = true
        return
      }
      flightDirection = -1
      flights += 1
      withAnimation(.smooth(duration: 0.9).delay(0.15)) { landed = true }
    }
    .accessibilityElement()
    .accessibilityLabel("Price chart")
    .accessibilityValue(summary)
    .accessibilityAdjustableAction { direction in
      let current = selectedIndex ?? values.count - 1
      switch direction {
      case .increment: selectedIndex = min(values.count - 1, current + 1)
      case .decrement: selectedIndex = max(0, current - 1)
      @unknown default: break
      }
    }
  }

  /// If the finger comes near the owl, it flies to the farthest other dip.
  private func scareOwl(near index: Int) {
    guard showsOwl, let current = perchIndex ?? defaultPerch else { return }
    let reach = max(1, values.count / 25)
    guard abs(index - current) <= reach else { return }
    let candidates = perches.filter { abs($0 - index) > reach * 3 }
    let destination = candidates.max { abs($0 - index) < abs($1 - index) }
      ?? (index < values.count / 2 ? values.count - 3 : 1)
    flightDirection = destination > current ? 1 : -1
    flights += 1
    withAnimation(reduceMotion ? nil : .smooth(duration: 0.75)) {
      perchIndex = destination
    }
  }

  private var yDomain: ClosedRange<Double> {
    let all = values + levels.map(\.price) + zones.flatMap { [$0.range.lowerBound, $0.range.upperBound] }
    guard let low = all.min(), let high = all.max(), low < high else {
      let value = values.first ?? 1
      return (value * 0.95)...(value * 1.05)
    }
    let range = high - low
    let headroom = showsOwl ? range * 0.55 : range * 0.15
    return (low - range * 0.12)...(high + headroom)
  }

  private var summary: String {
    guard let first = values.first, let last = values.last, let low = values.min() else { return "" }
    let change = (last / first - 1).formatted(.percent.precision(.fractionLength(1)))
    return "Changed \(change) over the period. Low \(low.formatted(.number.precision(.fractionLength(2)))), now \(last.formatted(.number.precision(.fractionLength(2))))."
  }
}
