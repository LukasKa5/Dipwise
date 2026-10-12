import Charts
import SwiftUI

/// A price chart where the user drags handles to set a buy or sell zone, or a single level.
/// Dragging toward the edge zooms the chart out, so the zone never leaves the view.
struct ZoneEditorChart: View {
  var values: [Double]
  var side: TradeSide
  @Binding var lower: Double
  /// Nil for single-level alerts.
  var upper: Binding<Double>?
  var crowdZone: ClosedRange<Double>?
  var format: (Double) -> String

  @State private var domain: ClosedRange<Double>?
  @State private var dragStart: (lower: Double, upper: Double)?

  private var tint: Color { side.color }
  private var upperValue: Double { upper?.wrappedValue ?? lower }
  private var currentDomain: ClosedRange<Double> { domain ?? initialDomain }

  var body: some View {
    Chart { marks }
      .chartYScale(domain: currentDomain)
      .chartXAxis(.hidden)
      .chartYAxis {
        AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
          AxisGridLine()
          AxisValueLabel {
            if let level = value.as(Double.self) { Text(format(level)) }
          }
        }
      }
      .chartOverlay { proxy in
        GeometryReader { geometry in
          editorOverlay(proxy: proxy, geometry: geometry)
        }
        .coordinateSpace(.named("zoneEditor"))
      }
      .sensoryFeedback(.selection, trigger: Int(lower * 10) + Int(upperValue * 10))
      .onAppear { domain = initialDomain }
      .accessibilityElement()
      .accessibilityLabel(upper == nil ? "Price level" : "Price zone")
      .accessibilityValue(upper == nil ? format(lower) : "\(format(lower)) to \(format(upperValue))")
      .accessibilityAdjustableAction { direction in
        let step = (values.last ?? 100) * 0.005
        let delta = max(direction == .increment ? step : -step, minimumPrice - lower)
        lower = round(lower + delta)
        upper?.wrappedValue = round(upperValue + delta)
        makeRoom(for: lower...upperValue)
      }
  }

  @ChartContentBuilder
  private var marks: some ChartContent {
    if let crowdZone {
      RectangleMark(yStart: .value("Low", crowdZone.lowerBound), yEnd: .value("High", crowdZone.upperBound))
        .foregroundStyle(tint.opacity(0.12))
        .annotation(position: .overlay, alignment: .leading) {
          Text("Crowd")
            .font(.caption2.bold())
            .foregroundStyle(tint)
            .padding(.leading, 4)
        }
    }
    if upper != nil {
      RectangleMark(yStart: .value("Low", lower), yEnd: .value("High", upperValue))
        .foregroundStyle(tint.opacity(0.25))
    }
    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
      LineMark(x: .value("Session", index), y: .value("Price", value))
        .foregroundStyle(.primary.opacity(0.8))
        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .interpolationMethod(.monotone)
    }
    RuleMark(y: .value("Lower", lower))
      .foregroundStyle(tint)
      .lineStyle(StrokeStyle(lineWidth: 2, dash: upper == nil ? [5, 4] : []))
    if upper != nil {
      RuleMark(y: .value("Upper", upperValue))
        .foregroundStyle(tint)
        .lineStyle(StrokeStyle(lineWidth: 2))
    }
  }

  @ViewBuilder
  private func editorOverlay(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
    if let plotFrame = proxy.plotFrame {
      let frame: CGRect = geometry[plotFrame]
      let yLower: CGFloat = clampY((proxy.position(forY: lower) ?? 0) + frame.minY, frame: frame)
      let yUpper: CGFloat = clampY((proxy.position(forY: upperValue) ?? 0) + frame.minY, frame: frame)
      let handleX: CGFloat = frame.maxX - 52
      ZStack {
        if let dip = values.indices.dropLast().min(by: { values[$0] < values[$1] }),
           let position = proxy.position(for: (x: dip, y: values[dip])) {
          LivelyOwl(hopsOnTap: false)
            .frame(width: 30, height: 34)
            .position(x: frame.minX + position.x, y: frame.minY + position.y - 17)
            .allowsHitTesting(false)
        }
        if upper != nil {
          bandDragArea(proxy: proxy, frame: frame, yLower: yLower, yUpper: yUpper)
        }
        handle(label: upper == nil ? format(lower) : "Low \(format(lower))")
          .position(x: handleX, y: yLower)
          .gesture(handleDrag(proxy: proxy, frame: frame, isUpper: false))
        if upper != nil {
          handle(label: "High \(format(upperValue))")
            .position(x: handleX, y: yUpper)
            .gesture(handleDrag(proxy: proxy, frame: frame, isUpper: true))
        }
      }
    }
  }

  private func clampY(_ y: CGFloat, frame: CGRect) -> CGFloat {
    min(max(y, frame.minY + 12), frame.maxY - 12)
  }

  private func price(atY y: CGFloat, proxy: ChartProxy, frame: CGRect) -> Double? {
    proxy.value(atY: y - frame.minY, as: Double.self)
  }

  /// Widens the chart when a zone gets close to its top or bottom edge.
  private func makeRoom(for range: ClosedRange<Double>) {
    let current = currentDomain
    let span = current.upperBound - current.lowerBound
    let margin = span * 0.1
    var low = current.lowerBound
    var high = current.upperBound
    if range.lowerBound < low + margin { low = range.lowerBound - span * 0.25 }
    if range.upperBound > high - margin { high = range.upperBound + span * 0.25 }
    guard low != current.lowerBound || high != current.upperBound else { return }
    withAnimation(.smooth(duration: 0.35)) { domain = max(0, low)...high }
  }

  private func handleDrag(proxy: ChartProxy, frame: CGRect, isUpper: Bool) -> some Gesture {
    DragGesture(coordinateSpace: .named("zoneEditor"))
      .onChanged { drag in
        guard let value = price(atY: drag.location.y, proxy: proxy, frame: frame) else { return }
        if isUpper {
          upper?.wrappedValue = round(max(value, lower + minimumGap))
        } else {
          lower = max(minimumPrice, round(upper == nil ? value : min(value, upperValue - minimumGap)))
        }
      }
      .onEnded { _ in makeRoom(for: lower...max(lower, upperValue)) }
  }

  /// Dragging the middle of the band moves the whole zone.
  private func bandDragArea(proxy: ChartProxy, frame: CGRect, yLower: CGFloat, yUpper: CGFloat) -> some View {
    let width: CGFloat = frame.width - 60
    let height: CGFloat = max(16, abs(yLower - yUpper))
    return Rectangle()
      .fill(.clear)
      .contentShape(.rect)
      .frame(width: width, height: height)
      .position(x: frame.minX + width / 2, y: (yLower + yUpper) / 2)
      .gesture(
        DragGesture(coordinateSpace: .named("zoneEditor"))
          .onChanged { drag in
            if dragStart == nil { dragStart = (lower, upperValue) }
            guard let start = dragStart,
                  let from = price(atY: drag.startLocation.y, proxy: proxy, frame: frame),
                  let to = price(atY: drag.location.y, proxy: proxy, frame: frame) else { return }
            // Never let the zone slide below zero.
            let delta = max(to - from, minimumPrice - start.lower)
            lower = round(start.lower + delta)
            upper?.wrappedValue = round(start.upper + delta)
          }
          .onEnded { _ in
            dragStart = nil
            makeRoom(for: lower...max(lower, upperValue))
          }
      )
  }

  private func handle(label: String) -> some View {
    Text(label)
      .font(.caption2.bold().monospacedDigit())
      .foregroundStyle(.white)
      .padding(.horizontal, 8)
      .padding(.vertical, 5)
      .background(tint, in: .capsule)
      .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
      .frame(width: 104, height: 34)
      .contentShape(.rect)
      .accessibilityHidden(true)
  }

  private var minimumGap: Double { (values.last ?? 100) * 0.005 }
  private var minimumPrice: Double { (values.last ?? 1) >= 10 ? 0.05 : 0.001 }

  private var initialDomain: ClosedRange<Double> {
    let all = values + [lower, upperValue] + [crowdZone?.lowerBound, crowdZone?.upperBound].compactMap { $0 }
    let low = all.min() ?? 0
    let high = all.max() ?? 1
    let pad = max((high - low) * 0.25, high * 0.03)
    return max(0, low - pad)...(high + pad)
  }

  private func round(_ value: Double) -> Double {
    let step: Double = value >= 1000 ? 1 : (value >= 10 ? 0.05 : 0.001)
    return (value / step).rounded() * step
  }
}
