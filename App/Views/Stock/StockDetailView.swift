import SwiftData
import SwiftUI

struct StockDetailView: View {
  var symbol: String

  @Query private var matches: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss
  @State private var range: ChartRange = .month
  @State private var fiveYearQuote: Quote?
  @State private var selectedIndex: Int?
  @State private var editor: AlertEditorTarget?
  @State private var showsPositionEditor = false
  @State private var showsRemoveConfirmation = false
  @State private var showsPaywall = false

  init(symbol: String) {
    self.symbol = symbol
    _matches = Query(filter: #Predicate<Holding> { $0.symbol == symbol })
  }

  private var holding: Holding? { matches.first }
  private var quote: Quote? { quotes[symbol] }
  private func format(_ value: Double) -> String { quote?.formatted(value) ?? value.formatted(.number.precision(.fractionLength(2))) }

  private var series: (values: [Double], dates: [Date]) {
    if range == .fiveYears { return (fiveYearQuote?.closes ?? [], fiveYearQuote?.dates ?? []) }
    return quote?.recent(range.sessions ?? 22) ?? ([], [])
  }

  var body: some View {
    Group {
      if let holding {
        content(for: holding)
      } else {
        ContentUnavailableView("Not Watching \(symbol)", systemImage: "binoculars", description: Text("This stock was removed."))
      }
    }
    .background(Palette.canvas)
    .navigationTitle(symbol)
    .navigationBarTitleDisplayMode(.inline)
    .sheet(item: $editor) { target in
      if let holding {
        AlertEditorView(holding: holding, alert: target.alert, initialRule: target.rule)
      }
    }
    .sheet(isPresented: $showsPositionEditor) {
      if let holding { PositionEditorView(holding: holding) }
    }
    .sheet(isPresented: $showsPaywall) { PaywallView() }
    .task(id: range) {
      guard range == .fiveYears, fiveYearQuote == nil else { return }
      fiveYearQuote = try? await QuoteService().quote(for: symbol, fiveYears: true)
    }
    .task(id: quote?.price) {
      if let quote { await flock.load(symbol: symbol, currentPrice: quote.price) }
    }
  }

  private func content(for holding: Holding) -> some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        header(for: holding)
        planSection(for: holding)
        otherAlerts(for: holding)
        if let quote { keyStats(quote) }
        if holding.isOwned { positionSection(for: holding) }
        if let quote, !quote.dividends.isEmpty { dividendSection(quote, holding: holding) }
        FlockTeaser(symbol: symbol, quote: quote)
        DisclaimerFooter(lastUpdated: quote?.updatedAt)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity)
    }
    .refreshable { await quotes.refresh(symbols: [symbol]) }
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Menu("Options", systemImage: "ellipsis") {
          Button("New Alert", systemImage: "bell.badge") { addAlert(nil) }
          Button(holding.isOwned ? "Edit Position" : "Add Position", systemImage: "chart.pie") { showsPositionEditor = true }
          Button("Stop Watching", systemImage: "trash", role: .destructive) { showsRemoveConfirmation = true }
        }
      }
    }
    .confirmationDialog("Stop watching \(symbol)?", isPresented: $showsRemoveConfirmation, titleVisibility: .visible) {
      Button("Stop Watching", role: .destructive) { remove(holding) }
    } message: {
      Text("This removes the stock and all of its alerts.")
    }
  }

  // MARK: Header

  private func header(for holding: Holding) -> some View {
    let series = series
    let selection = selectedIndex.flatMap { series.values.indices.contains($0) ? $0 : nil }
    return VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(selection.flatMap { series.dates.indices.contains($0) ? series.dates[$0].formatted(date: .abbreviated, time: .omitted) : nil } ?? holding.name)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(selection == nil ? .white.opacity(0.65) : Brand.mint)
          .lineLimit(1)
        Text(selection.map { format(series.values[$0]) } ?? quote.map { format($0.price) } ?? "—")
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .monospacedDigit()
          .foregroundStyle(.white)
          .contentTransition(.numericText())
        if let quote {
          if let selection, series.values[selection] > 0 {
            ChangeBadge(change: quote.price / series.values[selection] - 1, caption: "since then", positiveColor: Brand.mint, negativeColor: Brand.loss)
          } else if range == .week || range == .month, let first = series.values.first, first > 0 {
            HStack(spacing: 12) {
              ChangeBadge(change: quote.change, caption: "today", positiveColor: Brand.mint, negativeColor: Brand.loss)
              ChangeBadge(change: quote.price / first - 1, caption: range.title, positiveColor: Brand.mint, negativeColor: Brand.loss)
            }
          } else if let first = series.values.first, first > 0 {
            ChangeBadge(change: quote.price / first - 1, caption: range.title, positiveColor: Brand.mint, negativeColor: Brand.loss)
          }
        }
      }

      if series.values.count > 1 {
        InteractiveChart(
          values: series.values,
          dates: series.dates,
          levels: holding.activeAlerts.filter { !$0.kind.isZone }.compactMap { alert in
            quote.flatMap { alert.rule.triggerLevel(for: $0) }.map { InteractiveChart.Level(price: $0, label: alert.kind.title) }
          },
          zones: holding.activeAlerts.filter(\.kind.isZone).map { alert in
            InteractiveChart.Zone(range: alert.targetPrice...max(alert.targetPrice, alert.upperPrice), side: alert.kind.side,
                                  label: alert.kind == .buyZone ? "Buy zone" : "Sell zone")
          },
          owlSize: 44,
          selectedIndex: $selectedIndex
        )
        .frame(height: 230)
      } else {
        ProgressView()
          .tint(.white)
          .frame(maxWidth: .infinity, minHeight: 230)
      }

      Picker("Range", selection: $range) {
        ForEach(ChartRange.allCases) { Text($0.title).tag($0) }
      }
      .pickerStyle(.segmented)
    }
    .padding(20)
    .background(Brand.nightGradient, in: .rect(cornerRadius: 32))
    .environment(\.colorScheme, .dark)
    .padding(.top, 8)
  }

  // MARK: Plan

  private func planSection(for holding: Holding) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your Plan", subtitle: "Where you'd buy more and take profit")
      VStack(alignment: .leading, spacing: 16) {
        if let quote {
          let report = flock.reports[symbol]
          ZoneTrack(
            price: quote.price,
            bands: [
              holding.buyZone.map { ZoneTrack.Band(range: $0.targetPrice...max($0.targetPrice, $0.upperPrice), side: .buy, isCrowd: false) },
              holding.sellZone.map { ZoneTrack.Band(range: $0.targetPrice...max($0.targetPrice, $0.upperPrice), side: .sell, isCrowd: false) },
              report?.buyZone.map { ZoneTrack.Band(range: $0, side: .buy, isCrowd: true) },
              report?.sellZone.map { ZoneTrack.Band(range: $0, side: .sell, isCrowd: true) },
            ].compactMap { $0 },
            low: quote.low52,
            high: quote.high52,
            format: format
          )
          ZoneLegend(showsCrowd: report?.buyZone != nil || report?.sellZone != nil)
        }
        HStack(spacing: 12) {
          ZoneButton(title: "Buy zone", alert: holding.buyZone, side: .buy, quote: quote) {
            if let alert = holding.buyZone { editor = AlertEditorTarget(alert: alert) } else { addAlert(AlertRule(kind: .buyZone)) }
          }
          ZoneButton(title: "Sell zone", alert: holding.sellZone, side: .sell, quote: quote) {
            if let alert = holding.sellZone { editor = AlertEditorTarget(alert: alert) } else { addAlert(AlertRule(kind: .sellZone)) }
          }
        }
      }
      .padding(18)
      .cardStyle()
    }
  }

  private func otherAlerts(for holding: Holding) -> some View {
    let alerts = (holding.alerts ?? [])
      .filter { !($0.isActive && ($0.id == holding.buyZone?.id || $0.id == holding.sellZone?.id)) }
      .sorted { ($0.isActive ? 0 : 1, $0.createdAt) < ($1.isActive ? 0 : 1, $1.createdAt) }
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Alerts") {
        Button("Add Alert", systemImage: "plus") { addAlert(nil) }
          .labelStyle(.iconOnly)
          .font(.title3.weight(.semibold))
      }
      if alerts.isEmpty {
        EmptyHint(systemImage: "bell.badge", text: "Add price levels or smart alerts like a dip from the 52-week high, a trailing stop, or a big daily move.")
      } else {
        ForEach(alerts) { alert in
          Button {
            editor = AlertEditorTarget(alert: alert)
          } label: {
            AlertCard(alert: alert, quote: quote)
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  // MARK: Stats

  private func keyStats(_ quote: Quote) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Key Numbers")
      LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
        StatTile(title: "52-week range", value: "\(format(quote.low52)) – \(format(quote.high52))", systemImage: "arrow.left.and.right", tint: Palette.green)
        StatTile(title: "From 52-week high", value: quote.drawdownFromHigh.formatted(.percent.precision(.fractionLength(1))), systemImage: "chart.line.downtrend.xyaxis", tint: Palette.amber)
        if let average = quote.movingAverage(days: 200) {
          StatTile(title: "vs 200-day average", value: (quote.price / average - 1).formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())), systemImage: "waveform.path.ecg", tint: quote.price >= average ? Palette.green : Palette.loss)
        }
        if let average = quote.movingAverage(days: 50) {
          StatTile(title: "vs 50-day average", value: (quote.price / average - 1).formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())), systemImage: "waveform.path", tint: quote.price >= average ? Palette.green : Palette.loss)
        }
      }
    }
  }

  private func positionSection(for holding: Holding) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your Position") {
        Button("Edit") { showsPositionEditor = true }
          .font(.subheadline.weight(.semibold))
      }
      VStack(spacing: 0) {
        DetailRow(title: "Shares", value: holding.shares.formatted())
        Divider().padding(.leading, 16)
        DetailRow(title: "Market value", value: quote.map { format(holding.value(at: $0.price)) } ?? "—")
        if holding.averageCost > 0 {
          Divider().padding(.leading, 16)
          DetailRow(title: "Average cost", value: format(holding.averageCost))
          if let quote, let gain = holding.gain(at: quote.price) {
            Divider().padding(.leading, 16)
            HStack {
              Text("Total return")
              Spacer()
              Text(format(holding.value(at: quote.price) - holding.costBasis))
                .monospacedDigit()
                .foregroundStyle(.secondary)
              ChangeBadge(change: gain)
            }
            .padding(16)
          }
        }
      }
      .cardStyle()
    }
  }

  private func dividendSection(_ quote: Quote, holding: Holding) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Dividends")
      VStack(spacing: 0) {
        DetailRow(title: "Last 12 months", value: format(quote.trailingAnnualDividend) + " / share")
        Divider().padding(.leading, 16)
        DetailRow(title: "Yield", value: quote.dividendYield.formatted(.percent.precision(.fractionLength(2))))
        if holding.isOwned {
          Divider().padding(.leading, 16)
          DetailRow(title: "Your yearly income", value: format(quote.trailingAnnualDividend * holding.shares))
        }
        if let next = quote.projectedDividends.first {
          Divider().padding(.leading, 16)
          DetailRow(title: "Next expected", value: "\(next.date.formatted(.dateTime.day().month(.abbreviated))) · \(format(next.amount))")
        }
      }
      .cardStyle()
    }
  }

  // MARK: Actions

  private func addAlert(_ rule: AlertRule?) {
    if AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro) {
      editor = AlertEditorTarget(alert: nil, rule: rule)
    } else {
      showsPaywall = true
    }
  }

  private func remove(_ holding: Holding) {
    let alerts = holding.alerts ?? []
    Task {
      for alert in alerts { await flock.withdraw(alert) }
    }
    modelContext.delete(holding)
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    dismiss()
  }
}

