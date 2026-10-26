#if DEBUG
import SwiftData
import SwiftUI
import WidgetKit

/// Development only: an iPhone Home Screen with Dipwise's widgets on the Dipwise wallpaper, filled from the demo
/// portfolio, for the App Store's widgets screenshot. Launch with `-demoPortfolio -marketingScene home-widgets`.
struct MarketingHomeScreen: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(\.modelContext) private var modelContext
  @State private var isReady = false

  private static let small = CGSize(width: 170, height: 170)
  private static let medium = CGSize(width: 364, height: 170)

  var body: some View {
    ZStack(alignment: .top) {
      DipwiseWallpaper()
      if isReady {
        let targets = TargetSnapshotStore.loadTargets()
        let statuses = TargetStatus.sorted(targets: targets, quotes: quotes.quotes)
        let flock = FlockWidgetEntry(date: .now, snapshot: flockSnapshot)
        VStack(spacing: 0) {
          tile("Dipwise", size: Self.medium) {
            PortfolioWidgetView(entry: PortfolioProvider.entry(quotes: quotes.quotes), previewFamily: .systemMedium)
          }
          Spacer(minLength: 10)
          HStack(spacing: 24) {
            tile("Dipwise", size: Self.small) {
              PlansWidgetView(entry: PlansEntry(date: .now, statuses: statuses), previewFamily: .systemSmall)
            }
            tile("Dipwise", size: Self.small) {
              FlockZonesWidgetView(entry: flock, previewFamily: .systemSmall)
            }
          }
          Spacer(minLength: 10)
          tile("Dipwise", size: Self.medium) {
            FlockMoodWidgetView(entry: flock, previewFamily: .systemMedium)
          }
          Spacer(minLength: 10)
          HStack(spacing: 24) {
            tile("Dipwise", size: Self.small) {
              MarketWidgetView(entry: MarketEntry(date: marketMoment, market: quotes[Benchmark.symbol] ?? MarketProvider.sampleMarket, plans: targets.count),
                               previewFamily: .systemSmall, previewIsOpen: true)
            }
            tile("Dipwise", size: Self.small) {
              StockPlanWidgetView(entry: StockPlanEntry(date: .now, symbol: "NVDA", quote: quotes["NVDA"], targets: targets.filter { $0.symbol == "NVDA" }),
                                  previewFamily: .systemSmall)
            }
          }
          Spacer(minLength: 10)
          searchPill
        }
        .padding(.top, 72)
        .padding(.bottom, 34)
        .frame(maxHeight: .infinity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .ignoresSafeArea()
    .environment(\.colorScheme, .dark)
    .task {
      SnapshotPublisher.publish(context: modelContext)
      await quotes.refresh(symbols: holdings.map(\.symbol) + [Benchmark.symbol])
      isReady = true
    }
  }

  /// 9:41 on the screenshot day, with the market open.
  private var marketMoment: Date {
    let day = QuoteService.marketingDate ?? .now
    return Calendar.current.date(bySettingHour: 9, minute: 41, second: 0, of: day) ?? day
  }

  /// The flock's picks around the demo portfolio's own prices, so every screenshot tells the same day.
  private var flockSnapshot: FlockSnapshot {
    func pick(_ symbol: String, name: String, low: Double, high: Double, conviction: Int, watchers: Int) -> FlockSnapshot.Pick? {
      guard let quote = quotes[symbol] else { return nil }
      return FlockSnapshot.Pick(symbol: symbol, name: name, price: quote.price, currency: quote.currency,
                                zoneLower: quote.price * low, zoneUpper: quote.price * high, conviction: conviction, watchers: watchers)
    }
    return FlockSnapshot(
      picks: [
        pick("AMZN", name: "Amazon", low: 0.95, high: 1.01, conviction: 84, watchers: 412),
        pick("NVDA", name: "NVIDIA", low: 0.9, high: 0.97, conviction: 79, watchers: 386),
        pick("AAPL", name: "Apple", low: 0.88, high: 0.95, conviction: 71, watchers: 351),
      ].compactMap { $0 },
      trending: [
        FlockSnapshot.Trend(symbol: "NVDA", alertsThisWeek: 142, buyShare: 0.74),
        FlockSnapshot.Trend(symbol: "AMZN", alertsThisWeek: 118, buyShare: 0.69),
        FlockSnapshot.Trend(symbol: "TSLA", alertsThisWeek: 96, buyShare: 0.41),
      ],
      bullShare: 0.64,
      investors: 2_480,
      alertsThisWeek: 1_312,
      updatedAt: .now
    )
  }

  /// A widget at its real Home Screen size, with the app's name under it like iOS shows.
  private func tile(_ name: String, size: CGSize, @ViewBuilder content: () -> some View) -> some View {
    VStack(spacing: 5) {
      content()
        .environment(\.colorScheme, .dark)
        .padding(16)
        .frame(width: size.width, height: size.height)
        .background(Brand.nightMiddle, in: .rect(cornerRadius: 24, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 14, y: 6)
      Text(name)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
    }
  }

  private var searchPill: some View {
    Label("Search", systemImage: "magnifyingglass")
      .font(.system(size: 15, weight: .semibold))
      .foregroundStyle(.white)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(.white.opacity(0.22), in: .capsule)
  }
}
#endif
