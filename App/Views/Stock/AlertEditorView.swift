import SwiftData
import SwiftUI

/// Create or edit any kind of alert for one stock: zones, price levels, or smart alerts.
struct AlertEditorView: View {
  var holding: Holding
  var alert: PriceAlert?
  var initialRule: AlertRule?

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(ProgressStore.self) private var progress
  @State private var intent: AlertIntent = .buy
  @State private var exactPrice = false
  @State private var smartKind: AlertKind = .dropFromHigh
  @State private var smartCategory: AlertCategory = .moves
  @State private var level: Double = 30
  @State private var periodDays = 5
  @State private var showsOptions = false
  @State private var lower: Double = 0
  @State private var upper: Double = 0
  @State private var percent: Double = 0.1
  @State private var averageDays = 200
  @State private var budget: Double?
  @State private var repeats = false
  @State private var expiry: Expiry = .never
  @State private var note = ""
  @State private var didLoad = false
  @State private var showsDeleteConfirmation = false
  @State private var showsPaywall = false

  private var quote: Quote? { quotes[holding.symbol] }
  private var report: FlockReport? { flock.reports[holding.symbol] }
  private func format(_ value: Double) -> String { quote?.formatted(value) ?? value.formatted(.number.precision(.fractionLength(2))) }

  private var kind: AlertKind {
    switch intent {
    case .buy: exactPrice ? .priceBelow : .buyZone
    case .sell: exactPrice ? .priceAbove : .sellZone
    case .smart: smartKind
    }
  }

  private func apply(kind: AlertKind) {
    switch kind {
    case .buyZone: intent = .buy; exactPrice = false
    case .priceBelow: intent = .buy; exactPrice = true
    case .sellZone: intent = .sell; exactPrice = false
    case .priceAbove: intent = .sell; exactPrice = true
    default: intent = .smart; smartKind = kind; smartCategory = kind.category
    }
  }

  private var rule: AlertRule {
    AlertRule(kind: kind, lower: kind.category == .zones || kind.needsCost ? lower : 0, upper: kind.isZone ? upper : 0,
              percent: kind.usesPercent ? percent : 0, averageDays: averageDays, peak: alert?.peakPrice ?? quote?.price ?? 0,
              level: kind.usesLevel ? level : 0, days: periodDays)
  }

  private var isLocked: Bool { kind.requiresPro && !subscription.isPro }
  private var isValid: Bool {
    switch kind {
    case .buyZone, .sellZone: lower > 0 && upper > lower
    case .priceBelow, .priceAbove, .breakEven: lower > 0
    case .stopLoss, .profitTarget: lower > 0 && percent > 0
    default: !kind.usesPercent || percent > 0
    }
  }

