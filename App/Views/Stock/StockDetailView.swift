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
    let active = holding.activeAlerts.sorted {
      (quote.flatMap($0.distance(for:)) ?? .infinity) < (quote.flatMap($1.distance(for:)) ?? .infinity)
    }
    let fired = (holding.alerts ?? []).filter { !$0.isActive }.sorted { ($0.triggeredAt ?? $0.createdAt) > ($1.triggeredAt ?? $1.createdAt) }
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Your Plan", subtitle: "Everything Dipp watches on \(symbol)") {
        Button("Build", systemImage: "wand.and.stars") { showsPlanBuilder = true }
          .font(.subheadline.weight(.semibold))
      }
      VStack(alignment: .leading, spacing: 0) {
        if let quote, ![holding.buyZone, holding.sellZone].compactMap { $0 }.isEmpty {
          let report = flock.reports[symbol]
          VStack(alignment: .leading, spacing: 10) {
            ZoneTrack(
              price: quote.price,
              bands: [holding.buyZone, holding.sellZone].compactMap { $0 }.map { ZoneTrack.Band(range: $0.targetPrice...max($0.targetPrice, $0.upperPrice), side: $0.kind.side, isCrowd: false) }
                + [report?.buyZone.map { ZoneTrack.Band(range: $0, side: .buy, isCrowd: true) },
                   report?.sellZone.map { ZoneTrack.Band(range: $0, side: .sell, isCrowd: true) }].compactMap { $0 },
              low: quote.low52,
              high: quote.high52,
              format: format
            )
            ZoneLegend(showsCrowd: report?.buyZone != nil || report?.sellZone != nil)
          }
          .padding(16)
          Divider()
        }

        if active.isEmpty {
          VStack(spacing: 12) {
            LivelyOwl().frame(width: 56, height: 64)
            Text("No plan for \(symbol) yet")
              .font(.headline)
            Text("Tell Dipp where you'd buy more and where you'd take profit.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
            Button {
              showsPlanBuilder = true
            } label: {
              Label("Build my plan", systemImage: "wand.and.stars")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
          }
          .padding(20)
          .frame(maxWidth: .infinity)
        } else {
          ForEach(active) { alert in
            Button {
              editor = AlertEditorTarget(alert: alert)
            } label: {
              PlanRow(alert: alert, quote: quote, showsOdds: subscription.isPro || alert.id == active.first?.id)
            }
            .buttonStyle(.plain)
            Divider().padding(.leading, 64)
          }
        }

        Button {
          addAlert(nil)
        } label: {
          Label("Add alert", systemImage: "plus.circle.fill")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)

        if !fired.isEmpty {
          Divider()
          DisclosureGroup {
            ForEach(fired) { alert in
              HStack(spacing: 10) {
                Image(systemName: alert.kind.systemImage)
                  .foregroundStyle(alert.kind.side.color)
                  .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                  Text(alert.summary(for: quote))
                    .font(.subheadline)
                    .lineLimit(1)
                  if let triggeredAt = alert.triggeredAt, let price = alert.triggeredPrice {
                    Text("Fired \(triggeredAt.formatted(.relative(presentation: .named))) at \(format(price))")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
                Spacer()
                Button(alert.journalAction?.title ?? "Log") { journalAlert = alert }
                  .font(.caption.weight(.semibold))
                  .buttonStyle(.bordered)
                  .controlSize(.small)
              }
              .padding(.vertical, 4)
              .contextMenu {
                Button("Edit or Re-arm", systemImage: "pencil") { editor = AlertEditorTarget(alert: alert) }
              }
            }
          } label: {
            Label("History · \(fired.count) fired", systemImage: "clock.arrow.circlepath")
              .font(.subheadline.weight(.semibold))
          }
          .padding(16)
        }
      }
      .cardStyle()
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

/// One alert in a stock's plan: what it watches, how far away it is, and its odds.
private struct PlanRow: View {
  var alert: PriceAlert
  var quote: Quote?
  var showsOdds: Bool

  var body: some View {
    let tint = alert.kind.side.color
    let distance = quote.flatMap { alert.distance(for: $0) }
    let odds = quote.flatMap { AlertOdds(rule: alert.rule, quote: $0) }
    HStack(spacing: 12) {
      Image(systemName: alert.kind.systemImage)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(tint)
        .frame(width: 36, height: 36)
        .background(tint.opacity(0.14), in: .circle)
      VStack(alignment: .leading, spacing: 4) {
        Text(alert.summary(for: quote))
          .font(.subheadline.weight(.semibold))
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 6) {
          if let odds, showsOdds, distance != 0 {
            Label(odds.headline, systemImage: "dice")
              .foregroundStyle(Palette.amber)
          }
          if alert.budget > 0, let quote {
            Text("Budget \(quote.formatted(alert.budget))")
              .foregroundStyle(.secondary)
          }
          if alert.repeats {
            Image(systemName: "repeat").foregroundStyle(.secondary)
          }
        }
        .font(.caption)
        if let quote {
          TargetTrack(progress: alert.progress(for: quote), isReached: distance == 0, tint: tint)
        }
      }
      Spacer(minLength: 6)
      VStack(alignment: .trailing, spacing: 2) {
        Text(distance == 0 ? "Now" : distance.map { $0.formatted(.percent.precision(.fractionLength(1))) } ?? "—")
          .font(.subheadline.bold().monospacedDigit())
          .foregroundStyle(distance == 0 || (distance ?? 1) < 0.035 ? tint : .primary)
        Text(distance == 0 ? "active" : "away")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
      Image(systemName: "chevron.forward")
        .font(.caption.weight(.semibold))
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
  }
}
