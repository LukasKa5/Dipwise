import SwiftData
import SwiftUI

/// Set up several alerts for one stock at once: buy tiers, a sell zone, and smart alerts.
struct PlanBuilderView: View {
  var holding: Holding

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext
  @Environment(QuoteStore.self) private var quotes
  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(ProgressStore.self) private var progress
  @State private var draft = PlanDraft()
  @State private var template: PlanTemplate?
  @State private var budget: Double?
  @State private var showsPaywall = false

  private var quote: Quote? { quotes[holding.symbol] }
  private func format(_ value: Double) -> String { quote?.formatted(value) ?? value.formatted() }

  private func round(_ value: Double) -> Double {
    let step: Double = value >= 1000 ? 1 : (value >= 10 ? 0.05 : 0.001)
    return (value / step).rounded() * step
  }

  private var rules: [(rule: AlertRule, budget: Double)] {
    guard let quote else { return [] }
    var draft = draft
    draft.budget = budget ?? 0
    return draft.rules(price: quote.price, round: round)
  }

  private var needsPro: Bool {
    guard !subscription.isPro else { return false }
    let smart = rules.contains { $0.rule.kind.requiresPro }
    let total = AlertLimits.activeAlertCount(in: modelContext) + rules.count
    return smart || total > FreeTier.maxActiveAlerts
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          ScrollView(.horizontal) {
            HStack(spacing: 10) {
              ForEach(PlanTemplate.allCases) { item in
                Button {
                  withAnimation(.snappy) {
                    template = item
                    draft = PlanDraft(template: item)
                  }
                } label: {
                  VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: item.systemImage)
                      .font(.title3)
                    Text(item.title)
                      .font(.subheadline.weight(.bold))
                    Text(item.subtitle)
                      .font(.caption)
                      .foregroundStyle(template == item ? .white.opacity(0.85) : .secondary)
                      .lineLimit(2)
                      .multilineTextAlignment(.leading)
                  }
                  .foregroundStyle(template == item ? .white : .primary)
                  .frame(width: 140, height: 104, alignment: .topLeading)
                  .padding(12)
                  .background(template == item ? AnyShapeStyle(Palette.buy) : AnyShapeStyle(Palette.card), in: .rect(cornerRadius: 16))
                  .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(.quaternary, lineWidth: template == item ? 0 : 1) }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(template == item ? .isSelected : [])
              }
            }
            .padding(.horizontal, 20)
          }
          .scrollIndicators(.hidden)
          .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
          .listRowBackground(Color.clear)
        } header: {
          Text("Start from a template")
        }

        if let quote {
          Section {
            ZoneTrack(
              price: quote.price,
              bands: rules.filter { $0.rule.kind.isZone }.map { ZoneTrack.Band(range: $0.rule.lower...$0.rule.upper, side: $0.rule.kind.side, isCrowd: false) }
                + [flock.reports[holding.symbol]?.buyZone.map { ZoneTrack.Band(range: $0, side: .buy, isCrowd: true) }].compactMap { $0 },
              low: nil,
              high: nil,
              format: format
            )
            .padding(.vertical, 6)
            ZoneLegend(showsCrowd: flock.reports[holding.symbol]?.buyZone != nil)
          } header: {
            Text("Preview")
          }
        }

        Section {
          Picker("Buy tiers", selection: $draft.buyTiers.animation(.snappy)) {
            Text("None").tag(0)
            Text("1").tag(1)
            Text("2").tag(2)
            Text("3").tag(3)
          }
          .pickerStyle(.segmented)
          if draft.buyTiers > 0 {
            Picker("Spacing", selection: $draft.depth) {
              ForEach(PlanDraft.Depth.allCases) { Text("\($0.title) · \(Int($0.step * 100))% apart").tag($0) }
            }
            LabeledContent("Total budget") {
              TextField("Optional", value: $budget, format: .currency(code: quote?.currency ?? "USD"))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            }
            ForEach(Array(rules.filter { $0.rule.kind == .buyZone }.enumerated()), id: \.offset) { index, item in
              HStack {
                Circle().fill(Palette.buy).frame(width: 8, height: 8)
                Text("Tier \(index + 1)")
                Spacer()
                Text("\(format(item.rule.lower))–\(format(item.rule.upper))")
                  .monospacedDigit()
                  .foregroundStyle(Palette.buy)
                if item.budget > 0 {
                  Text(format(item.budget))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
              }
              .font(.subheadline)
            }
          }
        } header: {
          Label("Buy ladder", systemImage: "arrow.down.to.line.compact")
            .foregroundStyle(Palette.buy)
        } footer: {
          Text("Splitting your buy into tiers lowers your average price if the dip deepens.")
        }

        Section {
          Toggle("Take-profit zone", isOn: $draft.sellZone.animation(.snappy))
          if draft.sellZone {
            Picker("Target", selection: $draft.sellTarget) {
              ForEach(PlanDraft.SellTarget.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
          }
        } header: {
          Label("Sell zone", systemImage: "arrow.up.to.line.compact")
            .foregroundStyle(Palette.sell)
        }

        Section {
          smartToggle("Trailing stop 8%", kind: .trailingStop, isOn: $draft.trailingStop)
          smartToggle("20% dip from 52-week high", kind: .dropFromHigh, isOn: $draft.dropFromHigh)
          smartToggle("5% move in a day", kind: .dailyMove, isOn: $draft.dailyMove)
          smartToggle("Falls below 200-day average", kind: .belowAverage, isOn: $draft.belowAverage)
        } header: {
          Text("Smart alerts")
        }
      }
      .navigationTitle("Plan \(holding.symbol)")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
        ToolbarItem(placement: .confirmationAction) {
          Button(needsPro ? "Unlock" : "Create \(rules.count)") {
            if needsPro { showsPaywall = true } else { save() }
          }
          .disabled(rules.isEmpty || quote == nil)
        }
      }
      .onChange(of: draft) { if template.map(PlanDraft.init(template:)) != draft { template = nil } }
      .sheet(isPresented: $showsPaywall) { PaywallView() }
    }
  }

  private func smartToggle(_ title: String, kind: AlertKind, isOn: Binding<Bool>) -> some View {
    Toggle(isOn: isOn) {
      HStack(spacing: 8) {
        Label(title, systemImage: kind.systemImage)
        if kind.requiresPro && !subscription.isPro { ProBadge() }
      }
    }
  }

  private func save() {
    guard let quote else { return }
    for item in rules {
      let alert = PriceAlert(rule: item.rule, priceAtCreation: quote.price)
      alert.budget = item.budget
      alert.holding = holding
      modelContext.insert(alert)
      progress.record(.alertCreated)
      Task { await flock.share(alert) }
    }
    try? modelContext.save()
    SnapshotPublisher.publish(context: modelContext)
    Task { await NotificationManager.requestAuthorization() }
    dismiss()
  }
}