  var body: some View {
    NavigationStack {
      Form {
        Group {
        Section {
          IntentPicker(selection: $intent)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            .listRowBackground(Color.clear)
        }

        if let quote {
          Section {
            RuleSummary(rule: rule, quote: quote, symbol: holding.symbol, isLocked: isLocked)
          }
        }

        conditionSection

        if let report, report.hasEnoughData, kind.side != .watch {
          Section("The Flock") {
            FlockComparisonRow(report: report, rule: rule, isPro: subscription.isPro, format: format) {
              showsPaywall = true
            }
          }
        }

        Section {
          DisclosureGroup("More options", isExpanded: $showsOptions) {
            if kind.side == .buy {
              LabeledContent("Budget") {
                TextField("Optional", value: $budget, format: .currency(code: quote?.currency ?? "USD"))
                  .keyboardType(.decimalPad)
                  .multilineTextAlignment(.trailing)
              }
              if let budget, budget > 0, let price = rule.referencePrice ?? quote?.price, price > 0 {
                LabeledContent("You'd get about", value: "\((budget / price).formatted(.number.precision(.fractionLength(0...2)))) shares")
              }
            }
            Toggle("Alert every time", isOn: $repeats)
            Picker("Expires", selection: $expiry) {
              ForEach((alert?.expiresAt != nil ? [Expiry.custom] : []) + Expiry.allCases) { Text($0.title).tag($0) }
            }
            TextField("Your reason (shown in the alert)", text: $note, axis: .vertical)
              .lineLimit(2...4)
          }
        } footer: {
          Text("Add a budget, repeat the alert, set an expiry, or note why you chose this price.")
        }

        if let alert {
          Section {
            if !alert.isActive {
              Button("Re-arm Alert", systemImage: "arrow.clockwise") { rearm(alert) }
            }
            Button("Delete Alert", systemImage: "trash", role: .destructive) { showsDeleteConfirmation = true }
          }
        }
        }
        .dipwiseRows()
      }
      .dipwiseListStyle()
      .navigationTitle(alert == nil ? "New Alert" : "Edit Alert")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button(isLocked ? "Unlock" : "Save") {
            if isLocked { showsPaywall = true } else { save() }
          }
          .disabled(!isValid)
        }
      }
      .confirmationDialog("Delete this alert?", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
        Button("Delete Alert", role: .destructive) { delete() }
      }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
      .onAppear(perform: load)
      .onChange(of: kind) { oldKind, newKind in
        guard didLoad, oldKind != newKind else { return }
        if newKind.category == .zones {
          if oldKind.category != .zones || oldKind.side != newKind.side { loadSlotOrSuggest() }
        } else {
          applyDefaults(for: newKind)
        }
      }
      .sensoryFeedback(.selection, trigger: kind)
      .task {
        if let quote { await flock.load(symbol: holding.symbol, currentPrice: quote.price) }
      }
    }
  }

  // MARK: Condition

  @ViewBuilder
  private var conditionSection: some View {
    if let quote {
      switch intent {
      case .buy, .sell:
        Section {
          ZoneEditorChart(
            values: quote.recent(64).values,
            side: kind.side,
            lower: $lower,
            upper: kind.isZone ? $upper : nil,
            crowdZone: kind.side == .buy ? report?.buyZone : report?.sellZone,
            format: format
          )
          .frame(height: 230)
          .padding(.vertical, 6)
          presets(for: quote)
          Toggle("Exact price instead of a zone", isOn: $exactPrice.animation(.snappy))
          if kind.isZone {
            LabeledContent("From") { priceField($lower) }
            LabeledContent("To") { priceField($upper) }
          } else {
            LabeledContent("Price") { priceField($lower) }
          }
        } header: {
          Text("Drag the handles on the chart")
        } footer: {
          Text(levelDescription(for: quote))
        }

      case .smart:
        Section {
          Picker("Category", selection: $smartCategory.animation(.snappy)) {
            ForEach(AlertCategory.allCases.filter { $0 != .zones }) { Text($0.title).tag($0) }
          }
          .pickerStyle(.segmented)
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
          ForEach(AlertKind.smart.filter { $0.category == smartCategory }) { option in
            Button {
              withAnimation(.snappy) { smartKind = option }
            } label: {
              HStack(spacing: 12) {
                Image(systemName: option.systemImage)
                  .font(.headline)
                  .foregroundStyle(option.side.color)
                  .frame(width: 36, height: 36)
                  .background(option.side.color.opacity(0.14), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                  HStack(spacing: 6) {
                    Text(option.title).font(.headline)
                    if !subscription.isPro { ProBadge() }
                  }
                  Text(option.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: smartKind == option ? "checkmark.circle.fill" : "circle")
                  .font(.title3)
                  .foregroundStyle(smartKind == option ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
              }
              .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(smartKind == option ? .isSelected : [])
          }
        } header: {
          HStack {
            Text("Choose a smart alert")
            Spacer()
            InfoButton(topic: .category(smartCategory))
          }
        }

        Section {
          smartControls(for: quote)
        } footer: {
          Text(smartDescription(for: quote))
        }
      }
    } else {
      Section { ProgressView("Loading price…") }
    }
  }

  private func priceField(_ value: Binding<Double>) -> some View {
    TextField("Price", value: Binding(get: { value.wrappedValue }, set: { value.wrappedValue = max(0, $0) }), format: .number.precision(.fractionLength(2)))
      .keyboardType(.decimalPad)
      .multilineTextAlignment(.trailing)
      .font(.body.weight(.semibold).monospacedDigit())
      .foregroundStyle(kind.side.color)
  }

  private func presets(for quote: Quote) -> some View {
    ScrollView(.horizontal) {
      HStack(spacing: 8) {
        ForEach(presetOptions(for: quote), id: \.title) { preset in
          Button(preset.title) {
            withAnimation(.snappy) {
              lower = preset.lower
              if kind.isZone { upper = preset.upper }
            }
          }
          .font(.subheadline.weight(.semibold))
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background((kind.side.color).opacity(0.14), in: .capsule)
          .foregroundStyle(kind.side.color)
          .buttonStyle(.plain)
        }
      }
    }
    .scrollIndicators(.hidden)
  }

  private func presetOptions(for quote: Quote) -> [(title: String, lower: Double, upper: Double)] {
    var options: [(String, Double, Double)]
    if kind.side == .buy {
      options = [("Near 52-week low", quote.low52, quote.low52 * 1.04)]
      if let zone = report?.buyZone { options.insert(("Crowd zone", zone.lowerBound, zone.upperBound), at: 0) }
    } else {
      options = [("Near 52-week high", quote.high52 * 0.97, quote.high52)]
      if let zone = report?.sellZone { options.insert(("Crowd zone", zone.lowerBound, zone.upperBound), at: 0) }
    }
    if !kind.isZone {
      options = options.map { ($0.0, kind.side == .buy ? $0.2 : $0.1, 0) }
    }
    return options.map { (title: $0.0, lower: rounded($0.1), upper: rounded($0.2)) }
  }

  private func levelDescription(for quote: Quote) -> String {
    let level = kind == .buyZone ? upper : lower
    guard level > 0 else { return "" }
    let offset = level / quote.price - 1
    let distance = "\(abs(offset).formatted(.percent.precision(.fractionLength(1)))) \(offset < 0 ? "below" : "above") today's \(format(quote.price))"
    if kind.isZone {
      return "You'll be alerted when the price enters the zone, \(distance)."
    }
    return "Triggers \(distance)."
  }

  private var percentRange: ClosedRange<Double> {
    switch kind {
    case .dailyMove, .gapMove: 0.02...0.15
    case .weeklyDrop: 0.03...0.30
    case .trailingStop, .stopLoss: 0.03...0.30
    case .profitTarget: 0.05...1.0
    case .yieldAbove: 0.01...0.10
    case .beatsMarket, .lagsMarket: 0.02...0.25
    default: 0.05...0.50
    }
  }

  @ViewBuilder
  private func smartControls(for quote: Quote) -> some View {
    if kind.usesPercent {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text(percentLabel)
          Spacer()
          Text(percent, format: .percent.precision(.fractionLength(0)))
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(kind.side.color)
        }
        Slider(value: $percent, in: percentRange) {
          Text(percentLabel)
        } minimumValueLabel: {
          Text(percentRange.lowerBound, format: .percent.precision(.fractionLength(0)))
        } maximumValueLabel: {
          Text(percentRange.upperBound, format: .percent.precision(.fractionLength(0)))
        }
      }
    }
    if kind == .losingStreak {
      Picker("Days in a row", selection: $periodDays) {
        Text("3").tag(3)
        Text("4").tag(4)
        Text("5").tag(5)
        Text("7").tag(7)
      }
      .pickerStyle(.segmented)
    } else if kind.usesDays {
      Picker("Over", selection: $periodDays) {
        Text("1 week").tag(5)
        Text("2 weeks").tag(10)
        Text("1 month").tag(21)
        Text("3 months").tag(63)
      }
      .pickerStyle(.segmented)
    }
    if kind.usesAverage {
      Picker("Average", selection: $averageDays) {
        Text("50-day").tag(50)
        Text("100-day").tag(100)
        Text("200-day").tag(200)
      }
      .pickerStyle(.segmented)
    }
    if kind == .rsiOversold || kind == .rsiOverbought {
      Stepper(value: $level, in: kind == .rsiOversold ? 10...45 : 55...90, step: 5) {
        LabeledContent("RSI level", value: "\(Int(level))")
      }
    }
    if kind == .volumeSpike {
      Picker("Volume", selection: $level) {
        Text("1.5×").tag(1.5)
        Text("2×").tag(2.0)
        Text("3×").tag(3.0)
        Text("5×").tag(5.0)
      }
      .pickerStyle(.segmented)
    }
    if kind.needsCost {
      LabeledContent("Your average cost") { priceField($lower) }
    }
    if !kind.usesPercent && !kind.usesAverage && !kind.usesLevel && !kind.needsCost && !kind.usesDays {
      Label("No settings needed. Dippy handles it.", systemImage: "checkmark.circle")
        .foregroundStyle(.secondary)
    }
  }

  private var percentLabel: String {
    switch kind {
    case .dailyMove, .gapMove: "Move size"
    case .profitTarget: "Gain"
    case .yieldAbove: "Yield"
    case .beatsMarket: "Ahead by"
    case .lagsMarket: "Behind by"
    default: "Drop"
    }
  }

  private func smartDescription(for quote: Quote) -> String {
    switch kind {
    case .dropFromHigh:
      return "52-week high is \(format(quote.high52)), so this triggers at \(format(quote.high52 * (1 - percent))). Today it's \(abs(quote.drawdownFromHigh).formatted(.percent.precision(.fractionLength(1)))) below its high."
    case .trailingStop:
      let peak = max(alert?.peakPrice ?? 0, quote.price)
      return "Tracks the highest price from now on. Right now it would trigger at \(format(peak * (1 - percent)))."
    case .weeklyDrop:
      return "Over the last \(periodDays) trading days \(holding.symbol) moved \(quote.change(over: periodDays).formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())))."
    case .belowAverage, .aboveAverage:
      guard let average = quote.movingAverage(days: averageDays) else { return "Not enough price history for this average yet." }
      return "The \(averageDays)-day average is \(format(average)). Today's price is \(abs(quote.price / average - 1).formatted(.percent.precision(.fractionLength(1)))) \(quote.price >= average ? "above" : "below") it."
    case .goldenCross, .deathCross:
      guard let fast = quote.movingAverage(days: 50), let slow = quote.movingAverage(days: 200) else { return "Needs about a year of price history." }
      return "Today the 50-day average is \(format(fast)) and the 200-day is \(format(slow)). You'll hear about it the moment they cross."
    case .rsiOversold, .rsiOverbought:
      return quote.rsi().map { "RSI is \(Int($0)) today. Below 30 is usually called oversold, above 70 overbought." } ?? ""
    case .macdBullish, .macdBearish:
      return "Fires when momentum flips. Popular with trend followers."
    case .volumeSpike:
      return quote.volumeRatio.map { "Today's volume is \($0.formatted(.number.precision(.fractionLength(1))))× the 20-day average." } ?? ""
    case .stopLoss:
      return "Triggers at \(format(lower * (1 - percent)))."
    case .profitTarget:
      return "Triggers at \(format(lower * (1 + percent)))."
    case .breakEven:
      return "You'll know when \(holding.symbol) is back to what you paid."
    case .losingStreak:
      return "\(holding.symbol) has closed lower \(quote.losingStreak) days in a row right now."
    case .yieldAbove:
      return quote.dividendYield > 0 ? "Today's yield is \(quote.dividendYield.formatted(.percent.precision(.fractionLength(2)))). It rises when the price falls." : "\(holding.symbol) hasn't paid a dividend in the past year."
    case .beatsMarket, .lagsMarket:
      return quote.relativeToMarket(over: periodDays).map { "Over the last \(periodDays) trading days \(holding.symbol) is \($0.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always()))) versus the S&P 500." } ?? "Comparing with the S&P 500 once its prices load."
    case .dividendSoon:
      return quote.daysToNextDividend.map { "Next dividend expected in about \($0) days." } ?? "\(holding.symbol) hasn't paid a dividend in the past year."
    default:
      return kind.explanation
    }
  }

  // MARK: Actions

  private func defaultPercent(for kind: AlertKind) -> Double {
    let defaults = AlertRule.defaults(for: kind, price: quote?.price ?? 1, cost: holding.averageCost)
    return defaults.percent > 0 ? defaults.percent : 0.1
  }

  /// Fills in starting values when the user picks a smart alert.
  private func applyDefaults(for kind: AlertKind) {
    let defaults = AlertRule.defaults(for: kind, price: quote?.price ?? 1, cost: holding.averageCost)
    if kind.usesPercent { percent = defaults.percent }
    if kind.usesLevel { level = defaults.level }
    if kind.needsCost { lower = rounded(defaults.lower) }
    if kind == .weeklyDrop { periodDays = defaults.days }
  }

  private func rounded(_ value: Double) -> Double {
    let step: Double = value >= 1000 ? 1 : (value >= 10 ? 0.05 : 0.001)
    return (value / step).rounded() * step
  }

  private func suggestLevels() {
    guard let quote else { return }
    let price = quote.price
    switch kind.side {
    case .buy:
      lower = rounded(price * (kind.isZone ? 0.90 : 0.92))
      upper = rounded(price * 0.95)
    case .sell:
      lower = rounded(price * 1.10)
      upper = rounded(price * 1.18)
    case .watch:
      break
    }
  }

  private func load() {
    guard !didLoad else { return }
    didLoad = true
    if let alert {
      let rule = alert.rule
      apply(kind: rule.kind)
      lower = rule.lower
      upper = rule.upper
      percent = rule.percent > 0 ? rule.percent : defaultPercent(for: rule.kind)
      averageDays = rule.averageDays
      level = rule.level > 0 ? rule.level : level
      periodDays = rule.days
      budget = alert.budget > 0 ? alert.budget : nil
      repeats = alert.repeats
      expiry = alert.expiresAt == nil ? .never : .custom
      note = alert.note
      showsOptions = alert.budget > 0 || alert.repeats || alert.expiresAt != nil || !alert.note.isEmpty
    } else if let initialRule {
      apply(kind: initialRule.kind)
      if initialRule.kind.category != .zones {
        applyDefaults(for: initialRule.kind)
      } else if initialRule.lower > 0 {
        lower = rounded(initialRule.lower)
        upper = rounded(initialRule.upper)
      } else {
        loadSlotOrSuggest()
      }
    } else {
      loadSlotOrSuggest()
    }
  }

  /// A stock has one buy plan and one sell plan, so picking Buy or Sell edits the existing one.
  private var slotAlert: PriceAlert? {
    guard alert == nil else { return nil }
    switch intent {
    case .buy: return holding.buyZone
    case .sell: return holding.sellZone
    case .smart: return nil
    }
  }

  private func loadSlotOrSuggest() {
    if let existing = slotAlert {
      exactPrice = !existing.kind.isZone
      lower = existing.targetPrice
      upper = existing.upperPrice
      budget = existing.budget > 0 ? existing.budget : budget
    } else {
      suggestLevels()
    }
  }

  private func save() {
    guard isValid else { return }
    let current = quote?.price ?? lower
    let target: PriceAlert
    if let alert = alert ?? (kind.category == .zones ? slotAlert : nil) {
      let changed = alert.rule != rule
      alert.rule = rule
      if changed {
        alert.conditionMet = false
        if let quote { alert.prime(with: quote) }
        alert.headsUpSentAt = nil
        Task {
          await flock.withdraw(alert)
          await flock.share(alert)
          try? modelContext.save()
        }
      }
      target = alert
    } else {
      let alert = PriceAlert(rule: rule, priceAtCreation: current)
      alert.holding = holding
      if let quote { alert.prime(with: quote) }
      modelContext.insert(alert)
      progress.record(.alertCreated)
      ToastCenter.shared.show("Dippy is on it!", systemImage: "binoculars.fill")
      Task {
        await NotificationManager.requestAuthorization()
        await flock.share(alert)
        try? modelContext.save()
      }
      target = alert
    }
    target.budget = max(0, budget ?? 0)
    target.repeats = repeats
    target.note = note
    if let date = expiry.date(from: .now) { target.expiresAt = date } else if expiry == .never { target.expiresAt = nil }

    if let quote, target.isActive {
      // If the condition is already met, alert right away.
      let events = AlertEngine.evaluate([target], quotes: [quote.symbol: quote], headsUpThreshold: nil)
      Task { await NotificationManager.post(events) }
    }
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    dismiss()
  }

  private func rearm(_ alert: PriceAlert) {
    guard AlertLimits.canAddAlert(in: modelContext, isPro: subscription.isPro) else {
      showsPaywall = true
      return
    }
    alert.rearm(currentPrice: quote?.price ?? alert.priceAtCreation)
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    dismiss()
  }

  private func delete() {
    guard let alert else { return }
    Task { await flock.withdraw(alert) }
    modelContext.delete(alert)
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    dismiss()
  }
}

