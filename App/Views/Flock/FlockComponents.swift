import Charts
import SwiftUI

/// A 0–100 ring with the score in the middle.
struct ConvictionGauge: View {
  var score: Int
  var diameter: CGFloat = 86

  private var color: Color {
    switch score {
    case 55...: Palette.buy
    case 45..<55: .secondary
    default: Palette.sell
    }
  }

  var body: some View {
    ZStack {
      Circle().stroke(.quaternary, lineWidth: diameter * 0.1)
      Circle()
        .trim(from: 0, to: max(0.02, Double(score) / 100))
        .stroke(color, style: StrokeStyle(lineWidth: diameter * 0.1, lineCap: .round))
        .rotationEffect(.degrees(-90))
      VStack(spacing: 0) {
        Text("\(score)")
          .font(.system(size: diameter * 0.32, weight: .heavy, design: .rounded))
          .monospacedDigit()
        if diameter > 60 {
          Text("/ 100")
            .font(.system(size: diameter * 0.12, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
        }
      }
    }
    .frame(width: diameter, height: diameter)
    .animation(.smooth, value: score)
    .accessibilityElement()
    .accessibilityLabel("Crowd conviction")
    .accessibilityValue("\(score) out of 100")
  }
}

/// A stock trading inside the crowd's buy zone.
struct RadarCard: View {
  var item: RadarItem

  private func format(_ value: Double) -> String {
    value.formatted(.currency(code: item.currency).precision(.fractionLength(2)))
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        TickerBadge(symbol: item.symbol, size: 38)
        VStack(alignment: .leading, spacing: 1) {
          Text(item.symbol).font(.headline)
          Text(format(item.price))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        Spacer()
        ConvictionGauge(score: item.conviction, diameter: 42)
      }
      VStack(alignment: .leading, spacing: 4) {
        Label(item.buyZone.contains(item.price) ? "In the crowd's buy zone" : "Just above the buy zone", systemImage: "scope")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Palette.buy)
        Text("\(format(item.buyZone.lowerBound))–\(format(item.buyZone.upperBound)) · \(item.watchers) investors")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(cornerRadius: 22)
    .accessibilityElement(children: .combine)
  }
}

/// One anonymous action from the flock.
struct FeedRow: View {
  var event: FlockEvent
  var showsSymbol = true

  private var tint: Color {
    event.entry.kind.side.color
  }

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: event.systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        .frame(width: 34, height: 34)
        .background(tint.opacity(0.14), in: .circle)
      VStack(alignment: .leading, spacing: 2) {
        if showsSymbol {
          Text(event.symbol).font(.subheadline.weight(.bold))
        }
        Text(event.text { $0.formatted(.number.precision(.fractionLength(2))) })
          .font(.subheadline)
          .foregroundStyle(showsSymbol ? .secondary : .primary)
          .lineLimit(2)
      }
      Spacer(minLength: 6)
      Text(event.date, format: .relative(presentation: .numeric, unitsStyle: .narrow))
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .accessibilityElement(children: .combine)
  }
}

/// Where the flock's alerts sit relative to today's price.
struct FlockHistogram: View {
  var report: FlockReport
  var userLevels: [Double] = []

