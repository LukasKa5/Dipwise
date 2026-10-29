import Charts
import SwiftUI

/// Your odds, drawn: the recent price, a cone of where it could go from its own daily moves, and your zone across
/// both, for buying or for selling. Two rings give the chance it reaches the zone within 30 and 90 days (tap one to
/// see that cone), with the typical wait and the likely price range a month out. Free shows the 30-day odds for a
/// buy zone; Pro adds every horizon, the wait, the range, and sell zones.
struct OddsForecastCard: View {
  var symbol: String
  var quote: Quote
  var buyZone: AlertRule?
  var sellZone: AlertRule?
  var isPro: Bool

  @State private var side: TradeSide = .buy
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

  private var rule: AlertRule? {
    side == .sell ? (sellZone ?? buyZone) : (buyZone ?? sellZone)
  }

  var body: some View {
    if let rule, let odds = AlertOdds(rule: rule, quote: quote) {
      let color = rule.kind.side.brandColor
      let isSell = rule.kind.side == .sell
      VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
          LivelyOwl(mood: .calm)
            .frame(width: 34, height: 40)
          VStack(alignment: .leading, spacing: 2) {
            Text("Your odds")
              .font(.headline)
            Text(isSell ? "\(symbol) · sell between \(quote.formatted(rule.lower)) and \(quote.formatted(max(rule.lower, rule.upper)))"
                        : "\(symbol) · buy between \(quote.formatted(rule.lower)) and \(quote.formatted(max(rule.lower, rule.upper)))")
              .font(.caption.weight(.semibold))
              .foregroundStyle(color)
              .lineLimit(1)
              .minimumScaleFactor(0.5)
          }
          Spacer(minLength: 0)
        }

        if buyZone != nil && sellZone != nil {
          HStack(spacing: 4) {
            ForEach([TradeSide.buy, .sell], id: \.self) { option in
              Button {
                withAnimation(.smooth) { side = option }
              } label: {
                Text(option == .buy ? "Buy zone" : "Sell zone")
                  .font(.subheadline.weight(.semibold))
                  .foregroundStyle(side == option ? Brand.owlInk : .white.opacity(0.75))
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 7)
                  .background(side == option ? AnyShapeStyle(option == .buy ? Brand.buy : Brand.sell) : AnyShapeStyle(.clear), in: .capsule)
                  .contentShape(.capsule)
              }
              .buttonStyle(.plain)
              .accessibilityAddTraits(side == option ? .isSelected : [])
            }
          }
          .padding(3)
          .background(.white.opacity(0.08), in: .capsule)
        }

        VStack(alignment: .leading, spacing: 14) {
          OddsCone(quote: quote, rule: rule, sigma: odds.dailyVolatility, days: horizon.rawValue, color: color)
            .frame(height: 180)
            .animation(.smooth(duration: 0.6), value: horizon)

          // What the shapes mean, in words.
          HStack(spacing: 14) {
            OddsLegend(color: OddsCone.likely, title: "Most likely")
            OddsLegend(color: OddsCone.possible, title: "Possible")
            OddsLegend(color: color.opacity(0.5), title: isSell ? "Sell zone" : "Buy zone")
          }
          let chance = horizon == .month ? odds.monthChance : odds.quarterChance
          Text(isSell
               ? "Out of 100 likely paths, \(Int((chance * 100).rounded())) reach your sell zone \(Text(horizon.title))."
               : "Out of 100 likely paths, \(Int((chance * 100).rounded())) reach your buy zone \(Text(horizon.title)).")
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: false, vertical: true)

          HStack(spacing: 12) {
            ForEach(Horizon.allCases) { option in
              Button {
                withAnimation(.snappy) { horizon = option }
              } label: {
                OddsRing(chance: option == .month ? odds.monthChance : odds.quarterChance, title: option.title,
                         color: color, isSelected: horizon == option)
              }
              .buttonStyle(.plain)
              .accessibilityAddTraits(horizon == option ? .isSelected : [])
              .compactProLock(!isPro && option == .quarter)
            }
          }
          .sensoryFeedback(.selection, trigger: horizon)

          HStack(spacing: 12) {
            OddsFact(title: "Typical wait", value: waitText(rule: rule, sigma: odds.dailyVolatility), systemImage: "hourglass")
            OddsFact(title: "Likely in 30 days", value: rangeText(sigma: odds.dailyVolatility), systemImage: "arrow.up.and.down")
          }
          .compactProLock(!isPro)
        }
        .proLocked(!isPro && isSell, message: "See your odds of reaching your sell zone with Pro")

        Text("\(odds.lastTriggeredText). Worked out from \(symbol)'s daily moves over the past year, not a prediction.")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.6))
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(18)
      .heroCardStyle(cornerRadius: 26)
      .onAppear { if buyZone == nil { side = .sell } }
    }
  }

  /// How long half of all likely paths take to first reach the zone, from a random walk at this volatility.
  private func waitText(rule: AlertRule, sigma: Double) -> String {
    guard let level = rule.triggerLevel(for: quote), level > 0, sigma > 0 else { return "—" }
    let distance = abs(log(level / quote.price))
    let tradingDays = pow(distance / (0.6745 * sigma), 2)
    let days = max(1, Int((tradingDays * 7 / 5).rounded()))
    return days > 365 ? String(localized: "Over a year") : String(localized: "About \(days) days")
  }

  /// Where the price lands in a month in eight of ten likely paths.
  private func rangeText(sigma: Double) -> String {
    let spread = 1.28 * sigma * sqrt(21)
    return "\(compactPrice(quote.price * exp(-spread), currency: quote.currency))–\(compactPrice(quote.price * exp(spread), currency: quote.currency))"
  }
}

