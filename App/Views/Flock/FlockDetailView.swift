import SwiftData
import SwiftUI

/// The full crowd report for any stock, built only from anonymous alert data.
struct FlockDetailView: View {
  var symbol: String

  @Query private var matches: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(\.modelContext) private var modelContext
  @Environment(ProgressStore.self) private var progress
  @State private var quote: Quote?
  @State private var showsAddStock = false
  @State private var showsPaywall = false
  @State private var editor: AlertEditorTarget?

  init(symbol: String) {
    self.symbol = symbol
    _matches = Query(filter: #Predicate<Holding> { $0.symbol == symbol })
  }

  private var holding: Holding? { matches.first }
  private var report: FlockReport? { flock.reports[symbol] }
  private var isPro: Bool { subscription.isPro }
  /// Free members see the crowd zone in full for stocks they already follow.
  private var zoneUnlocked: Bool { isPro || holding != nil }
  private func format(_ value: Double) -> String { quote?.formatted(value) ?? value.formatted(.number.precision(.fractionLength(2))) }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        header
        if !flock.isAvailable {
          EmptyHint(systemImage: "person.3", text: "Crowd statistics are coming soon.")
        } else if let report {
          if report.hasEnoughData {
            conviction(report)
            VoteCard(symbol: symbol, votes: report.votes, userVote: flock.userVote(for: symbol)) { bullish in
              let isFirst = flock.userVote(for: symbol) == nil
              Task { await flock.vote(symbol: symbol, bullish: bullish) }
              if isFirst { progress.record(.vote) }
            }
            crowdZone(report)
            distribution(report)
            momentum(report)
            trackRecord(report)
            mix(report)
            feed(report)
            related(report)
            if !isPro { proFooter }
            if report.isSample {
              Label("Sample data shown until Flock sync is connected.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          } else {
            EmptyHint(systemImage: "person.3", text: "Not enough investors are watching \(symbol) yet. Your alerts help build the flock.")
          }
        } else {
          ProgressView().frame(maxWidth: .infinity, minHeight: 200)
        }
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity)
    }
    .background(Palette.canvas)
    .navigationTitle("Crowd Report")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showsAddStock) {
      NavigationStack {
        StockSetupView(match: SymbolMatch(symbol: symbol, name: quote?.name ?? symbol, exchange: "", type: "")) { _ in
          showsAddStock = false
        }
      }
    }
    .sheet(isPresented: $showsPaywall) { PaywallView() }
    .sheet(item: $editor) { target in
      if let holding { AlertEditorView(holding: holding, alert: nil, initialRule: target.rule) }
    }
    .task {
      quote = quotes[symbol]
      if quote == nil, let fresh = try? await QuoteService().quote(for: symbol) {
        quote = fresh
      }
      if let quote { await flock.load(symbol: symbol, currentPrice: quote.price) }
    }
  }

  // MARK: Header

  private var header: some View {
    HStack(spacing: 14) {
      TickerBadge(symbol: symbol, size: 50)
      VStack(alignment: .leading, spacing: 2) {
        Text(quote?.name ?? symbol)
          .font(.headline)
          .lineLimit(1)
        if let quote {
          HStack(spacing: 8) {
            Text(quote.formatted(quote.price)).monospacedDigit()
            ChangeBadge(change: quote.change)
          }
          .font(.subheadline)
        }
      }
      Spacer()
      if holding == nil {
        Button("Watch", systemImage: "binoculars.fill") { showsAddStock = true }
          .buttonStyle(.borderedProminent)
          .controlSize(.small)
      }
    }
    .padding(.top, 8)
  }

  // MARK: Sections

  private func conviction(_ report: FlockReport) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Crowd conviction")
          .font(.headline)
        Spacer()
        Label("From real alerts", systemImage: "person.3.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      HStack(spacing: 18) {
        ConvictionGauge(score: report.conviction)
        VStack(alignment: .leading, spacing: 6) {
          Text(report.convictionLabel)
            .font(.title3.bold())
            .foregroundStyle(report.conviction >= 55 ? Palette.buy : (report.conviction < 45 ? Palette.sell : .primary))
          Text(report.convictionBlurb)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      HStack(spacing: 12) {
        MiniStat(title: "Investors", value: report.watcherCount.formatted())
        MiniStat(title: "Buy-side", value: report.buyShare.formatted(.percent.precision(.fractionLength(0))))
        MiniStat(title: "Near price", value: "\(report.nearPriceCount)")
      }
    }
    .padding(18)
    .cardStyle()
  }

  private func crowdZone(_ report: FlockReport) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Crowd zones")
          .font(.headline)
        Spacer()
        Label("Anonymous", systemImage: "eye.slash.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      VStack(alignment: .leading, spacing: 14) {
        Text(report.buyShare >= 0.5 ? "The crowd is hunting a dip" : "The crowd is taking profit")
          .font(.subheadline.weight(.semibold))
        ZoneTrack(
          price: report.currentPrice,
          bands: [
            report.buyZone.map { ZoneTrack.Band(range: $0, side: .buy, isCrowd: true) },
            report.sellZone.map { ZoneTrack.Band(range: $0, side: .sell, isCrowd: true) },
            holding?.buyZone.map { ZoneTrack.Band(range: $0.targetPrice...max($0.targetPrice, $0.upperPrice), side: .buy, isCrowd: false) },
            holding?.sellZone.map { ZoneTrack.Band(range: $0.targetPrice...max($0.targetPrice, $0.upperPrice), side: .sell, isCrowd: false) },
          ].compactMap { $0 },
          low: nil,
          high: nil,
          format: format
        )
        ZoneLegend()
        VStack(spacing: 8) {
          if let zone = report.buyZone {
            zoneRow(title: "Buy zone", zone: zone, count: report.buyLevels.count, color: Palette.buy)
          }
          if let zone = report.sellZone {
            zoneRow(title: "Sell zone", zone: zone, count: report.sellLevels.count, color: Palette.sell)
          }
        }
        if let zone = report.buyZone {
          Button {
            copyZone(zone, kind: .buyZone)
          } label: {
            Label("Use the crowd's buy zone", systemImage: "square.on.square")
              .font(.subheadline.weight(.semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
          }
          .buttonStyle(.bordered)
          .tint(Palette.buy)
        }
      }
      .proLocked(!zoneUnlocked, message: "Watch \(symbol) to unlock its crowd zones for free, or go Pro for every stock")
    }
    .padding(18)
    .cardStyle()
  }

  private func zoneRow(title: String, zone: ClosedRange<Double>, count: Int, color: Color) -> some View {
    HStack {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(title).font(.subheadline.weight(.semibold))
      Spacer()
      Text("\(format(zone.lowerBound))–\(format(zone.upperBound))")
        .font(.subheadline.monospacedDigit())
      Text("· \(count)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .accessibilityElement(children: .combine)
  }

  private func distribution(_ report: FlockReport) -> some View {
    ReportSection(title: "Where alerts cluster", systemImage: "chart.bar.fill", isLocked: !isPro, message: "See exactly where investors set their alerts") {
      VStack(alignment: .leading, spacing: 12) {
        FlockHistogram(report: report, userLevels: holding?.activeAlerts.compactMap(\.rule.referencePrice) ?? [])
          .frame(height: 190)
        if let crowded = report.crowdedLevel {
          Label("Most crowded level: \(format(crowded))", systemImage: "scope")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Palette.amber)
        }
        ForEach(holding?.activeAlerts ?? []) { alert in
          if let level = alert.rule.referencePrice, let patience = report.patience(of: level, side: alert.kind.side) {
            Label("Your \(alert.kind.title.lowercased()) is more patient than \(patience.formatted(.percent.precision(.fractionLength(0)))) of investors", systemImage: "person.fill")
              .font(.footnote)
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func momentum(_ report: FlockReport) -> some View {
    ReportSection(title: "Momentum", systemImage: "flame.fill", isLocked: !isPro, message: "Track how fast interest is growing") {
      VStack(alignment: .leading, spacing: 14) {
        HStack(spacing: 12) {
          MiniStat(title: "This week", value: "\(report.alertsThisWeek)")
          MiniStat(title: "vs last week", value: report.weekChange.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())),
                   color: report.weekChange >= 0 ? Palette.green : Palette.loss)
          MiniStat(title: "Fired 24h", value: "\(report.triggeredLast24h)")
        }
        ActivityBars(counts: report.weeklyActivity)
          .frame(height: 60)
        Text("New alerts per week, last 8 weeks")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder
  private func trackRecord(_ report: FlockReport) -> some View {
    if let record = report.trackRecord {
      ReportSection(title: "Did buying the dip work?", systemImage: "checkmark.seal.fill", isLocked: !isPro, message: "See how the crowd's buy alerts have performed") {
        VStack(alignment: .leading, spacing: 12) {
          HStack(spacing: 12) {
            MiniStat(title: "Avg. since fired", value: record.averageReturn.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())),
                     color: record.averageReturn >= 0 ? Palette.green : Palette.loss)
            MiniStat(title: "In profit", value: record.winRate.formatted(.percent.precision(.fractionLength(0))))
            MiniStat(title: "Alerts fired", value: "\(record.count)")
          }
          Text("Based on buy alerts that fired in the last 6 months, compared with today's price. Past results don't predict the future.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func mix(_ report: FlockReport) -> some View {
    let maxCount = report.mix.map(\.count).max() ?? 1
    return ReportSection(title: "Alert mix", systemImage: "sparkles", isLocked: !isPro, message: "See which alerts investors rely on") {
      VStack(spacing: 10) {
        ForEach(report.mix, id: \.kind) { item in
          HStack(spacing: 10) {
            Image(systemName: item.kind.systemImage)
              .foregroundStyle(item.kind.side.color)
              .frame(width: 20)
            Text(item.kind.title)
              .font(.subheadline)
              .frame(width: 120, alignment: .leading)
            GeometryReader { geometry in
              Capsule()
                .fill((item.kind.side.color).opacity(0.6))
                .frame(width: max(4, geometry.size.width * Double(item.count) / Double(maxCount)), height: 8)
                .frame(maxHeight: .infinity)
            }
            .frame(height: 16)
            Text("\(item.count)")
              .font(.caption.monospacedDigit())
              .foregroundStyle(.secondary)
              .frame(width: 34, alignment: .trailing)
          }
          .accessibilityElement(children: .combine)
        }
      }
    }
  }

  private func feed(_ report: FlockReport) -> some View {
    let events = Array(report.feed.prefix(isPro ? 12 : 3))
    return VStack(alignment: .leading, spacing: 14) {
      Label("Live activity", systemImage: "waveform.path.ecg")
        .font(.headline)
      ForEach(events) { event in
        FeedRow(event: event, showsSymbol: false)
      }
      if !isPro && report.feed.count > events.count {
        Button("See all activity with Pro", systemImage: "lock.fill") { showsPaywall = true }
          .font(.subheadline.weight(.semibold))
      }
    }
    .padding(18)
    .cardStyle()
  }

  @ViewBuilder
  private func related(_ report: FlockReport) -> some View {
    if !report.related.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        Label("Investors watching \(symbol) also watch", systemImage: "person.2.wave.2.fill")
          .font(.headline)
        ScrollView(.horizontal) {
          HStack(spacing: 8) {
            ForEach(report.related) { item in
              NavigationLink {
                FlockDetailView(symbol: item.symbol)
              } label: {
                HStack(spacing: 6) {
                  TickerBadge(symbol: item.symbol, size: 24)
                  Text(item.symbol).font(.subheadline.weight(.bold))
                  Text(item.overlap, format: .percent.precision(.fractionLength(0)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.quaternary.opacity(0.6), in: .capsule)
              }
              .buttonStyle(.plain)
            }
          }
        }
        .scrollIndicators(.hidden)
      }
      .padding(18)
      .cardStyle()
    }
  }

  private var proFooter: some View {
    Button {
      showsPaywall = true
    } label: {
      HStack(spacing: 14) {
        LivelyOwl(hopsOnTap: false).frame(width: 40, height: 46)
        VStack(alignment: .leading, spacing: 2) {
          Text("Unlock the full crowd report")
            .font(.headline)
          Text("Every stock, every chart, the live feed, and track records.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.forward")
          .foregroundStyle(.tertiary)
      }
      .padding(18)
      .cardStyle()
    }
    .buttonStyle(.plain)
  }

  // MARK: Actions

  private func copyZone(_ zone: ClosedRange<Double>, kind: AlertKind) {
    guard holding != nil else {
      showsAddStock = true
      return
    }
    guard AlertLimits.canAddAlert(in: modelContext, isPro: isPro) else {
      showsPaywall = true
      return
    }
    editor = AlertEditorTarget(alert: nil, rule: AlertRule(kind: kind, lower: zone.lowerBound, upper: zone.upperBound))
  }
}

private struct ReportSection<Content: View>: View {
  var title: String
  var systemImage: String
  var isLocked: Bool
  var message: String
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Label(title, systemImage: systemImage)
          .font(.headline)
        Spacer()
        if isLocked { ProBadge() }
      }
      content
        .proLocked(isLocked, message: message)
    }
    .padding(18)
    .cardStyle()
  }
}

struct MiniStat: View {
  var title: String
  var value: String
  var color: Color = .primary

  var body: some View {
    VStack(spacing: 4) {
      Text(value)
        .font(.headline.monospacedDigit())
        .foregroundStyle(color)
        .lineLimit(1)
        .minimumScaleFactor(0.7)
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 10)
    .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 14))
    .accessibilityElement(children: .combine)
  }
}
