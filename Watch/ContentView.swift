import Charts
import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationStack {
      TabView {
        TodayPage()
        PlansPage()
        WatchlistPage()
        StreakPage()
      }
      .tabViewStyle(.verticalPage)
      .navigationDestination(for: String.self) { StockDetail(symbol: $0) }
    }
    .tint(Brand.buy)
  }
}

// MARK: - Today

/// The portfolio, the market, and today's biggest movers.
private struct TodayPage: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        MarketStatus(market: store.market)
        if let portfolio = store.portfolio {
          PortfolioCard(portfolio: portfolio)
        } else {
          DippHeader(statuses: store.statuses)
        }
        if !store.movers.isEmpty {
          Text("Today's movers")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
          ForEach(store.movers.prefix(4), id: \.symbol) { quote in
            NavigationLink(value: quote.symbol) {
              QuoteRow(quote: quote)
            }
            .buttonStyle(.plain)
          }
        }
        if let updated = store.lastUpdated {
          Text("Updated \(updated, format: .relative(presentation: .named))")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
    }
    .navigationTitle("Dipwise")
    .refreshable { await store.refresh() }
  }
}

/// Whether the US market is open, and when that changes.
private struct MarketStatus: View {
  var market: Quote?

  var body: some View {
    let isOpen = MarketClock.isOpen()
    let next = MarketClock.nextChange()
    HStack(spacing: 6) {
      Circle()
        .fill(isOpen ? Brand.buy : Color.secondary)
        .frame(width: 7, height: 7)
      Text(isOpen ? "Closes \(next.formatted(date: .omitted, time: .shortened))" : "Opens \(next.formatted(.dateTime.weekday(.abbreviated).hour().minute()))")
        .font(.caption2.weight(.semibold))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Spacer(minLength: 2)
      if let market {
        Text("S&P \(changeText(market.change))")
          .font(.caption2.weight(.bold).monospacedDigit())
          .foregroundStyle(market.change >= 0 ? Brand.buy : Brand.sell)
          .lineLimit(1)
          .fixedSize()
      }
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(isOpen ? "Market open, closes \(next.formatted(date: .omitted, time: .shortened))" : "Market closed, opens \(next.formatted(.dateTime.weekday(.wide).hour().minute()))")
  }
}

private struct PortfolioCard: View {
  var portfolio: WatchPortfolio

