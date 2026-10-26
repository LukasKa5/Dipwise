import SwiftData
import SwiftUI

/// The community hub: what the Dipwise flock is buying, selling, and watching.
struct FlockView: View {
  private enum Board: String, CaseIterable, Identifiable {
    case radar = "Dip Radar"
    case trending = "Trending"
    case live = "Live"
    var id: Self { self }
  }

  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(FlockService.self) private var flock
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @State private var board: Board = .radar
  @State private var query = ""
  @State private var results: [SymbolMatch] = []
  @State private var showsPaywall = false
  @AppStorage(AlertSettings.sharePortfolioKey) private var sharesPortfolio = false
  @Environment(\.modelContext) private var modelContext

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          if !query.isEmpty {
            searchResults
          } else if !flock.isAvailable {
            ContentUnavailableView("The Flock Is Gathering", systemImage: "person.3", description: Text("Anonymous statistics from other Dipwise investors will appear here soon."))
          } else {
            hero
            if let sentiment = flock.sentiment {
              FlockSentimentCard(sentiment: sentiment, mine: flock.myCheckIn)
            }
            topInvestors
            owned
            buyingAndSelling
            if !sharesPortfolio {
              SharePortfolioCard {
                sharesPortfolio = true
                Task { await MarketMonitor.refresh(context: modelContext, quotes: quotes, flock: flock) }
              }
            }
            boards
            yourStocks
            if flock.overview.isSample {
              Label("Sample data shown until Flock sync is connected.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
      }
      .background(Palette.canvas)
      .navigationTitle("Flock")
      .toolbar {
        if flock.isAvailable {
          ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
              InvestorProfileView()
            } label: {
              Label("Your Profile", systemImage: "person.crop.circle")
            }
          }
        }
      }
      .searchable(text: $query, prompt: "Crowd report for any stock")
      .task(id: query) { await search() }
      .task { await flock.loadOverview() }
      .task { await flock.loadSentiment() }
      .refreshable { await flock.loadOverview() }
      .navigationDestination(for: String.self) { symbol in
        FlockDetailView(symbol: symbol)
      }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
    }
  }

  // MARK: Hero

  /// The flock at a glance on the app's navy: a row of anonymous owls, how many set alerts this week, the mood,
  /// and the stocks trading inside the crowd's buy zone right now.
  private var hero: some View {
    let overview = flock.overview
    let faces = Array(flock.leaders.prefix(6))
    let bullish = overview.mood.bullShare >= 0.5
    return VStack(alignment: .leading, spacing: 18) {
      HStack {
        Label("Everyone here is anonymous", systemImage: "lock.fill")
          .font(.caption.weight(.bold))
          .foregroundStyle(Brand.mint)
          .padding(.horizontal, 10)
          .padding(.vertical, 5)
          .background(Brand.mint.opacity(0.15), in: .capsule)
        Spacer()
        InfoButton(topic: .flock)
      }
      HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(overview.investors.formatted()) investors")
            .font(.system(.title, design: .rounded).bold())
            .lineLimit(1)
            .minimumScaleFactor(0.5)
          Text("set \(overview.alertsThisWeek.formatted()) alerts this week")
            .font(.headline)
            .foregroundStyle(Brand.mint)
        }
        Spacer(minLength: 0)
        LivelyOwl()
          .frame(width: 58, height: 67)
      }
      if !faces.isEmpty {
        HStack(spacing: -10) {
          ForEach(faces) { investor in
            InvestorAvatar(investor: investor, size: 38)
              .overlay { Circle().strokeBorder(Brand.nightMiddle, lineWidth: 2.5) }
          }
          Text("+\(max(0, overview.investors - faces.count).formatted())")
            .font(.caption.weight(.bold).monospacedDigit())
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(.white.opacity(0.14), in: .capsule)
            .padding(.leading, 18)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(overview.investors) anonymous investors")
      }
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Market mood")
            .font(.subheadline.weight(.semibold))
          Spacer()
          Text(bullish ? "Optimistic" : "Cautious")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(bullish ? Brand.buy : Brand.sell)
        }
        GeometryReader { geometry in
          HStack(spacing: 3) {
            Capsule().fill(Brand.buy).frame(width: max(6, (geometry.size.width - 3) * overview.mood.bullShare))
            Capsule().fill(Brand.sell)
          }
        }
        .frame(height: 10)
        Text("\(overview.mood.bullShare.formatted(.percent.precision(.fractionLength(0)))) expect stocks they vote on to rise over the next 30 days")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.65))
      }
      .accessibilityElement(children: .combine)
      if !flock.radar.isEmpty {
        VStack(alignment: .leading, spacing: 10) {
          Text("In the crowd's buy zone now")
            .font(.subheadline.weight(.semibold))
          HStack(spacing: 8) {
            ForEach(flock.radar.prefix(3)) { item in
              NavigationLink(value: item.symbol) {
                HStack(spacing: 6) {
                  TickerBadge(symbol: item.symbol, size: 24)
                  Text(item.symbol)
                    .font(.subheadline.weight(.bold))
                }
                .padding(.leading, 5)
                .padding(.trailing, 10)
                .padding(.vertical, 5)
                .background(Brand.buy.opacity(0.2), in: .capsule)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
    .padding(20)
    .foregroundStyle(.white)
    .background(
      LinearGradient(colors: [Brand.nightTop, Brand.nightMiddle], startPoint: .top, endPoint: .bottom),
      in: .rect(cornerRadius: 28, style: .continuous)
    )
    .environment(\.colorScheme, .dark)
    .padding(.top, 8)
  }

  // MARK: Investors and holdings

  @ViewBuilder
  private var topInvestors: some View {
    if !flock.leaders.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SectionHeader(title: "Top Investors", subtitle: "The flock's best 12 months, anonymous") {
          if !subscription.isPro { ProBadge() }
        }
        ScrollView(.horizontal) {
          HStack(spacing: 12) {
            ForEach(Array(flock.leaders.prefix(10).enumerated()), id: \.element.id) { index, investor in
              NavigationLink {
                InvestorView(id: investor.id)
              } label: {
                InvestorCard(investor: investor, rank: index + 1)
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
      }
    }
  }

  @ViewBuilder
  private var owned: some View {
    if !flock.ownership.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SectionHeader(title: "What the Flock Owns", subtitle: "Share of members holding each stock")
        VStack(spacing: 0) {
          ForEach(Array(flock.ownership.prefix(8).enumerated()), id: \.element.id) { index, stat in
            NavigationLink(value: stat.symbol) {
              OwnershipRow(rank: index + 1, stat: stat)
            }
            .buttonStyle(.plain)
            if index < min(flock.ownership.count, 8) - 1 {
              Divider().padding(.leading, 84)
            }
          }
        }
        .cardStyle()
      }
    }
  }

  @ViewBuilder
  private var buyingAndSelling: some View {
    if !flock.flows.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        SectionHeader(title: "Buying and Selling", subtitle: "What members added and trimmed this week") {
          if !subscription.isPro { ProBadge() }
        }
        VStack(spacing: 0) {
          ForEach(Array(flock.flows.prefix(6).enumerated()), id: \.element.id) { index, stat in
            NavigationLink(value: stat.symbol) {
              FlowRow(stat: stat)
            }
            .buttonStyle(.plain)
            .proLocked(!subscription.isPro && index >= 1, message: "See what the flock is buying and selling")
            if index < min(flock.flows.count, 6) - 1 {
              Divider().padding(.leading, 62)
            }
          }
        }
        .cardStyle()
      }
    }
  }

  // MARK: Boards

  private var boards: some View {
    VStack(alignment: .leading, spacing: 16) {
      Picker("Board", selection: $board.animation(.smooth)) {
        ForEach(Board.allCases) { Text($0.rawValue).tag($0) }
      }
      .pickerStyle(.segmented)

      switch board {
      case .radar: radar
      case .trending: trending
      case .live: live
      }
    }
  }

  @ViewBuilder
  private var radar: some View {
    HStack {
      Text("Stocks trading inside the range where most investors plan to buy.")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
      InfoButton(topic: .radar)
    }
    if flock.radar.isEmpty {
      EmptyHint(systemImage: "scope", text: flock.isLoadingOverview ? "Scanning the flock…" : "No popular stocks are in the crowd's buy zone right now.")
    } else {
      let freeCount = 2
      ForEach(Array(flock.radar.enumerated()), id: \.element.id) { index, item in
        NavigationLink(value: item.symbol) {
          RadarCard(item: item)
        }
        .buttonStyle(.plain)
        .proLocked(!subscription.isPro && index >= freeCount, message: "See every dip the crowd is buying")
      }
    }
  }

  private var trending: some View {
    VStack(spacing: 0) {
      ForEach(Array(flock.overview.trending.enumerated()), id: \.element.id) { index, item in
        NavigationLink(value: item.symbol) {
          TrendingRow(rank: index + 1, item: item)
        }
        .buttonStyle(.plain)
        if index < flock.overview.trending.count - 1 {
          Divider().padding(.leading, 56)
        }
      }
    }
    .cardStyle()
  }

  private var live: some View {
    let events = Array(flock.overview.feed.prefix(subscription.isPro ? 30 : 5))
    return VStack(alignment: .leading, spacing: 14) {
      ForEach(events) { event in
        NavigationLink(value: event.symbol) {
          FeedRow(event: event)
        }
        .buttonStyle(.plain)
      }
      if !subscription.isPro {
        Button {
          showsPaywall = true
        } label: {
          Label("See the full live feed with Pro", systemImage: "lock.fill")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
      }
    }
    .padding(18)
    .cardStyle()
  }

  // MARK: Your stocks

  @ViewBuilder
  private var yourStocks: some View {
    if !holdings.isEmpty {
      VStack(alignment: .leading, spacing: 14) {
        SectionHeader(title: "Your Stocks", subtitle: "Crowd conviction on what you follow")
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
          ForEach(holdings) { holding in
            NavigationLink(value: holding.symbol) {
              FlockSnapshotCard(symbol: holding.symbol, report: flock.reports[holding.symbol])
            }
            .buttonStyle(.plain)
            .task {
              if let quote = quotes[holding.symbol] { await flock.load(symbol: holding.symbol, currentPrice: quote.price) }
            }
          }
        }
      }
    }
  }

  private var searchResults: some View {
    VStack(spacing: 0) {
      ForEach(results) { match in
        NavigationLink(value: match.symbol) {
          HStack(spacing: 12) {
            TickerBadge(symbol: match.symbol, size: 38)
            VStack(alignment: .leading, spacing: 2) {
              Text(match.symbol).font(.headline)
              Text(match.name).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "chevron.forward")
              .font(.footnote.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
          .padding(14)
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
        Divider().padding(.leading, 64)
      }
    }
    .cardStyle()
    .padding(.top, 8)
  }

  private func search() async {
    let text = query.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else { results = []; return }
    try? await Task.sleep(for: .milliseconds(300))
    guard !Task.isCancelled else { return }
    results = (try? await QuoteService().search(text)) ?? []
  }
}

private struct TrendingRow: View {
  var rank: Int
  var item: TrendingSymbol

  var body: some View {
    HStack(spacing: 14) {
      Text("\(rank)")
        .font(.headline.monospacedDigit())
        .foregroundStyle(.secondary)
        .frame(width: 26)
      VStack(alignment: .leading, spacing: 6) {
        HStack(spacing: 6) {
          Text(item.symbol).font(.headline)
          if item.weekChange > 0.25 {
            Label("Surging", systemImage: "flame.fill")
              .font(.caption2.bold())
              .foregroundStyle(Palette.amber)
          }
          Spacer()
          Text("\(item.alertsThisWeek)")
            .font(.subheadline.weight(.semibold).monospacedDigit())
          Text(item.weekChange, format: .percent.precision(.fractionLength(0)).sign(strategy: .always()))
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(item.weekChange >= 0 ? Palette.green : Palette.loss)
        }
        HStack(spacing: 8) {
          BuySellBar(buyShare: item.buyShare)
          Text("\(item.buyShare, format: .percent.precision(.fractionLength(0))) buy")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Palette.buy)
            .frame(width: 64, alignment: .trailing)
        }
      }
      Image(systemName: "chevron.forward")
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .padding(16)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}

private struct FlockSnapshotCard: View {
  var symbol: String
  var report: FlockReport?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        TickerBadge(symbol: symbol, size: 34)
        Spacer()
        if let report {
          ConvictionGauge(score: report.conviction, diameter: 38)
        }
      }
      Text(symbol)
        .font(.headline)
      if let report, report.hasEnoughData {
        Text(report.convictionLabel)
          .font(.caption.weight(.semibold))
          .foregroundStyle(Palette.buy)
        BuySellBar(buyShare: report.buyShare)
        Text("\(report.watcherCount) investors")
          .font(.caption)
          .foregroundStyle(.secondary)
      } else {
        Text(report == nil ? "Loading…" : "Not enough data yet")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .cardStyle(cornerRadius: 20)
    .accessibilityElement(children: .combine)
  }
}
