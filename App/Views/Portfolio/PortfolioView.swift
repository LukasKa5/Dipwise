import Charts
import SwiftData
import SwiftUI

/// Everything about the user's portfolio: performance, allocation, dividends, and buying power.
struct PortfolioView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @AppStorage(AlertSettings.cashBalanceKey) private var cash = 0.0
  @State private var period: ChartPeriod = .preset(.threeMonths)
  @State private var selectedIndex: Int?
  @State private var allocation: AllocationMode = .holding
  @State private var sort: PositionSort = .value
  @State private var showsCashEditor = false

  private var summary: PortfolioSummary {
    PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase, intraday: quotes.intraday)
  }

  private func money(_ value: Double) -> String { quotes.formatBase(value) }

  var body: some View {
    let summary = summary
    ScrollView {
      VStack(alignment: .leading, spacing: 28) {
        if summary.hasPositions {
          overview(summary)
          performance(summary)
          allocationSection(summary)
          dividends(summary)
          positions(summary)
          movers(summary)
          buyingPower(summary)
        } else {
          ContentUnavailableView(
            "No Positions Yet",
            systemImage: "chart.pie",
            description: Text("Add the number of shares you own on any stock to see your portfolio, dividends, and allocation.")
          )
          .padding(.top, 60)
        }
        DisclaimerFooter(lastUpdated: quotes.lastUpdated)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity)
    }
    .background(Palette.canvas)
    .task(id: period) {
      if period.isIntraday { await quotes.loadIntraday(symbols: holdings.map(\.symbol)) }
    }
    .navigationTitle("Portfolio")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showsCashEditor) {
      CashEditorView(cash: $cash, currency: quotes.baseCurrency)
        .presentationDetents([.height(260)])
    }
  }

  // MARK: Overview

  private func overview(_ summary: PortfolioSummary) -> some View {
    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
      StatTile(title: "Total value", value: money(summary.totalValue), systemImage: "briefcase.fill", tint: Palette.green)
      StatTile(title: "Today", value: signed(summary.dayChangeAmount) + " (\(summary.dayChange.formatted(.percent.precision(.fractionLength(1)))))",
               systemImage: summary.dayChange >= 0 ? "arrow.up.right" : "arrow.down.right", tint: summary.dayChange >= 0 ? Palette.green : Palette.loss)
      StatTile(title: "Unrealized gain", value: summary.costBasis > 0 ? signed(summary.unrealizedGain) : "Add costs", systemImage: "plus.forwardslash.minus", tint: summary.unrealizedGain >= 0 ? Palette.green : Palette.loss)
      StatTile(title: "Total return", value: summary.totalReturn.map { $0.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())) } ?? "—", systemImage: "chart.line.uptrend.xyaxis", tint: Palette.green)
    }
    .padding(.top, 8)
  }

  private func signed(_ value: Double) -> String { (value >= 0 ? "+" : "") + money(value) }

  // MARK: Performance

  private func performance(_ summary: PortfolioSummary) -> some View {
    let history = summary.history(period: period)
    let selected = selectedIndex.flatMap { history.values.indices.contains($0) ? $0 : nil }
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Performance", subtitle: "Value of today's positions over time")
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          if let selected {
            Text(money(history.values[selected]))
              .font(.title2.bold().monospacedDigit())
            Text(history.dates.indices.contains(selected) ? history.dates[selected].formatted(date: .abbreviated, time: .omitted) : "")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          } else if let first = history.values.first, let last = history.values.last, first > 0 {
            ChangeBadge(change: last / first - 1, caption: period.isCustom ? "in period" : "over \(period.title)", positiveColor: Palette.gain, negativeColor: Palette.loss)
          }
        }
        .frame(height: 30, alignment: .leading)
        InteractiveChart(values: history.values, dates: history.dates, showsOwl: true, owlSize: 40, selectedIndex: $selectedIndex)
          .frame(height: 200)
        PeriodPicker(period: $period, presets: [.day, .week, .month, .threeMonths, .year], earliest: summary.earliestDate)
      }
      .padding(18)
      .heroCardStyle()
    }
  }

  // MARK: Allocation

  private enum AllocationMode: String, CaseIterable, Identifiable {
    case holding = "Holdings"
    case type = "Asset type"
    case currency = "Currency"
    var id: Self { self }
  }

  private func allocationSection(_ summary: PortfolioSummary) -> some View {
    let slices: [PortfolioSummary.Slice] = switch allocation {
    case .holding: summary.allocationByHolding
    case .type: summary.allocationByType
    case .currency: summary.allocationByCurrency
    }
    let palette: [Color] = [Palette.buy, Palette.amber, .teal, .indigo, .pink, .orange, .cyan, .purple, .yellow, .gray]
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Allocation") { InfoButton(topic: .allocation) }
      VStack(spacing: 18) {
        Picker("Group by", selection: $allocation) {
          ForEach(AllocationMode.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)

        HStack(spacing: 20) {
          Chart(Array(slices.enumerated()), id: \.element.id) { index, slice in
            SectorMark(angle: .value("Value", slice.value), innerRadius: .ratio(0.62), angularInset: 1.5)
              .foregroundStyle(palette[index % palette.count])
              .cornerRadius(3)
          }
          .chartBackground { _ in
            VStack(spacing: 0) {
              Text("\(slices.count)")
                .font(.title2.bold())
              Text(allocation.rawValue.lowercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
          }
          .frame(width: 140, height: 140)

          VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(slices.prefix(6).enumerated()), id: \.element.id) { index, slice in
              HStack(spacing: 8) {
                Circle().fill(palette[index % palette.count]).frame(width: 9, height: 9)
                Text(slice.label)
                  .font(.subheadline.weight(.semibold))
                  .lineLimit(1)
                Spacer(minLength: 4)
                Text(slice.share, format: .percent.precision(.fractionLength(0)))
                  .font(.subheadline.monospacedDigit())
                  .foregroundStyle(.secondary)
              }
            }
          }
        }

        if let biggest = summary.biggestPosition, biggest.weight > 0.35 {
          Label("\(biggest.holding.symbol) is \(biggest.weight.formatted(.percent.precision(.fractionLength(0)))) of your portfolio. Consider whether that concentration fits your plan.", systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(Palette.amber)
        }
      }
      .padding(18)
      .cardStyle()
    }
  }

  // MARK: Dividends

  private func dividends(_ summary: PortfolioSummary) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Dividends", subtitle: "Projected from the last twelve months") {
        HStack(spacing: 4) {
          if !subscription.isPro { ProBadge() }
          InfoButton(topic: .dividends)
        }
      }
      VStack(alignment: .leading, spacing: 18) {
        HStack(spacing: 12) {
          DividendFigure(title: "Per year", value: money(summary.annualDividendIncome))
          DividendFigure(title: "Per month", value: money(summary.annualDividendIncome / 12))
          DividendFigure(title: "Yield", value: summary.dividendYield.formatted(.percent.precision(.fractionLength(2))))
          if let yieldOnCost = summary.yieldOnCost {
            DividendFigure(title: "On cost", value: yieldOnCost.formatted(.percent.precision(.fractionLength(2))))
          }
        }

        VStack(alignment: .leading, spacing: 18) {
          Chart(summary.monthlyDividends, id: \.month) { item in
            BarMark(x: .value("Month", item.month, unit: .month), y: .value("Income", item.amount))
              .foregroundStyle(Palette.amber.gradient)
              .cornerRadius(4)
          }
          .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { _ in
              AxisValueLabel(format: .dateTime.month(.narrow))
            }
          }
          .chartYAxis {
            AxisMarks(position: .leading) { value in
              AxisGridLine()
              AxisValueLabel {
                if let amount = value.as(Double.self) {
                  Text(amount, format: .currency(code: quotes.baseCurrency).precision(.fractionLength(0)))
                }
              }
            }
          }
          .frame(height: 150)
          .accessibilityLabel("Expected dividend income for the next twelve months")

          let upcoming = summary.upcomingPayments.prefix(5)
          if upcoming.isEmpty {
            Text("None of your positions paid dividends in the last year.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          } else {
            VStack(spacing: 10) {
              ForEach(Array(upcoming)) { payment in
                HStack {
                  TickerBadge(symbol: payment.symbol, size: 30)
                  Text(payment.symbol)
                    .font(.subheadline.weight(.semibold))
                  Spacer()
                  Text(payment.date, format: .dateTime.day().month(.abbreviated))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                  Text(money(payment.amount))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 80, alignment: .trailing)
                }
                .accessibilityElement(children: .combine)
              }
            }
          }
        }
        .proLocked(!subscription.isPro, message: "See your dividend calendar and monthly income")
      }
      .padding(18)
      .cardStyle()
    }
  }

  // MARK: Positions

  private enum PositionSort: String, CaseIterable, Identifiable {
    case value = "Value"
    case today = "Today"
    case total = "Return"
    var id: Self { self }
  }

  private func positions(_ summary: PortfolioSummary) -> some View {
    let sorted = summary.positions.sorted { lhs, rhs in
      switch sort {
      case .value: lhs.value > rhs.value
      case .today: lhs.quote.change > rhs.quote.change
      case .total: (lhs.totalReturn ?? -.infinity) > (rhs.totalReturn ?? -.infinity)
      }
    }
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Positions") {
        Picker("Sort", selection: $sort) {
          ForEach(PositionSort.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.menu)
      }
      VStack(spacing: 0) {
        ForEach(sorted) { position in
          NavigationLink(value: position.holding.symbol) {
            PositionRow(position: position, money: money)
          }
          .buttonStyle(.plain)
          if position.id != sorted.last?.id {
            Divider().padding(.leading, 66)
          }
        }
      }
      .cardStyle()
    }
  }

  // MARK: Movers

  @ViewBuilder
  private func movers(_ summary: PortfolioSummary) -> some View {
    let byToday = summary.positions.sorted { $0.quote.change > $1.quote.change }
    if byToday.count >= 2, let best = byToday.first, let worst = byToday.last {
      HStack(spacing: 12) {
        MoverTile(title: "Best today", position: best)
        MoverTile(title: "Worst today", position: worst)
      }
    }
  }

  // MARK: Buying power

  private func buyingPower(_ summary: PortfolioSummary) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Buying Power", subtitle: "Cash ready for your buy zones") {
        HStack(spacing: 4) {
          InfoButton(topic: .buyingPower)
          Button("Edit") { showsCashEditor = true }
            .font(.subheadline.weight(.semibold))
        }
      }
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Cash").font(.caption).foregroundStyle(.secondary)
            Text(money(cash)).font(.title3.bold().monospacedDigit())
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 4) {
            Text("Planned in buy alerts").font(.caption).foregroundStyle(.secondary)
            Text(money(summary.plannedBuys)).font(.title3.bold().monospacedDigit()).foregroundStyle(Palette.buy)
          }
        }
        if summary.plannedBuys > 0 {
          ProgressView(value: min(cash, summary.plannedBuys), total: max(summary.plannedBuys, 1))
            .tint(cash >= summary.plannedBuys ? Palette.green : Palette.amber)
          Text(cash >= summary.plannedBuys
               ? "You have enough cash for every planned buy."
               : "You're \(money(summary.plannedBuys - cash)) short of funding every planned buy.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          Text("Add a budget to a buy zone to plan how much you'll invest when it triggers.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
      }
      .padding(18)
      .cardStyle()
    }
  }
}

