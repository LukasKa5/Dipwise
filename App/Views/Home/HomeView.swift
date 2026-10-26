import SwiftData
import SwiftUI

struct HomeView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(Router.self) private var router
  @Environment(\.modelContext) private var modelContext
  @Environment(ProgressStore.self) private var progress
  @State private var showsProgress = false
  @AppStorage(AlertSettings.showsBriefKey) private var showsBrief = true
  @AppStorage(AlertSettings.briefHiddenDayKey) private var briefHiddenDay = ""
  @State private var showsAddStock = false
  @State private var showsAddPosition = false
  @State private var showsImport = false
  @State private var showsDesk = false
  /// Desk Mode is made for iPhone Duo standing like a tent on a desk, so it's offered only there.
  @State private var isFoldable = HomeView.forcesFoldable
  @State private var period: ChartPeriod = .preset(.month)

  private var summary: PortfolioSummary {
    PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase, intraday: quotes.intraday)
  }

  var body: some View {
    @Bindable var router = router
    NavigationStack(path: $router.homePath) {
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          if holdings.isEmpty {
            WelcomeCard { showsAddStock = true } importPortfolio: { showsImport = true }
          } else {
            if showsBrief && !progress.isBriefDoneToday && briefHiddenDay != Self.today {
              BriefBanner(streak: progress.streak) {
                router.showsBrief = true
              } dismissForToday: {
                withAnimation(.smooth) { briefHiddenDay = Self.today }
              } turnOff: {
                withAnimation(.smooth) { showsBrief = false }
                Task { await NotificationManager.scheduleBriefReminders(streak: 0, skipToday: true) }
              }
              .transition(.move(edge: .top).combined(with: .opacity))
            }
            hero
            nearTargets
            dipRadar
            flockPulse
          }
          DisclaimerFooter(lastUpdated: quotes.lastUpdated)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
      }
      .background(Palette.canvas)
      .navigationTitle("Dipwise")
      .refreshable { await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock) }
      .toolbar {
        if showsBrief {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              showsProgress = true
            } label: {
              StreakChip(streak: progress.streak, isDoneToday: progress.isBriefDoneToday)
            }
          }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
          if isFoldable {
            Button("Desk Mode", systemImage: "chart.xyaxis.line") { showsDesk = true }
          }
          Button("Add Stock", systemImage: "plus") { showsAddStock = true }
        }
      }
      .sheet(isPresented: $showsProgress) { ProgressHubView() }
      .fullScreenCover(isPresented: $showsDesk) { DeskModeView() }
      .onFoldableChange { isFoldable = $0 || HomeView.forcesFoldable }
      .fullScreenCover(isPresented: $router.showsBrief) { DailyBriefView() }
      .navigationDestination(for: String.self) { symbol in
        StockDetailView(symbol: symbol)
      }
      .navigationDestination(isPresented: $router.showsPortfolio) {
        PortfolioView()
      }
      .navigationDestination(isPresented: $router.showsProfile) {
        InvestorProfileView()
      }
      .sheet(isPresented: $showsAddStock) {
        AddStockView { symbol in
          router.homePath = [symbol]
        }
      }
      .sheet(isPresented: $showsImport) { ImportPortfolioView() }
      .sheet(isPresented: $showsAddPosition) {
        AddPositionSheet { showsAddStock = true }
      }
      .task { await flock.loadOverview() }
      .task(id: period) {
        if period.isIntraday { await quotes.loadIntraday(symbols: holdings.map(\.symbol)) }
      }
    }
  }

  private var greeting: String {
    DayPeriod(date: .now).greeting
  }

  private static var today: String { Date.now.formatted(.iso8601.year().month().day()) }

  // MARK: Sections

  @ViewBuilder
  private var hero: some View {
    let summary = summary
    if summary.hasPositions {
      let history = summary.history(period: period)
      let format: (Double) -> String = { quotes.formatBase($0) }
      HeroCard(
        title: greeting,
        value: format(summary.totalValue),
        change: summary.dayChange,
        changeCaption: "today",
        values: history.values,
        dates: history.dates,
        stats: [
          HeroStat(value: (summary.dayChangeAmount >= 0 ? "+" : "") + format(summary.dayChangeAmount), label: "Today", systemImage: "sun.max.fill", tint: summary.dayChangeAmount >= 0 ? Palette.gain : Palette.loss),
          HeroStat(value: summary.totalReturn.map { $0.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())) } ?? "—", label: "Total return", systemImage: "chart.line.uptrend.xyaxis", tint: Palette.gain),
          HeroStat(value: format(summary.annualDividendIncome), label: "Dividends / yr", systemImage: "leaf.fill", tint: Palette.amber),
        ],
        format: format,
        period: $period,
        earliest: summary.earliestDate,
        openDetails: { router.showsPortfolio = true },
        mood: OwlMood.current(dayChange: summary.dayChange, isAwake: OwlWake.shared.isAwake),
        status: status(for: summary)
      )
    } else {
      FirstPositionCard(
        greeting: greeting,
        stats: [
          HeroStat(value: "\(holdings.count)", label: "Watching", systemImage: "binoculars.fill", tint: .white),
          HeroStat(value: "\(summary.activeAlerts.count)", label: "Alerts", systemImage: "bell.fill", tint: Palette.buy),
          HeroStat(value: "\(summary.closeAlertCount())", label: "Close", systemImage: "scope", tint: Palette.amber),
        ]
      ) {
        showsAddPosition = true
      } importPortfolio: {
        showsImport = true
      }
    }
  }

  /// What Dippy says under the chart: the market's moment and the user's closest plan or biggest mover.
  private func status(for summary: PortfolioSummary) -> DippyStatus {
    let leader = summary.positions.max { abs($0.quote.change) < abs($1.quote.change) }
      .map { DippyStatus.Mover(symbol: $0.holding.symbol, change: $0.quote.change) }
    let closest = summary.nearestAlerts.first.flatMap { alert in
      quotes[alert.symbol].flatMap { quote in
        alert.distance(for: quote).map { DippyStatus.Plan(symbol: alert.symbol, distance: $0, isSell: alert.kind.side == .sell) }
      }
    }
    return DippyStatus.make(dayChange: summary.dayChange, leader: leader, closest: closest, isAwake: OwlWake.shared.isAwake)
  }

  @ViewBuilder
  private var nearTargets: some View {
    let alerts = Array(summary.nearestAlerts.prefix(4))
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your Plans", subtitle: alerts.isEmpty ? nil : "Closest to triggering first") {
        NavigationLink {
          AlertInsightsView()
        } label: {
          Label("Insights", systemImage: "chart.bar.xaxis")
            .font(.subheadline.weight(.semibold))
        }
      }
      if alerts.isEmpty {
        EmptyHint(systemImage: "scope", text: "Open a stock and add alerts. Dippy will watch them for you.")
      } else {
        ForEach(alerts) { alert in
          NavigationLink(value: alert.symbol) {
            AlertCard(alert: alert, quote: quotes[alert.symbol])
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  @ViewBuilder
  private var dipRadar: some View {
    if !flock.radar.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Dip Radar", subtitle: "In the crowd's buy zone right now") {
          Button("More") { router.selectedTab = .flock }
            .font(.subheadline.weight(.semibold))
        }
        ScrollView(.horizontal) {
          HStack(spacing: 12) {
            ForEach(flock.radar.prefix(6)) { item in
              NavigationLink {
                FlockDetailView(symbol: item.symbol)
              } label: {
                RadarCard(item: item)
                  .frame(width: 220)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
      }
    }
  }

  private var stocks: some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your Stocks")
      VStack(spacing: 0) {
        ForEach(holdings) { holding in
          NavigationLink(value: holding.symbol) {
            HoldingRow(holding: holding, quote: quotes[holding.symbol])
          }
          .buttonStyle(.plain)
          if holding.id != holdings.last?.id {
            Divider().padding(.leading, 72)
          }
        }
      }
      .cardStyle()
    }
  }

  @ViewBuilder
  private var flockPulse: some View {
    if !flock.overview.trending.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Flock Pulse", subtitle: "Most new alerts this week") {
          Button("Explore") { router.selectedTab = .flock }
            .font(.subheadline.weight(.semibold))
        }
        ScrollView(.horizontal) {
          HStack(spacing: 12) {
            ForEach(flock.overview.trending.prefix(8)) { item in
              TrendingChip(item: item)
            }
          }
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
      }
    }
  }
}

