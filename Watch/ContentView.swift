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
    .foregroundStyle(.white)
  }
}

extension View {
  /// Every page sits on the same navy as the iPhone app's hero cards.
  fileprivate func navyPage() -> some View {
    containerBackground(Brand.nightMiddle, for: .tabView)
  }
}

// MARK: - Today

/// Dippy, the portfolio, the closest plans, and today's movers.
private struct TodayPage: View {
  @Environment(WatchTargetStore.self) private var store
  @State private var hops = 0

  private var mood: OwlMood {
    OwlMood.current(dayChange: store.portfolio?.dayChange, isAwake: false)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        WatchDippyHeader(greeting: WatchGreeting.text(), message: mood.message(change: nil), isAsleep: mood == .sleeping, hops: hops)
          .onTapGesture { hops += 1 }
          .sensoryFeedback(.impact(weight: .light), trigger: hops)
        if let portfolio = store.portfolio {
          WatchPortfolioHero(portfolio: portfolio)
        }
        if !store.stocks.isEmpty {
          WatchSectionTitle(title: "Closest plans")
          ForEach(store.stocks.prefix(2), id: \.symbol) { stock in
            if let first = stock.statuses.first {
              NavigationLink(value: stock.symbol) {
                WatchPlanCard(status: first, extraCount: stock.statuses.count - 1)
              }
              .buttonStyle(.plain)
            }
          }
        }
        if !store.movers.isEmpty {
          WatchSectionTitle(title: "Today's movers")
          ForEach(store.movers.prefix(3), id: \.symbol) { quote in
            NavigationLink(value: quote.symbol) {
              WatchMoverRow(quote: quote)
            }
            .buttonStyle(.plain)
          }
        }
        WatchMarketStatus(isOpen: MarketClock.isOpen(), nextChange: MarketClock.nextChange(), market: store.market)
          .padding(.top, 4)
        if store.allSymbols.isEmpty {
          Text("Add stocks in Dipwise on your iPhone and Dippy will bring them here.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
        }
      }
    }
    .navigationTitle("Dipwise")
    .refreshable { await store.refresh() }
    .navyPage()
  }
}

// MARK: - Plans

/// Every stock with alerts, closest to triggering first.
private struct PlansPage: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 8) {
        if store.stocks.isEmpty {
          VStack(spacing: 8) {
            WidgetOwl(size: 44)
            Text("Set a buy zone in Dipwise on your iPhone. Dippy will watch it here.")
              .font(.footnote)
              .multilineTextAlignment(.center)
              .foregroundStyle(.white.opacity(0.75))
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 10)
        }
        ForEach(store.stocks, id: \.symbol) { stock in
          if let first = stock.statuses.first {
            NavigationLink(value: stock.symbol) {
              WatchPlanCard(status: first, extraCount: stock.statuses.count - 1)
            }
            .buttonStyle(.plain)
          }
        }
      }
    }
    .navigationTitle("Plans")
    .refreshable { await store.refresh() }
    .navyPage()
  }
}

// MARK: - Watchlist

/// Every stock followed on iPhone.
private struct WatchlistPage: View {
  @Environment(WatchTargetStore.self) private var store

  var body: some View {
    ScrollView {
      VStack(spacing: 8) {
        if store.allSymbols.isEmpty {
          Text("Add stocks in Dipwise on your iPhone.")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.75))
        }
        ForEach(store.allSymbols, id: \.self) { symbol in
          NavigationLink(value: symbol) {
            if let quote = store.quotes[symbol] {
              WatchMoverRow(quote: quote)
            } else {
              Text(symbol)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .watchTile(cornerRadius: 16)
            }
          }
          .buttonStyle(.plain)
        }
      }
    }
    .navigationTitle("Watchlist")
    .refreshable { await store.refresh() }
    .navyPage()
  }
}

// MARK: - Stock