private struct DividendFigure: View {
  var title: String
  var value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(value)
        .font(.headline.monospacedDigit())
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .combine)
  }
}

private struct PositionRow: View {
  var position: PortfolioSummary.Position
  var money: (Double) -> String

  var body: some View {
    VStack(spacing: 8) {
      HStack(spacing: 12) {
        TickerBadge(symbol: position.holding.symbol, size: 40)
        VStack(alignment: .leading, spacing: 2) {
          Text(position.holding.symbol).font(.headline)
          Text("\(position.holding.shares.formatted()) × \(position.quote.formatted(position.quote.price))")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        VStack(alignment: .trailing, spacing: 2) {
          Text(money(position.value)).font(.headline.monospacedDigit())
          HStack(spacing: 8) {
            ChangeBadge(change: position.quote.change).font(.caption)
            if let total = position.totalReturn {
              Text(total, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(total >= 0 ? Palette.green : Palette.loss)
            }
          }
        }
      }
      GeometryReader { geometry in
        Capsule()
          .fill(Palette.green.opacity(0.7))
          .frame(width: max(4, geometry.size.width * position.weight), height: 4)
      }
      .frame(height: 4)
      .padding(.leading, 52)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
    .accessibilityValue("\(position.weight.formatted(.percent.precision(.fractionLength(0)))) of portfolio")
  }
}

private struct MoverTile: View {
  var title: String
  var position: PortfolioSummary.Position

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
      HStack {
        TickerBadge(symbol: position.holding.symbol, size: 32)
        Text(position.holding.symbol).font(.headline)
      }
      ChangeBadge(change: position.quote.change)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .cardStyle(cornerRadius: 20)
    .accessibilityElement(children: .combine)
  }
}

private struct CashEditorView: View {
  @Binding var cash: Double
  var currency: String
  @Environment(\.dismiss) private var dismiss
  @State private var draft: Double?

  var body: some View {
    NavigationStack {
      Form {
        Group {
        Section {
          TextField("Cash available", value: $draft, format: .currency(code: currency))
            .keyboardType(.decimalPad)
            .font(.title2.bold())
        } footer: {
          Text("The cash you keep ready at your broker for buying dips.")
        }
        }
        .dipwiseRows()
      }
      .dipwiseListStyle()
      .navigationTitle("Cash")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            cash = max(0, draft ?? 0)
            dismiss()
          }
        }
      }
      .onAppear { draft = cash > 0 ? cash : nil }
    }
  }
}