enum Expiry: String, CaseIterable, Identifiable {
  case never
  case week
  case month
  case quarter
  case custom

  var id: Self { self }

  static var allCases: [Expiry] { [.never, .week, .month, .quarter] }

  var title: String {
    switch self {
    case .never: "Never"
    case .week: "In 1 week"
    case .month: "In 1 month"
    case .quarter: "In 3 months"
    case .custom: "Keep current"
    }
  }

  func date(from start: Date) -> Date? {
    let calendar = Calendar.current
    switch self {
    case .never, .custom: return nil
    case .week: return calendar.date(byAdding: .day, value: 7, to: start)
    case .month: return calendar.date(byAdding: .month, value: 1, to: start)
    case .quarter: return calendar.date(byAdding: .month, value: 3, to: start)
    }
  }
}

enum AlertIntent: String, CaseIterable, Identifiable {
  case buy
  case sell
  case smart

  var id: Self { self }

  var title: String {
    switch self {
    case .buy: "Buy"
    case .sell: "Sell"
    case .smart: "Smart"
    }
  }

  var subtitle: String {
    switch self {
    case .buy: "When it drops"
    case .sell: "When it rises"
    case .smart: "Dips, stops, trends"
    }
  }

  var systemImage: String {
    switch self {
    case .buy: "arrow.down.to.line.compact"
    case .sell: "arrow.up.to.line.compact"
    case .smart: "sparkles"
    }
  }

