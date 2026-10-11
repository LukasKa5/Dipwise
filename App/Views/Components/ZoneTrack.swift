import SwiftUI

/// A horizontal price scale showing buy and sell zones, the crowd's zones, and today's price.
struct ZoneTrack: View {
  struct Band: Identifiable {
    var id = UUID()
    var range: ClosedRange<Double>
    var side: TradeSide
    var isCrowd: Bool
  }

  var price: Double
  var bands: [Band]
  var low: Double?
  var high: Double?
  var format: (Double) -> String

  private var domain: ClosedRange<Double> {
    let all = bands.flatMap { [$0.range.lowerBound, $0.range.upperBound] } + [price, low ?? price, high ?? price]
    let minValue = all.min() ?? price
    let maxValue = all.max() ?? price
    let pad = max((maxValue - minValue) * 0.06, price * 0.01)
    return (minValue - pad)...(maxValue + pad)
  }

  var body: some View {
    VStack(spacing: 6) {
      GeometryReader { geometry in
        let width = geometry.size.width
        let domain = domain
        let x: (Double) -> CGFloat = { value in
          CGFloat((value - domain.lowerBound) / (domain.upperBound - domain.lowerBound)) * width
        }
        ZStack(alignment: .topLeading) {
          Capsule()
            .fill(.quaternary)
            .frame(height: 10)
            .offset(y: 25)

          ForEach(bands.sorted { $0.isCrowd && !$1.isCrowd }) { band in
            let color = band.side.color
            let start = x(band.range.lowerBound)
            let bandWidth = max(6, x(band.range.upperBound) - start)
            if band.isCrowd {
              // The crowd's zone sits on the line as a dashed outline around it.
              Capsule()
                .strokeBorder(color, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .background(color.opacity(0.12), in: .capsule)
                .frame(width: bandWidth, height: 20)
                .offset(x: start, y: 20)
            } else {
              Capsule()
                .fill(color)
                .frame(width: bandWidth, height: 10)
                .offset(x: start, y: 25)
            }
          }

          VStack(spacing: 2) {
            Image(systemName: "arrowtriangle.down.fill")
              .font(.system(size: 10))
            Capsule().frame(width: 3, height: 22)
          }
          .foregroundStyle(.primary)
          .offset(x: x(price) - 5, y: 12)
        }
      }
      .frame(height: 40)

      HStack {
        Text(format(domain.lowerBound))
        Spacer()
        Text("Now \(format(price))")
          .fontWeight(.semibold)
          .foregroundStyle(.primary)
        Spacer()
        Text(format(domain.upperBound))
      }
      .font(.caption2.monospacedDigit())
      .foregroundStyle(.secondary)
    }
    .accessibilityElement()
    .accessibilityLabel("Price zones")
    .accessibilityValue(bands.map { "\($0.isCrowd ? "Crowd" : "Your") \($0.side == .buy ? "buy" : "sell") zone \(format($0.range.lowerBound)) to \(format($0.range.upperBound))" }.joined(separator: ", "))
  }
}

struct ZoneLegend: View {
  var showsCrowd = true

  var body: some View {
    HStack(spacing: 14) {
      legend(color: Palette.buy, text: "Buy", dashed: false)
      legend(color: Palette.sell, text: "Sell", dashed: false)
      if showsCrowd {
        legend(color: .secondary, text: "Crowd", dashed: true)
      }
    }
    .font(.caption2.weight(.semibold))
    .foregroundStyle(.secondary)
  }

  private func legend(color: Color, text: String, dashed: Bool) -> some View {
    HStack(spacing: 5) {
      if dashed {
        RoundedRectangle(cornerRadius: 3)
          .strokeBorder(color, style: StrokeStyle(lineWidth: 1.2, dash: [3, 2]))
          .frame(width: 16, height: 9)
      } else {
        Capsule().fill(color).frame(width: 16, height: 6)
      }
      Text(text)
    }
  }
}
