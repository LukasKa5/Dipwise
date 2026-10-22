import SwiftData
import SwiftUI

/// Desk Mode: Dipwise as a calm, always-on tracker for your desk. In landscape it splits into two panels, the live
/// portfolio on top and your plans below, so a half-folded iPhone Duo stands like a tiny trading terminal. On iPad
/// and iPhone it fills the screen the same way. The screen stays awake while it's open.
struct DeskModeView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(FlockService.self) private var flock
  @State private var selectedIndex: Int?
  @State private var focus = 0

  /// Screenshots launched with `-marketingDate` freeze the clock at 9:41, with the market open, like every other screen.
  private var clock: Date {
    #if DEBUG
    if let day = QuoteService.marketingDate {
      return Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: day) ?? day
    }
    #endif
    return .now
  }

  private var isMarketOpen: Bool {
    #if DEBUG
    if QuoteService.marketingDate != nil { return true }
    #endif
    return MarketClock.isOpen()
  }

  private var summary: PortfolioSummary {
    PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase, intraday: quotes.intraday)
  }

  /// Every active plan with its quote, closest to firing first.
  private var plans: [(alert: PriceAlert, quote: Quote)] {
    summary.activeAlerts.compactMap { alert in quotes[alert.symbol].map { (alert, $0) } }
      .sorted { ($0.alert.distance(for: $0.quote) ?? 1) < ($1.alert.distance(for: $1.quote) ?? 1) }
  }

  var body: some View {
    GeometryReader { geometry in
      let isWide = geometry.size.width > geometry.size.height
      ZStack {
        LinearGradient(colors: [Brand.nightTop, Brand.nightMiddle, Brand.nightBottom], startPoint: .top, endPoint: .bottom)
          .ignoresSafeArea()
        if isWide {
          // Two panels, split at the middle like the fold of a half-open iPhone Duo.
          VStack(spacing: 0) {
            portfolioPanel(compact: true)
              .frame(height: geometry.size.height / 2)
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
            plansPanel(columns: 3)
              .frame(height: geometry.size.height / 2)
          }
        } else {
          VStack(spacing: 18) {
            portfolioPanel(compact: false)
            plansPanel(columns: 1)
          }
          .padding(.vertical, 12)
        }
      }
      .overlay(alignment: .topTrailing) {
        Button("Close Desk Mode", systemImage: "xmark") { dismiss() }
          .labelStyle(.iconOnly)
          .font(.headline)
          .foregroundStyle(.white.opacity(0.75))
          .frame(width: 40, height: 40)
          .background(.white.opacity(0.1), in: .circle)
          .padding(16)
      }
    }
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
    .statusBarHidden()
    .persistentSystemOverlays(.hidden)
    .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
    .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    .task {
      // Fresh prices every minute while it sits on the desk.
      while !Task.isCancelled {
        await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock)
        try? await Task.sleep(for: .seconds(60))
      }
    }
  }

  // MARK: Panels

  private func portfolioPanel(compact: Bool) -> some View {
    let summary = summary
    let history = summary.history(period: .preset(.day)).values.count > 2 ? summary.history(period: .preset(.day)) : summary.history(period: .preset(.month))
    let isUp = summary.dayChangeAmount >= 0
    return HStack(alignment: .center, spacing: 28) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 8) {
          Circle().fill(isMarketOpen ? Brand.buy : .white.opacity(0.4)).frame(width: 8, height: 8)
          Text(isMarketOpen ? "Market open" : "Market closed")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
          Text(clock, style: .time)
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.5))
        }
        Text(quotes.formatBase(summary.totalValue))
          .font(.system(size: compact ? 54 : 46, weight: .bold, design: .rounded).monospacedDigit())
          .lineLimit(1)
          .minimumScaleFactor(0.5)
          .contentTransition(.numericText())
        Label("\(changeText(summary.dayChange)) · \(isUp ? "+" : "")\(quotes.formatBase(summary.dayChangeAmount)) today",
              systemImage: isUp ? "arrow.up.right" : "arrow.down.right")
          .font(.title3.weight(.semibold).monospacedDigit())
          .foregroundStyle(isUp ? Brand.buy : Brand.sell)
        if let best = summary.positions.max(by: { $0.quote.change < $1.quote.change }) {
          Text("Best today: \(best.holding.symbol) \(changeText(best.quote.change))")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
        }
      }
      .frame(maxWidth: compact ? 360 : .infinity, alignment: .leading)
      InteractiveChart(values: history.values, dates: history.dates, lineColor: (history.values.last ?? 0) >= (history.values.first ?? 0) ? Brand.buy : Brand.sell,
                       gridColor: .white.opacity(0.08), owlSize: compact ? 44 : 40, selectedIndex: $selectedIndex)
        .frame(maxWidth: .infinity, maxHeight: compact ? .infinity : 180)
    }
    .padding(.horizontal, 32)
    .padding(.vertical, compact ? 20 : 8)
  }

  private func plansPanel(columns: Int) -> some View {
    let plans = plans
    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Closest to your zones")
          .font(.headline)
        Spacer()
        Text("\(plans.count) plans on watch")
          .font(.subheadline)
          .foregroundStyle(.white.opacity(0.55))
      }
      if plans.isEmpty {
        HStack(spacing: 14) {
          LivelyOwl().frame(width: 44, height: 50)
          Text("Set a buy zone on a stock and Dippy will track it here.")
            .foregroundStyle(.white.opacity(0.7))
        }
      } else {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: columns), spacing: 14) {
          ForEach(Array(plans.prefix(columns == 1 ? 4 : 6).enumerated()), id: \.element.alert.id) { index, plan in
            DeskPlanTile(alert: plan.alert, quote: plan.quote, isFocused: index == focus % max(plans.count, 1))
              .onTapGesture { withAnimation(.snappy) { focus = index } }
          }
        }
      }
      Spacer(minLength: 0)
      movers
    }
    .padding(.horizontal, 32)
    .padding(.vertical, 18)
  }

  /// Today's biggest moves among what you own, as a calm ticker along the bottom.
  private var movers: some View {
    let movers = summary.positions.map(\.quote).sorted { abs($0.change) > abs($1.change) }.prefix(5)
    return HStack(spacing: 10) {
      Text("Today")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.55))
      ForEach(Array(movers), id: \.symbol) { quote in
        HStack(spacing: 6) {
          Text(quote.symbol).font(.subheadline.weight(.bold))
          Text(changeText(quote.change))
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.white.opacity(0.07), in: .capsule)
      }
      Spacer(minLength: 0)
    }
    .lineLimit(1)
  }
}

/// One plan on the desk: the stock, where the price sits against the zone, and how far it has to go.
private struct DeskPlanTile: View {
  var alert: PriceAlert
  var quote: Quote
  var isFocused: Bool

  var body: some View {
    let status = TargetStatus(target: WatchedTarget(id: alert.id, symbol: alert.symbol, name: quote.name, rule: alert.rule), quote: quote)
    let color = alert.kind.side.brandColor
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        WidgetBadge(symbol: alert.symbol, size: 32)
        VStack(alignment: .leading, spacing: 1) {
          Text(alert.symbol).font(.headline)
          Text(compactSummary(status))
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        Spacer(minLength: 4)
        DistanceLabel(status: status)
      }
      ZoneRuler(status: status)
    }
    .padding(14)
    .background(.white.opacity(isFocused ? 0.14 : 0.07), in: .rect(cornerRadius: 18, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(isFocused ? color.opacity(0.6) : .clear, lineWidth: 1.5)
    }
    .accessibilityElement(children: .combine)
  }
}