/// One stock: a chart you scrub with the Digital Crown, key numbers, your position, and every alert.
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
      VStack(alignment: .leading, spacing: 8) {
        if let quote {
          chartCard(quote)
          HStack(spacing: 6) {
            tile("Today", changeText(quote.change), color: quote.change >= 0 ? Brand.buy : Brand.sell)
            tile("From high", quote.drawdownFromHigh.formatted(.percent.precision(.fractionLength(0))), color: .white)
          }
          if let stock = store.stock(symbol), stock.isOwned, let shares = stock.shares {
            position(quote: quote, shares: shares, averageCost: stock.averageCost ?? 0)
          }
        } else {
          ProgressView()
        }
        if !statuses.isEmpty {
          WatchSectionTitle(title: "Your plan")
          ForEach(statuses) { status in
            WatchPlanCard(status: status)
          }
        }
        if let quote {
          WatchSectionTitle(title: "52-week range")
          Text("\(compactPrice(quote.low52, currency: quote.currency)) – \(compactPrice(quote.high52, currency: quote.currency))")
            .font(.system(size: 13, weight: .semibold).monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
      }
    }
    .navigationTitle(symbol)
    .containerBackground(Brand.nightMiddle, for: .navigation)
  }

  private func chartCard(_ quote: Quote) -> some View {
    let values = Array(quote.closes.suffix(range.rawValue))
    let dates = Array(quote.dates.suffix(range.rawValue))
    let index = values.isEmpty ? 0 : min(values.count - 1, max(0, Int(crown.rounded())))
    let isLatest = index >= values.count - 1
    let shown = isLatest || values.isEmpty ? quote.price : values[index]
    let color = (values.last ?? 0) >= (values.first ?? 0) ? Brand.buy : Brand.sell
    return VStack(alignment: .leading, spacing: 3) {
      Text(isLatest ? quote.name : (dates.indices.contains(index) ? dates[index].formatted(.dateTime.month(.abbreviated).day()) : ""))
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(isLatest ? .white.opacity(0.65) : Brand.buy)
        .lineLimit(1)
      Text(quote.formatted(shown))
        .font(.system(size: 26, weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText())
      Text(isLatest ? "\(changeText(quote.change)) today" : "\(changeText(quote.price / max(shown, 0.0001) - 1)) since then")
        .font(.system(size: 12, weight: .semibold).monospacedDigit())
        .foregroundStyle(isLatest ? (quote.change >= 0 ? Brand.buy : Brand.sell) : .white.opacity(0.7))
        .lineLimit(1)
      if values.count > 1 {
        Chart {
          ForEach(Array(values.enumerated()), id: \.offset) { offset, value in
            AreaMark(x: .value("Day", offset), y: .value("Price", value))
              .foregroundStyle(LinearGradient(colors: [color.opacity(0.25), color.opacity(0)], startPoint: .top, endPoint: .bottom))
              .interpolationMethod(.monotone)
            LineMark(x: .value("Day", offset), y: .value("Price", value))
              .foregroundStyle(color)
              .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
              .interpolationMethod(.monotone)
          }
          if !isLatest {
            RuleMark(x: .value("Selected", index))
              .foregroundStyle(.white.opacity(0.5))
            PointMark(x: .value("Selected", index), y: .value("Price", values[index]))
              .foregroundStyle(.white)
              .symbolSize(36)
          }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 62)
        .focusable()
        .digitalCrownRotation($crown, from: 0, through: Double(max(values.count - 1, 1)), by: 1,
                              sensitivity: .medium, isContinuous: false, isHapticFeedbackEnabled: true)
        .accessibilityLabel("Price chart. Turn the Digital Crown to read past prices.")
      }
      HStack(spacing: 2) {
        ForEach(Range.allCases) { option in
          Button(option.title) {
            range = option
            crown = Double(min(option.rawValue, quote.closes.count) - 1)
          }
          .font(.system(size: 12, weight: .bold))
          .buttonStyle(.plain)
          .frame(maxWidth: .infinity, minHeight: 24)
          .background(range == option ? AnyShapeStyle(.white.opacity(0.18)) : AnyShapeStyle(.clear), in: .capsule)
          .foregroundStyle(range == option ? .white : .white.opacity(0.6))
          .accessibilityAddTraits(range == option ? .isSelected : [])
        }
      }
      .padding(2)
      .background(.white.opacity(0.06), in: .capsule)
    }
    .padding(10)
    .watchTile()
    .onAppear {
      guard !didSetCrown else { return }
      didSetCrown = true
      crown = Double(min(range.rawValue, quote.closes.count) - 1)
    }
  }

  private func tile(_ title: String, _ value: String, color: Color) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.white.opacity(0.65))
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .watchTile(cornerRadius: 14)
    .accessibilityElement(children: .combine)
  }

  private func position(quote: Quote, shares: Double, averageCost: Double) -> some View {
    let gain = averageCost > 0 ? quote.price / averageCost - 1 : nil
    return HStack(spacing: 6) {
      tile("\(shares.formatted()) shares", compactPrice(quote.price * shares, currency: quote.currency), color: .white)
      if let gain {
        tile("Return", changeText(gain), color: gain >= 0 ? Brand.buy : Brand.sell)
      }
    }
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
          .frame(height: 64)
      } animation: { _ in .easeInOut(duration: 0.12) }
        .onTapGesture { flaps += 1 }
        .sensoryFeedback(.impact, trigger: flaps)
      HStack(spacing: 4) {
        Image(systemName: "flame.fill")
          .foregroundStyle(progress.streak > 0 ? Brand.amber : .white.opacity(0.4))
        Text("\(progress.streak)")
          .font(.system(size: 32, weight: .bold, design: .rounded))
      }
      Text(progress.briefDoneToday ? "Brief done today" : "Your brief is ready on iPhone")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(progress.briefDoneToday ? Brand.buy : Brand.amber)
        .multilineTextAlignment(.center)
      Text("Level \(progress.level) · \(progress.levelTitle)")
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.65))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityElement(children: .combine)
    .navyPage()
  }
}
