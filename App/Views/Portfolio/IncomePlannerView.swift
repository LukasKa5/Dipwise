import Charts
import SwiftData
import SwiftUI

/// The passive income planner: today's dividend income against a monthly goal, how it grows year by year, and
/// exactly how much to invest each month to reach the goal by a chosen year.
struct IncomePlannerView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Environment(QuoteStore.self) private var quotes
  @Environment(SubscriptionManager.self) private var subscription
  @AppStorage("income.goal") private var goal = 500.0
  @AppStorage("income.monthly") private var monthly = 300.0
  @AppStorage("income.targetYear") private var targetYear = Calendar.current.component(.year, from: .now) + 10
  @AppStorage("income.growth") private var growth = 0.05
  @AppStorage("income.reinvests") private var reinvests = true
  @AppStorage("income.yield") private var customYield = 0.0

  private var summary: PortfolioSummary {
    PortfolioSummary(holdings: holdings, quotes: quotes.quotes, baseCurrency: quotes.baseCurrency, convert: quotes.toBase, intraday: quotes.intraday)
  }

  private var plan: IncomePlan {
    let summary = summary
    let yield = customYield > 0 ? customYield : max(summary.dividendYield, 0.005)
    return IncomePlan(value: summary.totalValue, yield: yield, monthly: monthly, growth: growth, reinvests: reinvests,
                      goalPerMonth: goal, targetYear: targetYear)
  }

  private func money(_ value: Double) -> String {
    value.formatted(.currency(code: quotes.baseCurrency).precision(.fractionLength(0)))
  }

  var body: some View {
    let plan = plan
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        hero(plan)
        Group {
          projection(plan)
          answer(plan)
        }
        .proLocked(!subscription.isPro, message: "See when you reach your income goal, and what it takes, with Pro")
        controls(plan)
        Text("A projection, not a promise. Dividends can be cut and prices fall. Growth and yield are your own assumptions.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 20)
      .padding(.bottom, 32)
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity)
    }
    .background(Palette.canvas)
    .navigationTitle("Passive Income")
    .navigationBarTitleDisplayMode(.inline)
    .sensoryFeedback(.selection, trigger: monthly)
  }

  // MARK: Sections

  private func hero(_ plan: IncomePlan) -> some View {
    HStack(spacing: 18) {
      ZStack {
        Circle().stroke(.white.opacity(0.12), lineWidth: 12)
        Circle()
          .trim(from: 0, to: plan.progress)
          .stroke(Brand.amber, style: StrokeStyle(lineWidth: 12, lineCap: .round))
          .rotationEffect(.degrees(-90))
        Text(plan.progress, format: .percent.precision(.fractionLength(0)))
          .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
          .fitsNumber()
          .padding(10)
      }
      .frame(width: 96, height: 96)
      .animation(.smooth, value: plan.progress)
      VStack(alignment: .leading, spacing: 4) {
        Text("Passive income today")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.7))
        Text("\(money(plan.currentPerMonth)) a month")
          .font(.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
          .fitsNumber()
        Text("Goal: \(money(goal)) a month")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(Brand.amber)
          .fitsNumber()
      }
      Spacer(minLength: 0)
    }
    .padding(20)
    .foregroundStyle(.white)
    .heroCardStyle()
    .accessibilityElement(children: .combine)
  }

  private func projection(_ plan: IncomePlan) -> some View {
    let horizon = max(targetYear, plan.yearReached ?? targetYear) + 2
    let years = plan.projection().filter { $0.year <= horizon }
    let reached = plan.yearReached
    return VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "How It Grows", subtitle: "Dividend income per month, year by year")
      Chart {
        ForEach(years) { year in
          BarMark(x: .value("Year", String(year.year)), y: .value("Per month", year.perMonth))
            .foregroundStyle(year.year == reached ? Brand.amber : Palette.green.opacity(year.perMonth >= goal ? 1 : 0.55))
            .cornerRadius(3)
        }
        RuleMark(y: .value("Goal", goal))
          .foregroundStyle(Brand.amber)
          .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
          .annotation(position: .top, alignment: .leading) {
            Text("Goal \(money(goal))")
              .font(.caption2.weight(.bold))
              .foregroundStyle(Brand.amber)
          }
      }
      .chartXAxis {
        AxisMarks(values: .stride(by: 1)) { value in
          if let year = value.as(String.self), let number = Int(year), (number - plan.startYear) % 5 == 0 {
            AxisValueLabel(year)
          }
        }
      }
      .frame(height: 200)
      .padding(16)
      .cardStyle()
    }
  }

  private func answer(_ plan: IncomePlan) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "flag.checkered")
          .font(.headline)
          .foregroundStyle(Brand.amber)
          .frame(width: 36, height: 36)
          .background(Brand.amber.opacity(0.15), in: .circle)
        VStack(alignment: .leading, spacing: 4) {
          if let year = plan.yearReached {
            Text("At \(money(monthly)) a month, you reach \(money(goal)) a month in \(String(year)).")
              .font(.headline)
          } else {
            Text("At \(money(monthly)) a month, the goal is more than 40 years away.")
              .font(.headline)
          }
          if let needed = plan.monthlyNeeded {
            Text(needed == 0 ? "You'll reach it by \(String(targetYear)) without adding more."
                             : "To get there by \(String(targetYear)), invest \(money(needed)) a month.")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }
        .fixedSize(horizontal: false, vertical: true)
      }
      if let needed = plan.monthlyNeeded, needed > 0, abs(needed - monthly) > 1 {
        Button {
          withAnimation(.smooth) { monthly = needed }
        } label: {
          Text("Use \(money(needed)) a month")
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(16)
    .cardStyle()
  }

  private func controls(_ plan: IncomePlan) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Your Plan")
      VStack(spacing: 0) {
        LabeledContent("Goal per month") {
          TextField("Goal", value: $goal, format: .currency(code: quotes.baseCurrency).precision(.fractionLength(0)))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.trailing)
            .monospacedDigit()
        }
        .padding(16)
        Divider().padding(.leading, 16)
        VStack(alignment: .leading, spacing: 8) {
          LabeledContent("Invest every month", value: money(monthly))
            .monospacedDigit()
          Slider(value: $monthly, in: 0...3000, step: 25) {
            Text("Invest every month")
          } minimumValueLabel: {
            Text(money(0)).font(.caption)
          } maximumValueLabel: {
            Text(money(3000)).font(.caption)
          }
        }
        .padding(16)
        Divider().padding(.leading, 16)
        Stepper(value: $targetYear, in: (plan.startYear + 1)...(plan.startYear + 40)) {
          LabeledContent("Reach it by", value: String(targetYear))
        }
        .padding(16)
        Divider().padding(.leading, 16)
        Stepper(value: Binding(get: { plan.yield }, set: { customYield = $0 }), in: 0.005...0.12, step: 0.0025) {
          LabeledContent("Dividend yield", value: plan.yield.formatted(.percent.precision(.fractionLength(2))))
        }
        .padding(16)
        Divider().padding(.leading, 16)
        Stepper(value: $growth, in: 0...0.12, step: 0.005) {
          LabeledContent("Yearly growth", value: growth.formatted(.percent.precision(.fractionLength(1))))
        }
        .padding(16)
        Divider().padding(.leading, 16)
        Toggle("Reinvest dividends", isOn: $reinvests)
          .padding(16)
      }
      .cardStyle()
    }
  }
}

/// The way into the planner from the Dividends section: today's income against the goal.
struct IncomeGoalCard: View {
  var currentPerMonth: Double
  var currency: String
  @AppStorage("income.goal") private var goal = 500.0

  var body: some View {
    NavigationLink {
      IncomePlannerView()
    } label: {
      HStack(spacing: 14) {
        Gauge(value: min(currentPerMonth / max(goal, 1), 1)) {
          EmptyView()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(Brand.amber)
        .scaleEffect(0.9)
        VStack(alignment: .leading, spacing: 2) {
          Text("Passive income goal")
            .font(.headline)
          Text("\(currentPerMonth.formatted(.currency(code: currency).precision(.fractionLength(0)))) of \(goal.formatted(.currency(code: currency).precision(.fractionLength(0)))) a month")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .fitsNumber()
        }
        Spacer(minLength: 4)
        Image(systemName: "chevron.forward")
          .font(.footnote.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(16)
      .cardStyle()
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
