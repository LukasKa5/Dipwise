import SwiftData
import SwiftUI

/// Risk Analysis: the risk score, style, concentration, and habits a broker works out from your trading,
/// computed on your own device and explained in plain words.
struct InvestorProfileView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription

  private var profile: InvestorProfile? {
    let summary = PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase)
    return InvestorProfile.make(summary: summary, holdings: holdings, quotes: quotes.quotes, flock: flock.portfolios)
  }

  private var isPro: Bool { subscription.isPro }

  var body: some View {
    ScrollView {
      if let profile {
        VStack(alignment: .leading, spacing: 22) {
          hero(profile)
          brokerView(profile)
          numbers(profile)
          if profile.flockReturnPercentile != nil || profile.flockRiskPercentile != nil {
            versusFlock(profile)
          }
          Text("Brokers build a profile like this from every trade you make. Dipwise works it out on your iPhone, so you can see it too. It's information, not advice.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
      } else {
        ContentUnavailableView("Add What You Own", systemImage: "person.text.rectangle",
                               description: Text("Enter the shares you own and Dippy will build your investor profile."))
          .padding(.top, 60)
      }
    }
    .background(Palette.canvas)
    .navigationTitle("Risk Analysis")
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: Sections

  private func hero(_ profile: InvestorProfile) -> some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Label(profile.style.title, systemImage: profile.style.systemImage)
            .font(.title3.bold())
          Text(profile.style.detail)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.75))
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        LivelyOwl(greeting: .nod, greetingID: "profile")
          .frame(width: 58, height: 66)
      }
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          Text("Risk score")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Text("\(profile.riskScore) of 7")
            .font(.title2.bold().monospacedDigit())
            .contentTransition(.numericText())
        }
        RiskMeter(score: profile.riskScore)
        HStack {
          Text("Steady")
          Spacer()
          Text("Wild")
        }
        .font(.caption)
        .foregroundStyle(.white.opacity(0.6))
      }
      .accessibilityElement(children: .combine)
    }
    .padding(20)
    .foregroundStyle(.white)
    .heroCardStyle()
    .padding(.top, 8)
  }

  private func brokerView(_ profile: InvestorProfile) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "What stands out", subtitle: "Worked out from your holdings and decisions") {
        if !isPro { ProBadge() }
      }
      VStack(alignment: .leading, spacing: 14) {
        ForEach(Array(profile.observations.enumerated()), id: \.offset) { index, line in
          HStack(alignment: .top, spacing: 12) {
            Image(systemName: "eye.fill")
              .font(.footnote.weight(.bold))
              .foregroundStyle(Palette.green)
              .frame(width: 28, height: 28)
              .background(Palette.green.opacity(0.14), in: .circle)
            Text(line)
              .font(.subheadline)
              .fixedSize(horizontal: false, vertical: true)
          }
          .proLocked(!isPro && index >= 2, message: "See everything a broker learns about you with Pro")
        }
      }
      .padding(18)
      .cardStyle()
    }
  }

  private func numbers(_ profile: InvestorProfile) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your habits")
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
        HabitTile(title: "Diversification", value: "\(profile.diversificationScore)", caption: "out of 100", systemImage: "circle.hexagongrid.fill")
        HabitTile(title: "Biggest position", value: profile.largestWeight.formatted(.percent.precision(.fractionLength(0))),
                  caption: LocalizedStringKey(profile.largestSymbol ?? "—"), systemImage: "chart.pie.fill")
        HabitTile(title: "Buys when alerted", value: profile.dipBuyRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—",
                  caption: profile.loggedDecisions > 0 ? "\(profile.loggedDecisions) decisions logged" : "Log decisions to see this", systemImage: "cart.fill")
        HabitTile(title: "Buy alerts in profit", value: profile.buyHitRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—",
                  caption: "since they fired", systemImage: "checkmark.seal.fill")
        HabitTile(title: "Stocks with a plan", value: profile.planCoverage.formatted(.percent.precision(.fractionLength(0))),
                  caption: "buy or sell zone set", systemImage: "scope")
        HabitTile(title: "Past 12 months", value: profile.yearReturn.map { $0.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())) } ?? "—",
                  caption: "today's holdings", systemImage: "calendar")
      }
      .proLocked(!isPro, message: "See your investing habits with Pro")
    }
  }

  private func versusFlock(_ profile: InvestorProfile) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "You vs the flock", subtitle: "Anonymous members who share their mix")
      VStack(spacing: 18) {
        if let percentile = profile.flockReturnPercentile {
          PercentileBar(title: "12-month result", detail: "Better than \(percentile.formatted(.percent.precision(.fractionLength(0)))) of members",
                        value: percentile, color: Palette.gain)
        }
        if let percentile = profile.flockRiskPercentile {
          PercentileBar(title: "Risk", detail: "Riskier than \(percentile.formatted(.percent.precision(.fractionLength(0)))) of members",
                        value: percentile, color: Palette.amber)
        }
      }
      .padding(18)
      .cardStyle()
      .proLocked(!isPro, message: "Compare yourself with the flock with Pro")
    }
  }
}