  var body: some View {
    Chart {
      ForEach(report.bins) { bin in
        BarMark(x: .value("Distance", bin.midOffset), y: .value("Alerts", bin.buyCount), width: .ratio(0.8))
          .foregroundStyle(by: .value("Type", "Buy"))
          .cornerRadius(3)
        BarMark(x: .value("Distance", bin.midOffset), y: .value("Alerts", bin.sellCount), width: .ratio(0.8))
          .foregroundStyle(by: .value("Type", "Sell"))
          .cornerRadius(3)
      }
      RuleMark(x: .value("Distance", 0))
        .foregroundStyle(.primary.opacity(0.6))
        .annotation(position: .top) {
          Text("Now").font(.caption2.bold()).foregroundStyle(.secondary)
        }
      ForEach(userLevels, id: \.self) { level in
        RuleMark(x: .value("Distance", level / report.currentPrice - 1))
          .foregroundStyle(Palette.amber)
          .lineStyle(StrokeStyle(lineWidth: 2, dash: [3, 3]))
          .annotation(position: .top) {
            Image(systemName: "person.fill")
              .font(.caption2.bold())
              .foregroundStyle(.white)
              .padding(4)
              .background(Palette.amber, in: .circle)
              .accessibilityLabel("Your level")
          }
      }
    }
    .chartForegroundStyleScale(["Buy": Palette.buy, "Sell": Palette.sell])
    .chartXScale(domain: FlockReport.offsetRange)
    .chartXAxis {
      AxisMarks(values: [-0.3, -0.2, -0.1, 0, 0.1, 0.2, 0.3]) { value in
        AxisGridLine()
        AxisValueLabel {
          if let offset = value.as(Double.self) {
            Text(offset, format: .percent.precision(.fractionLength(0)).sign(strategy: offset == 0 ? .never : .always()))
          }
        }
      }
    }
    .chartLegend(position: .bottom, alignment: .leading)
    .accessibilityElement()
    .accessibilityLabel("Distribution of crowd alerts around today's price")
    .accessibilityValue("\(report.buyLevels.count) buy levels and \(report.sellLevels.count) sell levels")
  }
}

/// Weekly bull/bear vote for one stock.
struct VoteCard: View {
  var symbol: String
  var votes: FlockVotes
  var userVote: Bool?
  var vote: (Bool) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      Text("Where's \(symbol) heading in the next 30 days?")
        .font(.headline)
      if let userVote {
        VStack(alignment: .leading, spacing: 8) {
          GeometryReader { geometry in
            HStack(spacing: 3) {
              Capsule().fill(Palette.green)
                .frame(width: max(6, (geometry.size.width - 3) * votes.bullShare))
              Capsule().fill(Palette.loss)
            }
          }
          .frame(height: 12)
          HStack {
            Label("\(votes.bullShare.formatted(.percent.precision(.fractionLength(0)))) up", systemImage: "arrow.up.right")
              .foregroundStyle(Palette.green)
            Spacer()
            Text("\(votes.total.formatted()) votes this week")
              .foregroundStyle(.secondary)
            Spacer()
            Label("\((1 - votes.bullShare).formatted(.percent.precision(.fractionLength(0)))) down", systemImage: "arrow.down.right")
              .foregroundStyle(Palette.loss)
          }
          .font(.caption.weight(.semibold))
          Text("You voted \(userVote ? "up" : "down"). Tap to change.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
      }
      HStack(spacing: 12) {
        voteButton(title: "Up", systemImage: "arrow.up.right", color: Palette.green, isSelected: userVote == true) { vote(true) }
        voteButton(title: "Down", systemImage: "arrow.down.right", color: Palette.loss, isSelected: userVote == false) { vote(false) }
      }
    }
    .padding(18)
    .cardStyle()
    .animation(.smooth, value: userVote)
    .sensoryFeedback(.success, trigger: userVote)
  }

  private func voteButton(title: String, systemImage: String, color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Label(title, systemImage: systemImage)
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .foregroundStyle(isSelected ? .white : color)
        .background(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.12)), in: .rect(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isSelected ? .isSelected : [])
  }
}

/// Small bar chart of new alerts per week.
struct ActivityBars: View {
  var counts: [Int]

  var body: some View {
    Chart(Array(counts.enumerated()), id: \.offset) { index, count in
      BarMark(x: .value("Week", index), y: .value("Alerts", count))
        .foregroundStyle(index == counts.count - 1 ? Palette.buy : Palette.buy.opacity(0.4))
        .cornerRadius(3)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .accessibilityElement()
    .accessibilityLabel("New alerts per week for the last eight weeks")
    .accessibilityValue(counts.map(String.init).joined(separator: ", "))
  }
}

/// A short summary of the crowd on a stock, linking to the full report.
struct FlockTeaser: View {
  var symbol: String
  var quote: Quote?
  @Environment(FlockService.self) private var flock

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "The Flock", subtitle: "What other Dipwise investors are planning")
      if !flock.isAvailable {
        EmptyHint(systemImage: "person.3", text: "Crowd statistics are coming soon.")
      } else if let report = flock.reports[symbol] {
        NavigationLink {
          FlockDetailView(symbol: symbol)
        } label: {
          VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
              ConvictionGauge(score: report.conviction, diameter: 64)
              VStack(alignment: .leading, spacing: 4) {
                Text(report.convictionLabel)
                  .font(.headline)
                Text("\(report.watcherCount) investors · \(report.alertsThisWeek) new alerts this week")
                  .font(.subheadline)
                  .foregroundStyle(.secondary)
              }
              Spacer()
            }
            if let zone = report.buyZone, let quote {
              Label("Crowd buys between \(quote.formatted(zone.lowerBound)) and \(quote.formatted(zone.upperBound))", systemImage: "scope")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.buy)
            }
            HStack {
              Text("Open full crowd report")
                .font(.subheadline.weight(.semibold))
              Spacer()
              Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.tint)
          }
          .padding(18)
          .cardStyle()
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
      } else {
        ProgressView().frame(maxWidth: .infinity, minHeight: 100)
      }
    }
  }
}