/// One entry in the chart's key: a swatch and what it means.
private struct OddsLegend: View {
  var color: Color
  var title: LocalizedStringKey

  var body: some View {
    HStack(spacing: 5) {
      RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 10)
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.75))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
  }
}

/// One more thing worth knowing about the odds, on a small tile.
private struct OddsFact: View {
  var title: LocalizedStringKey
  var value: String
  var systemImage: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Label(title, systemImage: systemImage)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white.opacity(0.6))
      Text(value)
        .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 16, style: .continuous))
    .accessibilityElement(children: .combine)
  }
}

/// The last two months of closes, then a widening cone of likely prices: the inner band holds half of the
/// outcomes, the outer one eight in ten. The buy zone runs across both.
private struct OddsCone: View {
  /// Half of the likely paths end inside this band.
  static let likely = Color.white.opacity(0.26)
  /// Eight in ten likely paths end inside this band.
  static let possible = Color.white.opacity(0.1)

  var quote: Quote
  var rule: AlertRule
  var sigma: Double
  var days: Int
  var color: Color

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
        .foregroundStyle(color.opacity(0.24))
        .annotation(position: .overlay, alignment: .leading) {
          Text(rule.kind.side == .sell ? "Your sell zone" : "Your buy zone")
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.leading, 4)
        }
      ForEach(bands) { band in
        AreaMark(x: .value("Day", band.day), yStart: .value("Low", band.low), yEnd: .value("High", band.high), series: .value("Band", "outer"))
          .foregroundStyle(OddsCone.possible)
          .interpolationMethod(.monotone)
        AreaMark(x: .value("Day", band.day), yStart: .value("Low", band.innerLow), yEnd: .value("High", band.innerHigh), series: .value("Band", "inner"))
          .foregroundStyle(OddsCone.likely)
          .interpolationMethod(.monotone)
      }
      if let end = bands.last {
        // Where the cone ends: the high and low of eight in ten likely paths.
        PointMark(x: .value("Day", end.day), y: .value("High", end.high))
          .symbolSize(0)
          .annotation(position: .topLeading, spacing: 2) {
            Text(compactPrice(end.high, currency: quote.currency))
              .font(.caption2.weight(.bold).monospacedDigit())
              .foregroundStyle(.white.opacity(0.85))
          }
        PointMark(x: .value("Day", end.day), y: .value("Low", end.low))
          .symbolSize(0)
          .annotation(position: .bottomLeading, spacing: 2) {
            Text(compactPrice(end.low, currency: quote.currency))
              .font(.caption2.weight(.bold).monospacedDigit())
              .foregroundStyle(.white.opacity(0.85))
          }
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
    .chartYAxis(.hidden)
    .chartXScale(domain: 0...(today + days))
    .chartYScale(domain: (low - pad)...(high + pad))
    .accessibilityLabel("Price chart with a cone of likely prices over the next \(days) trading days and your zone")
  }
}

/// A chance as a ring that fills up, with its horizon underneath.
private struct OddsRing: View {
  var chance: Double
  var title: LocalizedStringKey
  var color: Color
  var isSelected: Bool

  var body: some View {
    HStack(spacing: 12) {
      ZStack {
        Circle().stroke(.white.opacity(0.12), lineWidth: 7)
        Circle()
          .trim(from: 0, to: chance)
          .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text(chance, format: .percent.precision(.fractionLength(0)))
          .font(.system(.subheadline, design: .rounded).weight(.bold).monospacedDigit())
          .minimumScaleFactor(0.5)
      }
      .frame(width: 52, height: 52)
      VStack(alignment: .leading, spacing: 1) {
        Text("Chance")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.6))
        Text(title)
          .font(.subheadline.weight(.bold))
          .lineLimit(2)
          .minimumScaleFactor(0.5)
      }
      Spacer(minLength: 0)
    }
    .padding(10)
    .frame(maxWidth: .infinity)
    .background(.white.opacity(isSelected ? 0.14 : 0.05), in: .rect(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .strokeBorder(isSelected ? color.opacity(0.7) : .clear, lineWidth: 1.5)
    }
    .accessibilityElement(children: .combine)
  }
}

/// A small Pro lock for tiles: the content softly blurred under a Pro tag; tapping opens the paywall.
private struct CompactProLock: ViewModifier {
  var isLocked: Bool
  @State private var showsPaywall = false

  func body(content: Content) -> some View {
    if isLocked {
      content
        .blur(radius: 6)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .overlay {
          Button {
            showsPaywall = true
          } label: {
            Label("Unlock with Pro", systemImage: "lock.fill")
              .font(.caption.weight(.bold))
              .foregroundStyle(Brand.owlInk)
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background(Brand.amber, in: .capsule)
          }
          .buttonStyle(.plain)
        }
        .sheet(isPresented: $showsPaywall) { PaywallView() }
    } else {
      content
    }
  }
}

private extension View {
  func compactProLock(_ isLocked: Bool) -> some View {
    modifier(CompactProLock(isLocked: isLocked))
  }
}
