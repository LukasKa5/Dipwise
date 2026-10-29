import Charts
import SwiftUI

/// The flock's own fear and greed index, from everyone's anonymous daily check-ins: today's score on a gauge,
/// the last month as a line, and what members say they're doing with their money.
struct FlockSentimentCard: View {
  var sentiment: FlockSentiment
  var mine: FlockCheckIn?

  private func color(for score: Double) -> Color {
    switch score {
    case ..<40: Brand.sell
    case ..<60: Brand.amber
    default: Brand.buy
    }
  }

  var body: some View {
    let score = sentiment.score
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Flock Fear & Greed")
            .font(.headline)
          Text("From \((sentiment.today?.count ?? 0).formatted()) anonymous check-ins today")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
        }
        Spacer()
        if let change = sentiment.weekChange {
          Text("\(change >= 0 ? "+" : "")\(Int(change.rounded())) this week")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(change >= 0 ? Brand.buy : Brand.sell)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((change >= 0 ? Brand.buy : Brand.sell).opacity(0.15), in: .capsule)
        }
      }

      HStack(spacing: 18) {
        SentimentGauge(score: score, color: color(for: score))
          .frame(width: 128, height: 74)
        VStack(alignment: .leading, spacing: 2) {
          Text(Int(score.rounded()), format: .number)
            .font(.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
            .foregroundStyle(color(for: score))
          Text(sentiment.label)
            .font(.headline)
          if let mine {
            Label("You: \(mine.feeling.title)", systemImage: mine.feeling.systemImage)
              .font(.caption.weight(.semibold))
              .foregroundStyle(.white.opacity(0.7))
          }
        }
        .fitsNumber(0.7)
      }

      Chart(sentiment.days) { day in
        LineMark(x: .value("Day", day.day), y: .value("Score", day.score))
          .foregroundStyle(color(for: score))
          .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
          .interpolationMethod(.monotone)
        RuleMark(y: .value("Neutral", 50))
          .foregroundStyle(.white.opacity(0.15))
          .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
      }
      .chartXAxis(.hidden)
      .chartYAxis(.hidden)
      .chartYScale(domain: 0...100)
      .frame(height: 54)
      .accessibilityLabel("The flock's mood over the last month")

      VStack(alignment: .leading, spacing: 8) {
        Text("This week, the flock is")
          .font(.subheadline.weight(.semibold))
        ForEach(FlockAction.allCases) { action in
          let share = sentiment.actions[action] ?? 0
          HStack(spacing: 10) {
            Label(action.title, systemImage: action.systemImage)
              .font(.caption.weight(.semibold))
              .frame(width: 150, alignment: .leading)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
            GeometryReader { geometry in
              Capsule().fill(.white.opacity(0.1))
                .overlay(alignment: .leading) {
                  Capsule().fill(action.tint)
                    .frame(width: max(4, geometry.size.width * share))
                }
            }
            .frame(height: 8)
            Text(share, format: .percent.precision(.fractionLength(0)))
              .font(.caption.weight(.bold).monospacedDigit())
              .frame(width: 40, alignment: .trailing)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
    .padding(20)
    // The same navy card as Home's and the app icon's.
    .heroCardStyle()
  }
}

/// A half-circle gauge from fear (red) to greed (green), with a needle at the score.
struct SentimentGauge: View {
  var score: Double
  var color: Color

  var body: some View {
    GeometryReader { geometry in
      let width = geometry.size.width
      let center = CGPoint(x: width / 2, y: geometry.size.height)
      let radius = width / 2 - 8
      ZStack {
        Path { path in
          path.addArc(center: center, radius: radius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
        }
        .stroke(AngularGradient(colors: [Brand.sell, Brand.amber, Brand.buy], center: UnitPoint(x: 0.5, y: 1),
                                startAngle: .degrees(180), endAngle: .degrees(360)),
                style: StrokeStyle(lineWidth: 12, lineCap: .round))
        let angle = Angle.degrees(180 + 180 * score / 100)
        Circle()
          .fill(.white)
          .overlay { Circle().strokeBorder(color, lineWidth: 3) }
          .frame(width: 20, height: 20)
          .position(x: center.x + radius * cos(angle.radians), y: center.y + radius * sin(angle.radians))
      }
    }
    .animation(.smooth, value: score)
    .accessibilityHidden(true)
  }
}

extension FlockFeeling {
  /// From red to green, so every option reads clearly on light and navy backgrounds.
  var tint: Color {
    switch self {
    case .fearful: Brand.sell
    case .worried: Color(red: 0.96, green: 0.52, blue: 0.24)
    case .calm: Color(red: 0.45, green: 0.55, blue: 0.66)
    case .confident: Color(red: 0.36, green: 0.78, blue: 0.42)
    case .greedy: Brand.buy
    }
  }
}

extension FlockAction {
  var tint: Color {
    switch self {
    case .buying: Brand.buy
    case .holding, .trimming: Color(red: 0.45, green: 0.55, blue: 0.66)
    case .waiting: Brand.amber
    case .selling: Brand.sell
    }
  }
}
