import SwiftData
import SwiftUI

/// Desk Mode: a live portfolio tracker for iPhone Duo standing like a tent on a desk, on its outer display.
/// The time and today's market along the top; your portfolio with a chart you can scrub; and a panel that pages by
/// itself between your biggest movers, your closest plans, and what the flock is doing, until you tap a page. Your
/// stocks run along the bottom like a ticker. The screen stays awake while it's open.
struct DeskModeView: View {
  /// Renders a fixed moment, for App Store screenshots.
  var frozenDate: Date?

  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(FlockService.self) private var flock
  @State private var page = Page.movers
  @State private var isTouched = false
  @State private var selectedIndex: Int?
  @State private var tickerWidth: CGFloat = 0

  enum Page: String, CaseIterable, Identifiable {
    case movers
    case plans
    case flock

    var id: Self { self }

    var title: LocalizedStringKey {
      switch self {
      case .movers: "Movers"
      case .plans: "Plans"
      case .flock: "Flock"
      }
    }
  }

  private var pages: [Page] { flock.isAvailable ? Page.allCases : [.movers, .plans] }

  private var summary: PortfolioSummary {
    PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase, intraday: quotes.intraday)
  }

  /// Every active plan with its quote, closest to firing first.
  private var plans: [TargetStatus] {
    summary.activeAlerts.compactMap { alert in
      quotes[alert.symbol].map { TargetStatus(target: WatchedTarget(id: alert.id, symbol: alert.symbol, name: $0.name, rule: alert.rule), quote: $0) }
    }
    .sorted { ($0.distance ?? 1) < ($1.distance ?? 1) }
  }

  var body: some View {
    TimelineView(.everyMinute) { context in
      let now = frozenDate ?? context.date
      VStack(spacing: 12) {
        topBar(now)
        HStack(alignment: .top, spacing: 14) {
          portfolio
            .frame(maxWidth: .infinity)
          panel
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
        ticker
      }
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
    }
    .foregroundStyle(.white)
    .background {
      LinearGradient(colors: [Brand.nightTop, Brand.nightMiddle, Brand.nightBottom], startPoint: .top, endPoint: .bottom)
        .ignoresSafeArea()
    }
    .environment(\.colorScheme, .dark)
    .statusBarHidden()
    .persistentSystemOverlays(.hidden)
    .sensoryFeedback(.selection, trigger: page)
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    .task {
      guard frozenDate == nil else { return }
      // Fresh prices every minute while it stands on the desk.
      while !Task.isCancelled {
        await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock)
        try? await Task.sleep(for: .seconds(60))
      }
    }
    .task {
      guard frozenDate == nil else { return }
      // The panel tours its pages by itself until someone taps one.
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(12))
        guard !isTouched, let index = pages.firstIndex(of: page) else { continue }
        withAnimation(.smooth) { page = pages[(index + 1) % pages.count] }
      }
    }
  }

  // MARK: Top bar

  private func topBar(_ now: Date) -> some View {
    let isOpen = MarketClock.isOpen(at: now)
    let bell = MarketClock.nextChange(after: now)
    let countdown = countdownText(to: bell, from: now, isLive: frozenDate == nil)
    let market = quotes[Benchmark.symbol]
    return HStack(spacing: 10) {
      Text(now, format: .dateTime.hour().minute())
        .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
      Text(now, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.6))
      Spacer(minLength: 6)
      HStack(spacing: 6) {
        Circle().fill(isOpen ? Brand.buy : .white.opacity(0.4)).frame(width: 7, height: 7)
        Text(isOpen ? "Closes in \(countdown)" : "Opens in \(countdown)")
          .lineLimit(1)
      }
      .font(.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(.white.opacity(0.08), in: .capsule)
      if let market, abs(market.change) >= 0.0005 {
        HStack(spacing: 5) {
          Text("S&P 500")
            .foregroundStyle(.white.opacity(0.7))
          Text(changeText(market.change))
            .foregroundStyle(market.change >= 0 ? Brand.buy : Brand.sell)
        }
        .font(.caption.weight(.bold).monospacedDigit())
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08), in: .capsule)
      }
      LivelyOwl(mood: isOpen ? .calm : .sleeping)
        .frame(width: 30, height: 35)
      Button("Close Desk Mode", systemImage: "xmark") { dismiss() }
        .labelStyle(.iconOnly)
        .font(.caption.weight(.bold))
        .foregroundStyle(.white.opacity(0.7))
        .frame(width: 30, height: 30)
        .background(.white.opacity(0.1), in: .circle)
    }
  }

  // MARK: Portfolio

  private var portfolio: some View {
    let summary = summary
    let isUp = summary.dayChangeAmount >= 0
    let day = summary.history(period: .preset(.day))
    let history = day.values.count > 2 ? day : summary.history(period: .preset(.month))
    return VStack(alignment: .leading, spacing: 4) {
      Text("Portfolio")
        .font(.caption.weight(.bold))
        .foregroundStyle(.white.opacity(0.6))
      Text(quotes.formatBase(summary.totalValue))
        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .contentTransition(.numericText())
      Label("\(changeText(summary.dayChange)) · \(isUp ? "+" : "")\(quotes.formatBase(summary.dayChangeAmount)) today",
            systemImage: isUp ? "arrow.up.right" : "arrow.down.right")
        .font(.subheadline.weight(.semibold).monospacedDigit())
        .foregroundStyle(isUp ? Brand.buy : Brand.sell)
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      InteractiveChart(values: history.values, dates: history.dates,
                       lineColor: (history.values.last ?? 0) >= (history.values.first ?? 0) ? Brand.buy : Brand.sell,
                       gridColor: .white.opacity(0.08), owlSize: 30, selectedIndex: $selectedIndex)
        .frame(maxHeight: .infinity)
        .padding(.top, 4)
    }
    .padding(14)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 20, style: .continuous))
  }

  // MARK: Panel

  private var panel: some View {
    VStack(alignment: .leading, spacing: 10) {
      // Plain buttons rather than a segmented control, so the page tabs read the same in every render.
      HStack(spacing: 4) {
        ForEach(pages) { option in
          Button {
            isTouched = true
            withAnimation(.smooth) { page = option }
          } label: {
            Text(option.title)
              .font(.caption.weight(.bold))
              .foregroundStyle(page == option ? Brand.owlInk : .white.opacity(0.75))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
              .background(page == option ? AnyShapeStyle(Brand.mint) : AnyShapeStyle(.clear), in: .capsule)
              .contentShape(.capsule)
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(page == option ? .isSelected : [])
        }
      }
      .padding(3)
      .background(.white.opacity(0.08), in: .capsule)
      Group {
        switch page {
        case .movers: movers
        case .plans: plansPage
        case .flock: flockPage
        }
      }
      .frame(maxHeight: .infinity, alignment: .top)
      .transition(.opacity.combined(with: .move(edge: .trailing)))
      .id(page)
    }
    .padding(12)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.white.opacity(0.06), in: .rect(cornerRadius: 20, style: .continuous))
  }

  private var movers: some View {
    let positions = summary.positions.sorted { abs($0.quote.change) > abs($1.quote.change) }.prefix(4)
    return VStack(spacing: 6) {
      ForEach(Array(positions), id: \.holding.id) { position in
        HStack(spacing: 8) {
          WidgetBadge(symbol: position.holding.symbol, size: 26)
          VStack(alignment: .leading, spacing: 0) {
            Text(position.holding.symbol)
              .font(.subheadline.bold())
            Text(position.quote.formatted(position.quote.price))
              .font(.caption.monospacedDigit())
              .foregroundStyle(.white.opacity(0.6))
          }
          Spacer(minLength: 4)
          WidgetChangePill(change: position.quote.change)
        }
        .frame(maxHeight: .infinity)
        .accessibilityElement(children: .combine)
      }
    }
  }

  @ViewBuilder
  private var plansPage: some View {
    if plans.isEmpty {
      Text("Set a buy zone and Dippy will watch it here.")
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.7))
    } else {
      VStack(spacing: 8) {
        ForEach(plans.prefix(3)) { status in
          VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
              WidgetBadge(symbol: status.target.symbol, size: 24)
              VStack(alignment: .leading, spacing: 0) {
                Text(status.target.symbol)
                  .font(.caption.bold())
                Text(compactSummary(status))
                  .font(.caption2.weight(.semibold))
                  .foregroundStyle(status.target.rule.kind.side.brandColor)
                  .lineLimit(1)
                  .minimumScaleFactor(0.5)
              }
              Spacer(minLength: 4)
              DistanceLabel(status: status)
            }
            ZoneRuler(status: status)
          }
          .frame(maxHeight: .infinity)
          .accessibilityElement(children: .combine)
        }
      }
    }
  }

  private var flockPage: some View {
    let overview = flock.overview
    return VStack(alignment: .leading, spacing: 8) {
      HStack {
        Label("\(overview.investors.formatted()) anonymous investors", systemImage: "person.3.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white.opacity(0.75))
          .lineLimit(1)
          .minimumScaleFactor(0.5)
        Spacer(minLength: 4)
        Text(overview.mood.bullShare, format: .percent.precision(.fractionLength(0)))
          .font(.system(.subheadline, design: .rounded).weight(.bold))
          .foregroundStyle(overview.mood.bullShare >= 0.5 ? Brand.buy : Brand.sell)
      }
      GeometryReader { geometry in
        HStack(spacing: 3) {
          Capsule().fill(Brand.buy).frame(width: max(6, (geometry.size.width - 3) * overview.mood.bullShare))
          Capsule().fill(Brand.sell)
        }
      }
      .frame(height: 7)
      Text("In the crowd's buy zone")
        .font(.caption.weight(.bold))
        .foregroundStyle(.white.opacity(0.6))
        .padding(.top, 2)
      ForEach(flock.radar.prefix(3)) { item in
        HStack(spacing: 8) {
          WidgetBadge(symbol: item.symbol, size: 22)
          Text(item.symbol)
            .font(.caption.bold())
          Spacer(minLength: 4)
          Text("\(item.watchers) waiting")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
          Text("\(item.conviction)%")
            .font(.caption.weight(.bold).monospacedDigit())
            .foregroundStyle(Brand.buy)
        }
        .frame(maxHeight: .infinity)
      }
    }
  }

  // MARK: Ticker

  /// Every stock you follow, drifting slowly along the bottom like a ticker.
  private var ticker: some View {
    let items = summary.positions.map(\.quote)
    return TimelineView(.animation(minimumInterval: 1 / 30, paused: frozenDate != nil)) { context in
      GeometryReader { geometry in
        let row = HStack(spacing: 18) {
          ForEach(items, id: \.symbol) { quote in
            HStack(spacing: 5) {
              Text(quote.symbol).font(.caption.weight(.bold))
              Text(quote.formatted(quote.price))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
              Text(changeText(quote.change))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
            }
          }
        }
        .fixedSize()
        let offset = frozenDate == nil && tickerWidth > 0
          ? -CGFloat(context.date.timeIntervalSinceReferenceDate * 24).truncatingRemainder(dividingBy: tickerWidth) : 0
        HStack(spacing: 18) {
          row.onGeometryChange(for: CGFloat.self) { $0.size.width + 18 } action: { tickerWidth = $0 }
          row
        }
        .offset(x: offset)
        .frame(width: geometry.size.width, alignment: .leading)
        .clipped()
      }
    }
    .frame(height: 18)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Your stocks today")
  }
}