  var color: Color {
    switch self {
    case .buy: Palette.buy
    case .sell: Palette.sell
    case .smart: Palette.amber
    }
  }
}

/// Three big choices: buy, sell, or a smart alert.
struct IntentPicker: View {
  @Binding var selection: AlertIntent

  var body: some View {
    HStack(spacing: 10) {
      ForEach(AlertIntent.allCases) { intent in
        let isSelected = intent == selection
        Button {
          withAnimation(.snappy) { selection = intent }
        } label: {
          VStack(spacing: 6) {
            Image(systemName: intent.systemImage)
              .font(.title2.weight(.semibold))
            Text(intent.title)
              .font(.headline)
            Text(intent.subtitle)
              .font(.caption2)
              .opacity(0.8)
              .lineLimit(1)
              .minimumScaleFactor(0.8)
          }
          .foregroundStyle(isSelected ? .white : intent.color)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 14)
          .background(isSelected ? AnyShapeStyle(intent.color) : AnyShapeStyle(intent.color.opacity(0.12)), in: .rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
  }
}

/// The alert in plain language, with its odds of firing.
struct RuleSummary: View {
  var rule: AlertRule
  var quote: Quote
  var symbol: String
  var isLocked: Bool

  var body: some View {
    let odds = AlertOdds(rule: rule, quote: quote)
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text("Alert me when \(symbol) is ready:")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        InfoButton(topic: rule.kind.category == .zones ? .zones : .alert(rule.kind))
      }
      Text(rule.summary(format: quote.formatted))
        .font(.title3.bold())
        .foregroundStyle(rule.kind.side.color)
        .contentTransition(.numericText())
      if let odds {
        HStack(spacing: 10) {
          OddsPill(title: "30 days", value: odds.monthChance)
          OddsPill(title: "90 days", value: odds.quarterChance)
        }
        HStack {
          Label(odds.lastTriggeredText, systemImage: "clock.arrow.circlepath")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
          InfoButton(topic: .odds)
        }
      }
      if isLocked {
        Label("Smart alerts are part of Dipwise Pro", systemImage: "lock.fill")
          .font(.caption.weight(.semibold))
          .foregroundStyle(Palette.amber)
      }
    }
    .padding(.vertical, 4)
    .animation(.snappy, value: rule)
  }
}

/// A probability with a small fill bar.
struct OddsPill: View {
  var title: String
  var value: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
        Text(value, format: .percent.precision(.fractionLength(0)))
          .font(.subheadline.bold().monospacedDigit())
      }
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(.quaternary)
          Capsule().fill(Palette.amber).frame(width: max(4, geometry.size.width * value))
        }
      }
      .frame(height: 5)
    }
    .padding(10)
    .background(.quaternary.opacity(0.4), in: .rect(cornerRadius: 12))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Chance to trigger within \(title)")
    .accessibilityValue(value.formatted(.percent.precision(.fractionLength(0))))
  }
}

/// Compares the user's level with where the flock has set theirs.
struct FlockComparisonRow: View {
  var report: FlockReport
  var rule: AlertRule
  var isPro: Bool
  var format: (Double) -> String
  var upgrade: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      let side = rule.kind.side
      if let zone = side == .buy ? report.buyZone : report.sellZone {
        LabeledContent("Crowd \(side == .buy ? "buy" : "sell") zone") {
          Text("\(format(zone.lowerBound))–\(format(zone.upperBound))")
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .monospacedDigit()
            .foregroundStyle(side.color)
        }
      }
      if isPro {
        if let level = rule.referencePrice, let patience = report.patience(of: level, side: side) {
          Text("Your level is more patient than \(patience, format: .percent.precision(.fractionLength(0))) of investors on this side.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      } else {
        Button("Compare your level with the crowd", systemImage: "lock.fill", action: upgrade)
          .font(.subheadline)
      }
    }
  }
}