  var body: some View {
    let color = portfolio.dayChangeAmount >= 0 ? Brand.buy : Brand.sell
    VStack(alignment: .leading, spacing: 4) {
      Text("Portfolio")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(portfolio.formatted(portfolio.value))
        .font(.system(.title2, design: .rounded).weight(.semibold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text("\(portfolio.dayChangeAmount >= 0 ? "+" : "")\(portfolio.formatted(portfolio.dayChangeAmount)) · \(changeText(portfolio.dayChange))")
        .font(.footnote.weight(.semibold).monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      if portfolio.history.count > 1 {
        Chart(Array(portfolio.history.enumerated()), id: \.offset) { index, value in
          AreaMark(x: .value("Day", index), y: .value("Value", value))
            .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
            .interpolationMethod(.monotone)
          LineMark(x: .value("Day", index), y: .value("Value", value))
            .foregroundStyle(color)
            .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 44)
        .accessibilityHidden(true)
      }
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Brand.nightMiddle, in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

/// A stock with its price, a tiny chart, and today's move.
private struct QuoteRow: View {
  var quote: Quote

  var body: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 1) {
        Text(quote.symbol)
          .font(.headline)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Text(quote.formatted(quote.price))
          .font(.caption2.monospacedDigit())
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      .layoutPriority(1)
      Spacer(minLength: 2)
      MiniLine(values: Array(quote.closes.suffix(20)))
        .frame(width: 36, height: 18)
      Text(changeText(quote.change))
        .font(.caption2.weight(.bold).monospacedDigit())
        .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
        .lineLimit(1)
        .fixedSize()
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(Color(white: 0.14), in: .rect(cornerRadius: 14))
    .accessibilityElement(children: .combine)
  }
}

private struct MiniLine: View {
  var values: [Double]

  var body: some View {
    let isUp = (values.last ?? 0) >= (values.first ?? 0)
    Chart(Array(values.enumerated()), id: \.offset) { index, value in
      LineMark(x: .value("Day", index), y: .value("Price", value))
        .foregroundStyle(isUp ? Brand.buy : Brand.sell)
        .interpolationMethod(.monotone)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .chartYScale(domain: .automatic(includesZero: false))
    .accessibilityHidden(true)
  }
}

// MARK: - Plans

/// Dippy's greeting and every stock with alerts, closest to triggering first.
private struct PlansPage: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        DippHeader(statuses: store.statuses)
        if store.targets.isEmpty {
          Text("Set a buy zone in Dipwise on your iPhone.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        ForEach(store.stocks, id: \.symbol) { stock in
          NavigationLink(value: stock.symbol) {
            StockCard(symbol: stock.symbol, quote: store.quotes[stock.symbol], nearest: stock.statuses.first, count: stock.statuses.count)
          }
          .buttonStyle(.plain)
        }
      }
    }
    .navigationTitle("Plans")
    .refreshable { await store.refresh() }
  }
}

/// Dippy with a one-line take on what matters most.
private struct DippHeader: View {
  var statuses: [TargetStatus]
  @State private var hops = 0

  private var message: String {
    guard let first = statuses.first else { return "Hoo! Nothing to watch yet." }
    if first.distance == 0 { return "\(first.target.symbol) is in your plan!" }
    if !MarketClock.isOpen() { return "Markets closed. Your plans are safe." }
    return "\(first.target.symbol) is \(distanceText(first.distance)) away"
  }

  var body: some View {
    HStack(spacing: 8) {
      OwlMark(blink: MarketClock.isOpen() ? 0 : 1)
        .frame(width: 34, height: 40)
        .phaseAnimator([0.0, -6.0, 0.0], trigger: hops) { view, lift in
          view.offset(y: lift)
        }
        .onTapGesture { hops += 1 }
      Text(message)
        .font(.footnote.weight(.semibold))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Brand.nightMiddle, in: .rect(cornerRadius: 16))
    .sensoryFeedback(.impact(weight: .light), trigger: hops)
    .accessibilityElement(children: .combine)
  }
}

private struct StockCard: View {
  var symbol: String
  var quote: Quote?
  var nearest: TargetStatus?
  var count: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(symbol).font(.headline)
        Spacer()
        if let quote {
          Text(changeText(quote.change))
            .font(.footnote.weight(.semibold).monospacedDigit())
            .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
        }
      }
      if let quote {
        Text(quote.formatted(quote.price))
          .font(.title3.bold().monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      if let nearest {
        let color = nearest.target.rule.kind.side.brandColor
        Gauge(value: nearest.progress) { EmptyView() }
          .gaugeStyle(.accessoryLinearCapacity)
          .tint(color)
        HStack {
          Text(nearest.target.rule.kind.title)
            .foregroundStyle(color)
            .lineLimit(1)
          Spacer()
          Text(nearest.distance.map { $0 == 0 ? "Now" : $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—")
            .monospacedDigit()
        }
        .font(.caption2.weight(.semibold))
        if count > 1 {
          Text("+\(count - 1) more \(count == 2 ? "alert" : "alerts")")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding(10)
    .background(Brand.nightMiddle, in: .rect(cornerRadius: 16))
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Watchlist

/// Every stock followed on iPhone.
private struct WatchlistPage: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    List {
      if store.allSymbols.isEmpty {
        Text("Add stocks in Dipwise on your iPhone.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
      ForEach(store.allSymbols, id: \.self) { symbol in
        NavigationLink(value: symbol) {
          if let quote = store.quotes[symbol] {
            HStack(spacing: 6) {
              VStack(alignment: .leading, spacing: 1) {
                Text(symbol)
                  .font(.headline)
                  .lineLimit(1)
                  .minimumScaleFactor(0.6)
                Text(quote.formatted(quote.price))
                  .font(.caption2.monospacedDigit())
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.6)
              }
              .layoutPriority(1)
              Spacer(minLength: 2)
              MiniLine(values: Array(quote.closes.suffix(20)))
                .frame(width: 34, height: 18)
              Text(changeText(quote.change))
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
                .fixedSize()
            }
          } else {
            Text(symbol).font(.headline)
          }
        }
      }
    }
    .navigationTitle("Watchlist")
  }
}

// MARK: - Stock

/// One stock: a chart to scrub with the Digital Crown, key numbers, the position, and every alert.
private struct StockDetail: View {
  enum Range: Int, CaseIterable, Identifiable {
    case week = 5
    case month = 21
    case quarter = 63
    case year = 252

    var id: Self { self }

    var title: String {
      switch self {
      case .week: "1W"
      case .month: "1M"
      case .quarter: "3M"
      case .year: "1Y"
      }
    }
  }

  var symbol: String
  @Environment(WatchTargetStore.self) private var store
  @State private var range: Range = .month
  @State private var crown = 0.0
  @State private var didSetCrown = false

  var body: some View {
    let quote = store.quotes[symbol]
    let statuses = store.statuses.filter { $0.target.symbol == symbol }
    ScrollView {
      VStack(alignment: .leading, spacing: 10) {
        if let quote {
          chartCard(quote)
          keyNumbers(quote)
          if let stock = store.stock(symbol), stock.isOwned, let shares = stock.shares {
            position(quote: quote, shares: shares, averageCost: stock.averageCost ?? 0)
          }
        } else {
          ProgressView()
        }
        ForEach(statuses) { status in
          let color = status.target.rule.kind.side.brandColor
          VStack(alignment: .leading, spacing: 4) {
            Label(status.summary, systemImage: status.target.rule.kind.systemImage)
              .font(.footnote.weight(.semibold))
              .foregroundStyle(color)
            Gauge(value: status.progress) { EmptyView() }
              .gaugeStyle(.accessoryLinearCapacity)
              .tint(color)
            Text(status.distance.map { $0 == 0 ? "Active now" : "\($0.formatted(.percent.precision(.fractionLength(1)))) away" } ?? "")
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
          .padding(10)
          .background(color.opacity(0.15), in: .rect(cornerRadius: 14))
          .accessibilityElement(children: .combine)
        }
      }
    }
    .navigationTitle(symbol)
  }

  private func chartCard(_ quote: Quote) -> some View {
    let values = Array(quote.closes.suffix(range.rawValue))
    let dates = Array(quote.dates.suffix(range.rawValue))
    let index = values.isEmpty ? 0 : min(values.count - 1, max(0, Int(crown.rounded())))
    let isLatest = index >= values.count - 1
    let shown = isLatest ? quote.price : (values.isEmpty ? quote.price : values[index])
    let color = (values.last ?? 0) >= (values.first ?? 0) ? Brand.buy : Brand.sell
    return VStack(alignment: .leading, spacing: 4) {
      Text(quote.formatted(shown))
        .font(.system(.title2, design: .rounded).weight(.semibold))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText())
      Group {
        if isLatest {
          Text("\(changeText(quote.change)) today")
            .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
        } else {
          Text("\(dates.indices.contains(index) ? dates[index].formatted(.dateTime.month(.abbreviated).day()) : "") · \(changeText(quote.price / max(shown, 0.0001) - 1)) since")
            .foregroundStyle(.secondary)
        }
      }
      .font(.caption2.weight(.semibold).monospacedDigit())
      .lineLimit(1)
      .minimumScaleFactor(0.7)
      if values.count > 1 {
        Chart {
          ForEach(Array(values.enumerated()), id: \.offset) { offset, value in
            LineMark(x: .value("Day", offset), y: .value("Price", value))
              .foregroundStyle(color)
              .interpolationMethod(.monotone)
          }
          if !isLatest {
            RuleMark(x: .value("Selected", index))
              .foregroundStyle(.white.opacity(0.6))
            PointMark(x: .value("Selected", index), y: .value("Price", values[index]))
              .foregroundStyle(.white)
              .symbolSize(30)
          }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 64)
        .focusable()
        .digitalCrownRotation($crown, from: 0, through: Double(max(values.count - 1, 1)), by: 1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .accessibilityLabel("Price chart. Turn the Digital Crown to read past prices.")
      }
      HStack(spacing: 4) {
        ForEach(Range.allCases) { option in
          Button(option.title) {
            range = option
            crown = Double(min(option.rawValue, quote.closes.count) - 1)
          }
          .font(.caption2.weight(.bold))
          .buttonStyle(.plain)
          .padding(.horizontal, 7)
          .padding(.vertical, 3)
          .background(range == option ? AnyShapeStyle(.white.opacity(0.22)) : AnyShapeStyle(.clear), in: .capsule)
          .foregroundStyle(range == option ? .white : .secondary)
          .accessibilityAddTraits(range == option ? .isSelected : [])
        }
      }
      .frame(maxWidth: .infinity)
    }
    .padding(10)
    .background(Brand.nightMiddle, in: .rect(cornerRadius: 16))
    .onAppear {
      guard !didSetCrown else { return }
      didSetCrown = true
      crown = Double(min(range.rawValue, quote.closes.count) - 1)
    }
  }

  private func keyNumbers(_ quote: Quote) -> some View {
    VStack(spacing: 6) {
      stat("52-week range", "\(quote.formatted(quote.low52)) – \(quote.formatted(quote.high52))")
      stat("From high", quote.drawdownFromHigh.formatted(.percent.precision(.fractionLength(1))))
      if let rsi = quote.rsi() {
        stat("RSI", "\(Int(rsi))")
      }
    }
    .padding(10)
    .background(Color(white: 0.14), in: .rect(cornerRadius: 14))
  }

  private func position(quote: Quote, shares: Double, averageCost: Double) -> some View {
    let value = quote.price * shares
    let gain = averageCost > 0 ? quote.price / averageCost - 1 : nil
    return VStack(alignment: .leading, spacing: 6) {
      Text("Your position")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
      stat("\(shares.formatted()) shares", quote.formatted(value))
      if let gain {
        stat("Total return", changeText(gain), color: gain >= 0 ? Brand.buy : Brand.sell)
      }
    }
    .padding(10)
    .background(Color(white: 0.14), in: .rect(cornerRadius: 14))
  }

  private func stat(_ title: String, _ value: String, color: Color = .primary) -> some View {
    HStack {
      Text(title)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      Spacer(minLength: 4)
      Text(value)
        .monospacedDigit()
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
    .font(.caption2.weight(.semibold))
    .accessibilityElement(children: .combine)
  }
}

// MARK: - Streak

/// Dippy, the streak, and today's brief.
private struct StreakPage: View {
  @Environment(WatchTargetStore.self) private var store
  @State private var flaps = 0

  var body: some View {
    let progress = store.progress
    VStack(spacing: 8) {
      PhaseAnimator([0.0, 1.0, 0.3, 1.0, 0.0], trigger: flaps) { spread in
        OwlMark(wingSpread: spread)
          .frame(height: 70)
      } animation: { _ in .easeInOut(duration: 0.12) }
        .onTapGesture { flaps += 1 }
        .sensoryFeedback(.impact, trigger: flaps)
      HStack(spacing: 4) {
        Image(systemName: "flame.fill")
          .foregroundStyle(progress.streak > 0 ? Brand.amber : .secondary)
        Text("\(progress.streak)")
          .font(.title.bold())
      }
      Text(progress.briefDoneToday ? "Brief done today" : "Brief ready on iPhone")
        .font(.footnote)
        .foregroundStyle(progress.briefDoneToday ? Brand.buy : Brand.amber)
      Text("Level \(progress.level) · \(progress.levelTitle)")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Brand.nightMiddle.opacity(0.6))
    .accessibilityElement(children: .combine)
  }
}

/// "+1.2%" style text for a change.
private func changeText(_ change: Double) -> String {
  change.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))
}

private func distanceText(_ distance: Double?) -> String {
  guard let distance else { return "—" }
  return distance == 0 ? "Now" : distance.formatted(.percent.precision(.fractionLength(1)))
}
