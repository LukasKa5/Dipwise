import SwiftUI

/// An anonymous investor's face: Dippy on a circle in that investor's own color.
struct InvestorAvatar: View {
  var investor: FlockInvestor
  var size: CGFloat = 44

  var body: some View {
    OwlMark()
      .frame(width: size * 0.62)
      .frame(width: size, height: size)
      .background(Color(hue: investor.hue, saturation: 0.45, brightness: 0.55).gradient, in: .circle)
      .accessibilityHidden(true)
  }
}

/// One of the flock's top investors: their 12-month result, how risky they invest, and what they hold most.
struct InvestorCard: View {
  var investor: FlockInvestor
  var rank: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        InvestorAvatar(investor: investor, size: 40)
        VStack(alignment: .leading, spacing: 1) {
          Text(investor.nickname)
            .font(.headline)
            .lineLimit(1)
          Text("#\(rank) in the flock")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      VStack(alignment: .leading, spacing: 2) {
        Text(investor.yearReturn, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
          .font(.title2.bold().monospacedDigit())
          .foregroundStyle(investor.yearReturn >= 0 ? Palette.gain : Palette.loss)
        Text("past 12 months")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      HStack(spacing: 6) {
        ForEach(investor.portfolio.positions.prefix(3), id: \.symbol) { position in
          TickerBadge(symbol: position.symbol, size: 26)
        }
        Spacer(minLength: 4)
        RiskPill(score: investor.riskScore)
      }
    }
    .padding(16)
    .frame(width: 210, alignment: .leading)
    .cardStyle(cornerRadius: 22)
    .accessibilityElement(children: .combine)
  }
}

/// Risk from 1 (steady) to 7 (wild), like the scores investing apps use.
struct RiskPill: View {
  var score: Int

  private var color: Color {
    switch score {
    case ...2: Palette.gain
    case 3...4: Palette.amber
    default: Palette.loss
    }
  }

  var body: some View {
    Text("Risk \(score)")
      .font(.caption.weight(.bold).monospacedDigit())
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(color.opacity(0.14), in: .capsule)
      .accessibilityLabel("Risk score \(score) out of 7")
  }
}

/// How much of the flock owns a stock.
struct OwnershipRow: View {
  var rank: Int
  var stat: OwnershipStat

  var body: some View {
    HStack(spacing: 12) {
      Text("\(rank)")
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 22)
      TickerBadge(symbol: stat.symbol, size: 36)
      VStack(alignment: .leading, spacing: 5) {
        HStack {
          Text(stat.symbol).font(.headline)
          Spacer()
          Text("\(stat.share, format: .percent.precision(.fractionLength(0))) own it")
            .font(.subheadline.weight(.semibold).monospacedDigit())
        }
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Capsule().fill(.quaternary)
            Capsule().fill(Palette.green.gradient).frame(width: max(6, geometry.size.width * stat.share))
          }
        }
        .frame(height: 6)
        Text("Typically \(stat.averageWeight, format: .percent.precision(.fractionLength(0))) of their portfolio")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Image(systemName: "chevron.forward")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .padding(14)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

/// Who added and who trimmed a stock this week.
struct FlowRow: View {
  var stat: FlowStat

  var body: some View {
    HStack(spacing: 12) {
      TickerBadge(symbol: stat.symbol, size: 36)
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text(stat.symbol).font(.headline)
          Spacer()
          Text(stat.buyShare >= 0.5 ? "Mostly buying" : "Mostly selling")
            .font(.caption.weight(.bold))
            .foregroundStyle(stat.buyShare >= 0.5 ? Palette.buy : Palette.sell)
        }
        BuySellBar(buyShare: stat.buyShare)
        HStack {
          Text("\(stat.buyers) added")
            .foregroundStyle(Palette.buy)
          Spacer()
          Text("\(stat.sellers) trimmed")
            .foregroundStyle(Palette.sell)
        }
        .font(.caption.weight(.semibold).monospacedDigit())
      }
    }
    .padding(14)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

/// Invites the user to share their portfolio mix, in plain words about what is and isn't shared.
struct SharePortfolioCard: View {
  var share: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 12) {
        LivelyOwl(hopsOnTap: false)
          .frame(width: 40, height: 46)
        VStack(alignment: .leading, spacing: 3) {
          Text("Share your mix, see everyone's")
            .font(.headline)
          Text("The flock only works because members share. Dippy sends the percentages of your portfolio, never amounts, prices paid, or who you are.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Button(action: share) {
        Label("Share anonymously", systemImage: "person.3.fill")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(18)
    .cardStyle()
  }
}
