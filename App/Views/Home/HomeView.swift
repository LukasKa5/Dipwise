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
  @State private var showsPortfolio = false
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
            WelcomeCard { showsAddStock = true }
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
            stocks
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
        ToolbarItem(placement: .topBarTrailing) {
          Button("Add Stock", systemImage: "plus") { showsAddStock = true }
        }
      }
      .sheet(isPresented: $showsProgress) { ProgressHubView() }
      .fullScreenCover(isPresented: $router.showsBrief) { DailyBriefView() }
      .navigationDestination(for: String.self) { symbol in
        StockDetailView(symbol: symbol)
      }
      .navigationDestination(isPresented: $showsPortfolio) {
        PortfolioView()
      }
      .sheet(isPresented: $showsAddStock) {
        AddStockView { symbol in
          router.homePath = [symbol]
        }
      }
      .task { await flock.loadOverview() }
      .task(id: period) {
        if period.isIntraday { await quotes.loadIntraday(symbols: holdings.map(\.symbol)) }
      }
    }
  }

  private static var today: String { Date.now.formatted(.iso8601.year().month().day()) }

  // MARK: Sections

  private var hero: some View {
    let summary = summary
    if summary.hasPositions {
      let history = summary.history(period: period)
      let format: (Double) -> String = { quotes.formatBase($0) }
      return HeroCard(
        title: DayPeriod(date: .now).greeting,
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
        openDetails: { showsPortfolio = true },
        mood: OwlMood.current(dayChange: summary.dayChange)
      )
    }
    let focus = summary.nearestAlerts.first?.holding ?? holdings.first
    let quote = focus.flatMap { quotes[$0.symbol] }
    let recent: (values: [Double], dates: [Date])? = period.isIntraday
      ? focus.flatMap { quotes.intraday[$0.symbol] }.map { ($0.values, $0.dates) }
      : quote.map { period.slice(values: $0.closes, dates: $0.dates) }
    return HeroCard(
      title: "\(DayPeriod(date: .now).greeting) · Watching \(focus?.symbol ?? "")",
      value: quote.map { $0.formatted($0.price) } ?? "—",
      change: quote?.change,
      changeCaption: "today",
      values: recent?.values ?? [],
      dates: recent?.dates ?? [],
      stats: [
        HeroStat(value: "\(summary.activeAlerts.count)", label: "Alerts", systemImage: "scope", tint: Palette.buy),
        HeroStat(value: "\(summary.closeAlertCount())", label: "Close", systemImage: "bell.badge.fill", tint: Palette.amber),
        HeroStat(value: "\(holdings.count)", label: "Watching", systemImage: "binoculars.fill", tint: .primary),
      ],
      format: { quote?.formatted($0) ?? $0.formatted() },
      period: $period,
      earliest: quote?.dates.first ?? .now.addingTimeInterval(-365 * 86_400),
      openDetails: nil,
      mood: OwlMood.current(dayChange: quote?.change)
    )
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
        EmptyHint(systemImage: "scope", text: "Open a stock and set a buy zone or sell zone. Dipwise will watch it for you.")
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
    }
    .padding(28)
    .frame(maxWidth: .infinity)
    .cardStyle(cornerRadius: 28)
  }
}

struct EmptyHint: View {
  var systemImage: String
  var text: String

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

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      if let lastUpdated {
        Text("Prices updated \(lastUpdated, format: .relative(presentation: .named))")
      }
      Text("Market data may be delayed. Dipwise is not a broker and doesn't give investment advice.")
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