struct AlertEditorTarget: Identifiable {
  var alert: PriceAlert?
  var rule: AlertRule?
  var id: String { alert.map { "\($0.id)" } ?? "new-\(rule?.kind.rawValue ?? "")" }
}

struct DetailRow: View {
  var title: String
  var value: String

  var body: some View {
    HStack {
      Text(title)
      Spacer()
      Text(value)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.trailing)
    }
    .padding(16)
    .accessibilityElement(children: .combine)
  }
}

private struct ZoneButton: View {
  var title: String
  var alert: PriceAlert?
  var side: TradeSide
  var quote: Quote?
  var action: () -> Void

  private var tint: Color { side == .buy ? Palette.amber : Palette.green }

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Image(systemName: side == .buy ? "arrow.down.to.line.compact" : "arrow.up.to.line.compact")
          Text(title)
          Spacer()
          Image(systemName: alert == nil ? "plus" : "pencil")
            .font(.caption.bold())
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(tint)
        if let alert, let quote {
          Text("\(quote.formatted(alert.targetPrice))–\(quote.formatted(alert.upperPrice))")
            .font(.headline.monospacedDigit())
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          if let distance = alert.distance(for: quote) {
            Text(distance == 0 ? "Price is in the zone" : "\(distance.formatted(.percent.precision(.fractionLength(1)))) away")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } else {
          Text("Not set")
            .font(.headline)
            .foregroundStyle(.secondary)
          Text("Tap to plan")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(14)
      .background(tint.opacity(0.1), in: .rect(cornerRadius: 18))
    }
    .buttonStyle(.plain)
  }
}
