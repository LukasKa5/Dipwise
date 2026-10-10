import Charts
import SwiftUI
import WidgetKit

/// Shared look for Home Screen widgets: the system background, so they match the app's cards in light and dark mode.
extension View {
  func dipwiseWidgetBackground() -> some View {
    containerBackground(for: .widget) { Color(uiColor: .systemBackground) }
  }
}

struct WidgetTrack: View {
  var progress: Double
  var color: Color

  var body: some View {
    GeometryReader { geometry in
      ZStack(alignment: .leading) {
        Capsule().fill(.quaternary)
        Capsule()
          .fill(color)
          .frame(width: max(6, geometry.size.width * progress))
      }
    }
    .frame(height: 6)
  }
}

struct WidgetBadge: View {
  var symbol: String
  var size: CGFloat = 26

  private var hue: Double {
    var hash: UInt64 = 5381
    for scalar in symbol.unicodeScalars { hash = (hash &* 33) &+ UInt64(scalar.value) }
    return Double(hash % 360) / 360
  }

  var body: some View {
    Text(symbol.prefix(symbol.count > 4 ? 1 : 2))
      .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
      .foregroundStyle(.white)
      .minimumScaleFactor(0.5)
      .frame(width: size, height: size)
      .background(Color(hue: hue, saturation: 0.62, brightness: 0.72), in: .rect(cornerRadius: size * 0.3))
  }
}

struct WidgetSparkline: View {
  var values: [Double]

  var body: some View {
    let isUp = (values.last ?? 0) >= (values.first ?? 0)
    Chart(Array(values.enumerated()), id: \.offset) { index, value in
      LineMark(x: .value("Day", index), y: .value("Price", value))
        .foregroundStyle(isUp ? Brand.buy : Brand.sell)
        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        .interpolationMethod(.monotone)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: (values.min() ?? 0)...(max(values.max() ?? 1, (values.min() ?? 0) + 0.0001)))
  }
}

func distanceText(_ distance: Double?) -> String {
  guard let distance else { return "—" }
  return distance == 0 ? "Now" : distance.formatted(.percent.precision(.fractionLength(1)))
}

func changeText(_ change: Double) -> String {
  change.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
}
