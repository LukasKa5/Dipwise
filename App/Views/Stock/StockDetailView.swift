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
  @State private var period: ChartPeriod = .preset(.month)
  @State private var fiveYearQuote: Quote?
  @State private var selectedIndex: Int?
  @State private var editor: AlertEditorTarget?
  @State private var showsPositionEditor = false
  @State private var showsRemoveConfirmation = false
  @State private var showsPaywall = false
  @State private var showsPlanBuilder = false
  @State private var journalAlert: PriceAlert?

  init(symbol: String) {
    self.symbol = symbol
    _matches = Query(filter: #Predicate<Holding> { $0.symbol == symbol })
  }

  private var holding: Holding? { matches.first }
  private var quote: Quote? { quotes[symbol] }
  private func format(_ value: Double) -> String { quote?.formatted(value) ?? value.formatted(.number.precision(.fractionLength(2))) }

  private var series: (values: [Double], dates: [Date]) {
    if period.needsLongHistory(earliestDaily: quote?.dates.first) {
      guard let long = fiveYearQuote else { return ([], []) }
      return period.slice(values: long.closes, dates: long.dates)
    }
    guard let quote else { return ([], []) }
    return period.slice(values: quote.closes, dates: quote.dates)
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
    .sheet(isPresented: $showsPlanBuilder) {
      if let holding { PlanBuilderView(holding: holding) }
    }
    .sheet(item: $journalAlert) { alert in JournalSheet(alert: alert, quote: quote) }
    .task(id: period) {
      guard period.needsLongHistory(earliestDaily: quote?.dates.first), fiveYearQuote == nil else { return }
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
          .foregroundStyle(selection == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tint))
          .lineLimit(1)
        Text(selection.map { format(series.values[$0]) } ?? quote.map { format($0.price) } ?? "—")
          .font(.system(size: 40, weight: .bold, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())
        if let quote {
          if let selection, series.values[selection] > 0 {
            ChangeBadge(change: quote.price / series.values[selection] - 1, caption: "since then", positiveColor: Palette.gain, negativeColor: Palette.loss)
          } else if let first = series.values.first, let last = series.values.last, first > 0 {
            HStack(spacing: 12) {
              ChangeBadge(change: quote.change, caption: "today", positiveColor: Palette.gain, negativeColor: Palette.loss)
              ChangeBadge(change: last / first - 1, caption: period.isCustom ? "in period" : period.title, positiveColor: Palette.gain, negativeColor: Palette.loss)
            }
          }
        }
      }

      if series.values.count > 1 {
        InteractiveChart(
          values: series.values,
          dates: series.dates,
          levels: holding.activeAlerts.filter { !$0.kind.isZone }.compactMap { alert in
            quote.flatMap { alert.rule.triggerLevel(for: $0) }.map { InteractiveChart.Level(price: $0, side: alert.kind.side, label: alert.kind.title) }
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
          .frame(maxWidth: .infinity, minHeight: 230)
      }

      PeriodPicker(period: $period, earliest: Calendar.current.date(byAdding: .year, value: -5, to: .now) ?? .now)
    }
    .padding(20)
    .heroCardStyle()
    .padding(.top, 8)
  }

  // MARK: Plan

  private func planSection(for holding: Holding) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your Plan", subtitle: "Green is where you buy, red is where you sell") {
        Button("Build", systemImage: "wand.and.stars") { showsPlanBuilder = true }
          .font(.subheadline.weight(.semibold))
      }
      VStack(alignment: .leading, spacing: 16) {
        if let quote {
          let report = flock.reports[symbol]
          ZoneTrack(
            price: quote.price,
            bands: (holding.buyZones + holding.sellZones).map { ZoneTrack.Band(range: $0.targetPrice...max($0.targetPrice, $0.upperPrice), side: $0.kind.side, isCrowd: false) }
              + [report?.buyZone.map { ZoneTrack.Band(range: $0, side: .buy, isCrowd: true) },
                 report?.sellZone.map { ZoneTrack.Band(range: $0, side: .sell, isCrowd: true) }].compactMap { $0 },
            low: quote.low52,
            high: quote.high52,
            format: format
          )
          ZoneLegend(showsCrowd: report?.buyZone != nil || report?.sellZone != nil)
        }

        if holding.buyZones.isEmpty && holding.sellZones.isEmpty {
          Button {
            showsPlanBuilder = true
          } label: {
            Label("Build your plan in one step", systemImage: "wand.and.stars")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 6)
          }
          .buttonStyle(.borderedProminent)
        }

        tierList(title: "Buy", zones: holding.buyZones, side: .buy)
        tierList(title: "Sell", zones: holding.sellZones, side: .sell)

        if let ladder = holding.ladder {
          Label("If every funded buy tier fills: \(ladder.shares.formatted(.number.precision(.fractionLength(0...2)))) shares at an average of \(format(ladder.averagePrice)) for \(format(ladder.budget)).", systemImage: "equal.circle.fill")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .padding(18)
      .cardStyle()
    }
  }

  private func tierList(title: String, zones: [PriceAlert], side: TradeSide) -> some View {
    VStack(spacing: 8) {
      ForEach(Array(zones.enumerated()), id: \.element.id) { index, alert in
        Button {
          editor = AlertEditorTarget(alert: alert)
        } label: {
          HStack(spacing: 10) {
            Text(zones.count > 1 ? "\(title) \(index + 1)" : "\(title) zone")
              .font(.subheadline.weight(.bold))
              .foregroundStyle(side.color)
              .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
              Text("\(format(alert.targetPrice))–\(format(alert.upperPrice))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
              if alert.budget > 0 {
                Text("Budget \(format(alert.budget))")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            Spacer()
            if let quote, let distance = alert.distance(for: quote) {
              Text(distance == 0 ? "In zone" : "\(distance.formatted(.percent.precision(.fractionLength(1)))) away")
                .font(.caption.weight(.semibold))
                .foregroundStyle(distance == 0 ? side.color : .secondary)
            }
            Image(systemName: "chevron.forward")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.tertiary)
          }
          .padding(12)
          .background(side.color.opacity(0.1), in: .rect(cornerRadius: 14))
          .contentShape(.rect)
        }
        .buttonStyle(.plain)
      }
      if !zones.isEmpty || side == .buy {
        Button {
          addAlert(AlertRule(kind: side == .buy ? .buyZone : .sellZone))
        } label: {
          Label(zones.isEmpty ? "Add \(title.lowercased()) zone" : "Add \(title.lowercased()) tier", systemImage: "plus")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(side.color)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
      } else {
        Button {
          addAlert(AlertRule(kind: .sellZone))
        } label: {
          Label("Add sell zone", systemImage: "plus")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(side.color)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
      }
    }
  }

  private func otherAlerts(for holding: Holding) -> some View {
    let alerts = (holding.alerts ?? [])
      .filter { !($0.isActive && $0.kind.isZone) }
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
          VStack(spacing: 8) {
            Button {
              editor = AlertEditorTarget(alert: alert)
            } label: {
              AlertCard(alert: alert, quote: quote)
            }
            .buttonStyle(.plain)
            if alert.triggeredAt != nil && !alert.isActive && alert.journalAction == nil {
              Button("Log what you did", systemImage: "book.closed") { journalAlert = alert }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
            }
          }
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
