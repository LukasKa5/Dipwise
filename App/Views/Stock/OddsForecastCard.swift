import Charts
import SwiftUI

/// Your odds, drawn: the recent price, a cone of where it could go from its own daily moves, and your buy zone
/// across both. Two rings give the chance it reaches the zone within 30 and 90 days; tap one to see that cone.
struct OddsForecastCard: View {
  var symbol: String
  var quote: Quote
  var rule: AlertRule

  @State private var horizon = Horizon.month

  enum Horizon: Int, CaseIterable, Identifiable {
    case month = 21
    case quarter = 63

    var id: Self { self }

    var title: LocalizedStringKey {
      switch self {
      case .month: "within 30 days"
      case .quarter: "within 90 days"
      }
    }
  }

  var body: some View {
    if let odds = AlertOdds(rule: rule, quote: quote) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
          LivelyOwl(mood: .calm)
            .frame(width: 34, height: 40)
          VStack(alignment: .leading, spacing: 2) {
            Text("Your odds")
              .font(.headline)
            Text("\(symbol) · buy between \(quote.formatted(rule.lower)) and \(quote.formatted(max(rule.lower, rule.upper)))")
              .font(.caption.weight(.semibold))
              .foregroundStyle(Brand.buy)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
          Spacer(minLength: 0)
        }

        OddsCone(quote: quote, rule: rule, sigma: odds.dailyVolatility, days: horizon.rawValue)
          .frame(height: 190)
          .animation(.smooth(duration: 0.6), value: horizon)

        HStack(spacing: 12) {
          ForEach(Horizon.allCases) { option in
            Button {
              withAnimation(.snappy) { horizon = option }
            } label: {
              OddsRing(chance: option == .month ? odds.monthChance : odds.quarterChance, title: option.title, isSelected: horizon == option)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(horizon == option ? .isSelected : [])
          }
        }
        .sensoryFeedback(.selection, trigger: horizon)

        Text("\(odds.lastTriggeredText). Worked out from \(symbol)'s daily moves over the past year, not a prediction.")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.6))
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(18)
      .foregroundStyle(.white)
      .background(
        LinearGradient(colors: [Brand.nightTop, Brand.nightMiddle], startPoint: .top, endPoint: .bottom),
        in: .rect(cornerRadius: 26, style: .continuous)
      )
      .environment(\.colorScheme, .dark)
    }
  }
}

/// The last two months of closes, then a widening cone of likely prices: the inner band holds half of the
/// outcomes, the outer one eight in ten. The buy zone runs across both.
private struct OddsCone: View {
  var quote: Quote
  var rule: AlertRule
  var sigma: Double
  var days: Int

  private struct Band: Identifiable {
    var day: Int
    var low: Double
    var high: Double
    var innerLow: Double
    var innerHigh: Double
    var id: Int { day }
  }

  var body: some View {
    let history = Array(quote.closes.suffix(44))
    let today = history.count - 1
    let price = quote.price
    let bands = (0...days).map { t in
      let spread = sigma * sqrt(Double(t))
      return Band(day: today + t, low: price * exp(-1.28 * spread), high: price * exp(1.28 * spread),
                  innerLow: price * exp(-0.67 * spread), innerHigh: price * exp(0.67 * spread))
    }
    let upper = max(rule.lower, rule.upper)
    let values = history + [bands.last?.low ?? price, bands.last?.high ?? price, rule.lower, upper]
    let low = values.min() ?? price
    let high = values.max() ?? price
    let pad = (high - low) * 0.06
    Chart {
      RectangleMark(xStart: .value("Start", 0), xEnd: .value("End", today + days),
                    yStart: .value("Zone low", rule.lower), yEnd: .value("Zone high", upper))
        .foregroundStyle(Brand.buy.opacity(0.22))
      ForEach(bands) { band in
        AreaMark(x: .value("Day", band.day), yStart: .value("Low", band.low), yEnd: .value("High", band.high), series: .value("Band", "outer"))
          .foregroundStyle(.white.opacity(0.08))
          .interpolationMethod(.monotone)
        AreaMark(x: .value("Day", band.day), yStart: .value("Low", band.innerLow), yEnd: .value("High", band.innerHigh), series: .value("Band", "inner"))
          .foregroundStyle(.white.opacity(0.12))
          .interpolationMethod(.monotone)
      }
      ForEach(Array(history.enumerated()), id: \.offset) { index, value in
        LineMark(x: .value("Day", index), y: .value("Price", value), series: .value("Line", "price"))
          .foregroundStyle(.white)
          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
          .interpolationMethod(.monotone)
      }
      RuleMark(x: .value("Today", today))
        .foregroundStyle(.white.opacity(0.35))
        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
        .annotation(position: .top, alignment: .center, spacing: 2) {
          Text("Today")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.6))
        }
      PointMark(x: .value("Day", today), y: .value("Price", price))
        .foregroundStyle(.white)
        .symbolSize(70)
    }
    .chartXAxis(.hidden)
    .chartYAxis {
      AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
        AxisGridLine().foregroundStyle(.white.opacity(0.07))
        AxisValueLabel {
          if let price = value.as(Double.self) {
            Text(compactPrice(price, currency: quote.currency))
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.5))
          }
        }
      }
    }
    .chartXScale(domain: 0...(today + days))
    .chartYScale(domain: (low - pad)...(high + pad))
    .accessibilityLabel("Price chart with a cone of likely prices over the next \(days) trading days and your buy zone")
  }
}

/// A chance as a ring that fills up, with its horizon underneath.
private struct OddsRing: View {
  var chance: Double
  var title: LocalizedStringKey
  var isSelected: Bool

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle().stroke(.white.opacity(0.12), lineWidth: 7)
        Circle()
          .trim(from: 0, to: chance)
          .stroke(Brand.buy, style: StrokeStyle(lineWidth: 7, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text(chance, format: .percent.precision(.fractionLength(0)))
          .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
          .minimumScaleFactor(0.6)
      }
      .frame(width: 52, height: 52)
      VStack(alignment: .leading, spacing: 1) {
        Text("Chance")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.6))
        Text(title)
          .font(.subheadline.weight(.bold))
          .lineLimit(2)
          .minimumScaleFactor(0.7)
      }
      Spacer(minLength: 0)
    }
    .padding(10)
    .frame(maxWidth: .infinity)
    .background(.white.opacity(isSelected ? 0.14 : 0.05), in: .rect(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(isSelected ? Brand.buy.opacity(0.7) : .clear, lineWidth: 1.5)
    }
    .accessibilityElement(children: .combine)
  }
}