/// Seven segments, lit up to the risk score, colored from calm green to bright red.
struct RiskMeter: View {
  var score: Int
  /// The unlit segments: soft white on navy cards, soft gray on light ones.
  var track: Color = .white.opacity(0.14)

  private func color(_ step: Int) -> Color {
    switch step {
    case ...2: Brand.buy
    case 3...4: Brand.amber
    default: Brand.sell
    }
  }

  var body: some View {
    HStack(spacing: 5) {
      ForEach(1...7, id: \.self) { step in
        Capsule()
          .fill(step <= score ? AnyShapeStyle(color(step)) : AnyShapeStyle(track))
          .frame(height: step == score ? 14 : 10)
      }
    }
    .frame(height: 14)
    .animation(.bouncy, value: score)
    .accessibilityHidden(true)
  }
}

private struct HabitTile: View {
  var title: LocalizedStringKey
  var value: String
  var caption: LocalizedStringKey
  var systemImage: String

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: systemImage)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.tint)
      Text(value)
        .font(.title2.bold().monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(title)
        .font(.subheadline.weight(.semibold))
      Text(caption)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(cornerRadius: 20)
    .accessibilityElement(children: .combine)
  }
}

private struct PercentileBar: View {
  var title: LocalizedStringKey
  var detail: LocalizedStringKey
  var value: Double
  var color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(title).font(.subheadline.weight(.semibold))
        Spacer()
        Text(detail).font(.caption).foregroundStyle(.secondary)
      }
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary)
          Capsule().fill(color.gradient).frame(width: max(8, geometry.size.width * value))
          Circle().fill(.white).overlay { Circle().strokeBorder(color, lineWidth: 3) }
            .frame(width: 18, height: 18)
            .offset(x: max(0, geometry.size.width * value - 9))
        }
      }
      .frame(height: 18)
    }
    .accessibilityElement(children: .combine)
  }
}

/// A compact entry into the risk analysis: style, risk score, and the risk meter.
struct InvestorProfileCard: View {
  var profile: InvestorProfile

  var body: some View {
    NavigationLink {
      InvestorProfileView()
    } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 12) {
          Image(systemName: "gauge.with.dots.needle.67percent")
            .font(.headline)
            .foregroundStyle(.tint)
            .frame(width: 40, height: 40)
            .background(Palette.green.opacity(0.14), in: .circle)
          VStack(alignment: .leading, spacing: 2) {
            Text("Risk Analysis")
              .font(.headline)
            Text("\(profile.style.title) · Risk \(profile.riskScore) of 7")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 4)
          Image(systemName: "chevron.forward")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.tertiary)
        }
        RiskMeter(score: profile.riskScore, track: Color.secondary.opacity(0.18))
      }
      .padding(16)
      .cardStyle()
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