// MARK: - Supporting views

private struct WelcomeCard: View {
  var addStock: () -> Void
  var importPortfolio: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      LivelyOwl()
        .frame(height: 120)
      VStack(spacing: 8) {
        Text("Your owl is ready to watch")
          .font(.title2.bold())
        Text("Add the stocks you own or want to buy, set buy and sell zones, and Dipwise will tell you when it's time.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      Button(action: addStock) {
        Label("Add Your First Stock", systemImage: "plus")
          .font(.headline)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 6)
      }
      .buttonStyle(.borderedProminent)
      Button("Import from Broker or CSV", systemImage: "tray.and.arrow.down", action: importPortfolio)
        .font(.subheadline.weight(.semibold))
    }
    .padding(28)
    .frame(maxWidth: .infinity)
    .cardStyle(cornerRadius: 28)
  }
}

struct EmptyHint: View {
  var systemImage: String
  var text: LocalizedStringKey

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.subheadline)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(18)
      .cardStyle()
  }
}

struct HoldingRow: View {
  var holding: Holding
  var quote: Quote?

  var body: some View {
    HStack(spacing: 14) {
      TickerBadge(symbol: holding.symbol, size: 42)
      VStack(alignment: .leading, spacing: 2) {
        Text(holding.symbol)
          .font(.headline)
        Text(holding.isOwned ? "\(holding.shares.formatted()) shares" : "Watching")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
      if let quote {
        VStack(alignment: .trailing, spacing: 2) {
          Text(holding.isOwned ? quote.formatted(holding.value(at: quote.price)) : quote.formatted(quote.price))
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .font(.headline)
            .monospacedDigit()
          ChangeBadge(change: quote.change)
            .font(.caption)
        }
      } else {
        ProgressView()
      }
      Image(systemName: "chevron.forward")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

struct TrendingChip: View {
  var item: TrendingSymbol

  var body: some View {
    NavigationLink {
      FlockDetailView(symbol: item.symbol)
    } label: {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text(item.symbol)
            .font(.headline)
          Spacer()
          if item.weekChange > 0.25 {
            Image(systemName: "flame.fill")
              .foregroundStyle(Palette.amber)
              .accessibilityLabel("Surging")
          }
        }
        Text("\(item.alertsThisWeek) alerts this week")
          .font(.caption)
          .foregroundStyle(.secondary)
        BuySellBar(buyShare: item.buyShare)
      }
      .frame(width: 130, alignment: .leading)
      .padding(14)
      .cardStyle(cornerRadius: 20)
    }
    .buttonStyle(.plain)
  }
}

struct DisclaimerFooter: View {
  var lastUpdated: Date?
  @Environment(SubscriptionManager.self) private var subscription
  @State private var showsPaywall = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let lastUpdated {
        Text("Prices updated \(lastUpdated, format: .relative(presentation: .named))")
      }
      if !MarketData.offersRealTime {
        Label("Prices are 15 minutes delayed.", systemImage: "clock")
          .font(.caption.weight(.semibold))
      } else if !subscription.isPro {
        Button {
          showsPaywall = true
        } label: {
          Label("Prices are 15 minutes delayed. Real-time with Pro.", systemImage: "clock.badge.exclamationmark")
            .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .sheet(isPresented: $showsPaywall) { PaywallView() }
      }
      Text("Market data may be delayed. Dipwise is not a broker and doesn't give investment advice.")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

extension HomeView {
  /// Development only: `-foldable` shows Desk Mode on any iPhone, for testing without iPhone Duo.
  static var forcesFoldable: Bool {
    #if DEBUG
    ProcessInfo.processInfo.arguments.contains("-foldable")
    #else
    false
    #endif
  }
}
