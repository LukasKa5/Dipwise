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
    default: intent = .smart; smartKind = kind
    }
  }

  private var rule: AlertRule {
    AlertRule(kind: kind, lower: lower, upper: kind.isZone ? upper : 0, percent: kind.usesPercent ? percent : 0,
              averageDays: averageDays, peak: alert?.peakPrice ?? quote?.price ?? 0)
  }

  private var isLocked: Bool { kind.requiresPro && !subscription.isPro }
  private var isValid: Bool {
    switch kind {
    case .buyZone, .sellZone: lower > 0 && upper > lower
    case .priceBelow, .priceAbove: lower > 0
    case .dropFromHigh, .dailyMove, .trailingStop: percent > 0
    case .belowAverage: true
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
        if oldKind.side != newKind.side || oldKind.isZone != newKind.isZone { suggestLevels() }
        if newKind.usesPercent && oldKind != newKind { percent = defaultPercent(for: newKind) }
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
          ForEach([AlertKind.dropFromHigh, .trailingStop, .dailyMove, .belowAverage]) { option in
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
          Text("Choose a smart alert")
        }

        Section {
          if kind == .belowAverage {
            Picker("Average", selection: $averageDays) {
              Text("50-day").tag(50)
              Text("100-day").tag(100)
              Text("200-day").tag(200)
            }
            .pickerStyle(.segmented)
          } else {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Text(kind == .dailyMove ? "Move size" : "Drop")
                Spacer()
                Text(percent, format: .percent.precision(.fractionLength(0)))
                  .font(.title3.bold().monospacedDigit())
                  .foregroundStyle(kind.side.color)
              }
              Slider(value: $percent, in: percentRange) {
                Text("Percentage")
              } minimumValueLabel: {
                Text(percentRange.lowerBound, format: .percent.precision(.fractionLength(0)))
              } maximumValueLabel: {
                Text(percentRange.upperBound, format: .percent.precision(.fractionLength(0)))
              }
            }
          }
        } footer: {
          if kind == .belowAverage, let average = quote.movingAverage(days: averageDays) {
            Text("The \(averageDays)-day average is \(format(average)). Today's price is \(abs(quote.price / average - 1).formatted(.percent.precision(.fractionLength(1)))) \(quote.price >= average ? "above" : "below") it.")
          } else {
            Text(percentDescription(for: quote))
          }
        }
      }
    } else {
      Section { ProgressView("Loading price…") }
    }
  }

  private func priceField(_ value: Binding<Double>) -> some View {
    TextField("Price", value: value, format: .number.precision(.fractionLength(2)))
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
    let price = quote.price
    var options: [(String, Double, Double)]
    if kind.side == .buy {
      options = [("−3 to −6%", price * 0.94, price * 0.97), ("−5 to −10%", price * 0.90, price * 0.95), ("−10 to −15%", price * 0.85, price * 0.90)]
      options.append(("Near 52-week low", quote.low52, quote.low52 * 1.04))
      if let zone = report?.buyZone { options.insert(("Crowd zone", zone.lowerBound, zone.upperBound), at: 0) }
    } else {
      options = [("+5 to +10%", price * 1.05, price * 1.10), ("+10 to +20%", price * 1.10, price * 1.20)]
      options.append(("Near 52-week high", quote.high52 * 0.97, quote.high52))
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
    case .dailyMove: 0.02...0.15
    case .trailingStop: 0.03...0.30
    default: 0.05...0.50
    }
  }

  private func percentDescription(for quote: Quote) -> String {
    switch kind {
    case .dropFromHigh:
      let level = quote.high52 * (1 - percent)
      return "52-week high is \(format(quote.high52)), so this triggers at \(format(level)). Today the stock is \(abs(quote.drawdownFromHigh).formatted(.percent.precision(.fractionLength(1)))) below its high."
    case .trailingStop:
      let peak = max(alert?.peakPrice ?? 0, quote.price)
      return "Tracks the highest price from now on. Right now it would trigger at \(format(peak * (1 - percent)))."
    case .dailyMove:
      return "Fires when \(holding.symbol) rises or falls \(percent.formatted(.percent.precision(.fractionLength(0)))) or more in a single day."
    default:
      return ""
    }
  }

  // MARK: Actions

  private func defaultPercent(for kind: AlertKind) -> Double {
    switch kind {
    case .dailyMove: 0.05
    case .trailingStop: 0.08
    default: 0.2
    }
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
      budget = alert.budget > 0 ? alert.budget : nil
      repeats = alert.repeats
      expiry = alert.expiresAt == nil ? .never : .custom
      note = alert.note
      showsOptions = alert.budget > 0 || alert.repeats || alert.expiresAt != nil || !alert.note.isEmpty
    } else if let initialRule {
      apply(kind: initialRule.kind)
      percent = initialRule.percent > 0 ? initialRule.percent : defaultPercent(for: initialRule.kind)
      if initialRule.lower > 0 {
        lower = rounded(initialRule.lower)
        upper = rounded(initialRule.upper)
      } else {
        suggestLevels()
      }
    } else {
      suggestLevels()
    }
  }

  private func save() {
    guard isValid else { return }
    let current = quote?.price ?? lower
    let target: PriceAlert
    if let alert {
      let changed = alert.rule != rule
      alert.rule = rule
      if changed {
        alert.conditionMet = false
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
      modelContext.insert(alert)
      progress.record(.alertCreated)
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
      Text("Alert me when \(symbol) is ready:")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Text(rule.summary(format: quote.formatted))
        .font(.title3.bold())
        .foregroundStyle(rule.kind.side.color)
        .contentTransition(.numericText())
      if let odds {
        HStack(spacing: 10) {
          OddsPill(title: "30 days", value: odds.monthChance)
          OddsPill(title: "90 days", value: odds.quarterChance)
        }
        Label(odds.lastTriggeredText, systemImage: "clock.arrow.circlepath")
          .font(.caption)
          .foregroundStyle(.secondary)
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
