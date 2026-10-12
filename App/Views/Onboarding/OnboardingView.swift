import AuthenticationServices
import SwiftData
import SwiftUI
import WidgetKit

/// An interactive tour that ends with the user's first stocks and buy zones being watched.
struct OnboardingView: View {
  var onFinish: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(QuoteStore.self) private var quoteStore
  @Environment(FlockService.self) private var flock
  @Environment(ProgressStore.self) private var progress
  @Environment(SubscriptionManager.self) private var subscription
  @Environment(AccountStore.self) private var account
  @State private var model = OnboardingModel()
  @State private var page = 0
  @State private var showsPaywall = false
  @State private var celebration = 0
  @State private var xpToast: Int?

  private let pageCount = 12

  private var canContinue: Bool {
    switch page {
    case 1: !model.styles.isEmpty
    case 2: !model.selected.isEmpty
    case 6: model.vote != nil
    default: true
    }
  }

  private var buttonTitle: String {
    switch page {
    case 2: model.selected.isEmpty ? "Pick at least one" : "Watch \(model.selected.count) \(model.selected.count == 1 ? "stock" : "stocks")"
    case 5: model.smartKinds.isEmpty ? "Maybe later" : "Add \(model.smartKinds.count) smart \(model.smartKinds.count == 1 ? "alert" : "alerts")"
    case 6: model.vote == nil ? "Cast your vote" : "Continue"
    case 9: "Allow Notifications"
    case 10: account.isSignedIn ? "Continue" : "Continue without an account"
    case 11: "Start Watching"
    default: "Continue"
    }
  }

  var body: some View {
    ZStack {
      Brand.nightMiddle.ignoresSafeArea()
      VStack(spacing: 0) {
        topBar
        Group {
          switch page {
          case 0: WelcomeStep(model: model)
          case 1: StyleStep(model: model)
          case 2: PickStep(model: model)
          case 3: ScrubStep(model: model)
          case 4: ZoneStep(model: model)
          case 5: SmartStep(model: model)
          case 6: FlockStep(model: model)
          case 7: WidgetStep(model: model)
          case 8: WatchStep(model: model)
          case 9: NotifyStep()
          case 10: AccountStep()
          default: RevealStep(model: model, streak: max(1, progress.streak))
          }
        }
        .id(page)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        .frame(maxWidth: 560, maxHeight: .infinity)

        Button(action: advance) {
          Text(buttonTitle)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(Brand.buy)
        .disabled(!canContinue)
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .frame(maxWidth: 520)
        .sensoryFeedback(.impact(weight: .light), trigger: page)
      }
      Confetti(trigger: celebration)
      if let toast = xpToast {
        XPToast(points: toast)
          .transition(.scale(scale: 0.4).combined(with: .opacity).combined(with: .move(edge: .top)))
          .frame(maxHeight: .infinity, alignment: .top)
          .padding(.top, 60)
      }
    }
    .onChange(of: model.missionCelebration) {
      celebration += 1
      withAnimation(.bouncy) { xpToast = OnboardingModel.missionPoints }
      Task {
        try? await Task.sleep(for: .seconds(1.4))
        withAnimation(.smooth) { xpToast = nil }
      }
    }
    .sensoryFeedback(.success, trigger: model.missionCelebration)
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
    .task { await model.loadQuotes() }
    .sheet(isPresented: $showsPaywall, onDismiss: {
      if subscription.isPro { model.commitSmartAlerts(context: modelContext) }
      SnapshotPublisher.publish(context: modelContext)
      onFinish()
    }) {
      PaywallView()
    }
  }

  private var topBar: some View {
    HStack(spacing: 14) {
      Button("Back", systemImage: "chevron.backward") {
        withAnimation(.smooth) { page -= 1 }
      }
      .labelStyle(.iconOnly)
      .font(.title3.weight(.semibold))
      .opacity(page > 0 && page < pageCount - 1 ? 1 : 0)
      .disabled(page == 0 || page == pageCount - 1)
      .accessibilityHidden(page == 0 || page == pageCount - 1)
      GeometryReader { geometry in
        ZStack(alignment: .leading) {
          Capsule().fill(.white.opacity(0.15))
          Capsule().fill(Brand.buy)
            .frame(width: geometry.size.width * Double(page + 1) / Double(pageCount))
        }
      }
      .frame(height: 12)
      .animation(.snappy, value: page)
      .accessibilityElement()
      .accessibilityLabel("Step \(page + 1) of \(pageCount)")
      Label("\(model.earnedXP)", systemImage: "bolt.fill")
        .font(.subheadline.weight(.heavy).monospacedDigit())
        .foregroundStyle(Brand.amber)
        .contentTransition(.numericText())
        .animation(.bouncy, value: model.earnedXP)
        .accessibilityLabel("\(model.earnedXP) XP earned")
      Button("Skip") { showsPaywall = true }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.7))
        .opacity(page < pageCount - 1 ? 1 : 0)
        .disabled(page == pageCount - 1)
        .accessibilityHidden(page == pageCount - 1)
    }
    .padding(.horizontal, 24)
    .padding(.top, 12)
  }

  private func advance() {
    switch page {
    case 3: model.prepareZone()
    case 10:
      if !account.isSignedIn { account.continueAsGuest() }
    case 9:
      Task {
        await NotificationManager.requestAuthorization()
        withAnimation(.smooth) { page += 1 }
        celebration += 1
      }
      return
    case 11:
      let created = model.commit(context: modelContext, quoteStore: quoteStore, isPro: subscription.isPro)
      for alert in created {
        Task { await flock.share(alert) }
      }
      progress.record(.onboarding)
      progress.addBonus(model.earnedXP)
      SnapshotPublisher.publish(context: modelContext)
      showsPaywall = true
      return
    default: break
    }
    if page == 2 { model.prepareZone() }
    withAnimation(reduceMotion ? .easeInOut : .smooth) { page += 1 }
  }
}

// MARK: - Steps

private struct StepTitle: View {
  var title: String
  var message: String?

  var body: some View {
    VStack(spacing: 8) {
      Text(title)
        .font(.title.bold())
        .multilineTextAlignment(.center)
      if let message {
        Text(message)
          .font(.body)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
      }
    }
    .padding(.horizontal, 24)
  }
}

private struct WelcomeStep: View {
  var model: OnboardingModel
  @State private var taps = 0
  @State private var arrived = false
  private let lines = [
    "Hoo! Tap me three times.",
    "I'm Dippy, your stock-watching owl.",
    "I watch your stocks day and night…",
    "…and tell you when it's time to act.",
    "Let's set me up in one minute!",
  ]

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      MissionChip(text: "Tap Dippy 3 times", isDone: model.completedMissions.contains("welcome"))
      SpeechBubble(text: lines[min(taps, lines.count - 1)])
        .animation(.snappy, value: taps)
      LivelyOwl(mood: .calm)
        .frame(width: 180, height: 206)
        .simultaneousGesture(TapGesture().onEnded {
          taps += 1
          if taps >= 3 { model.complete("welcome") }
        })
        .offset(x: arrived ? 0 : 260, y: arrived ? 0 : -520)
        .rotationEffect(.degrees(arrived ? 0 : 30))
        .owlFlight(trigger: arrived ? 1 : 0, height: 30)
        .onAppear {
          withAnimation(.spring(duration: 1.2, bounce: 0.35)) { arrived = true }
        }
        .accessibilityLabel("Dippy the owl")
        .accessibilityAddTraits(.isButton)
      StepTitle(title: "Invest calmly. Let the owl watch.", message: "Dipwise sits between you and your broker, watching your plan so you don't have to.")
      Spacer()
    }
  }
}

private struct StyleStep: View {
  @Bindable var model: OnboardingModel
  @State private var hops = 0

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        HStack(alignment: .top, spacing: 12) {
          LivelyOwl(hopsOnTap: false, mood: .calm)
            .frame(width: 70, height: 80)
            .owlFlight(trigger: hops, height: 24)
          SpeechBubble(text: model.lastStyle?.owlReply ?? "What brings you here? Pick as many as you like.")
            .animation(.snappy, value: model.lastStyle)
        }
        .padding(.top, 12)
        VStack(spacing: 12) {
          ForEach(InvestorStyle.allCases) { style in
            let isSelected = model.styles.contains(style)
            Button {
              withAnimation(.snappy) { model.toggle(style: style) }
              if isSelected == false { hops += 1 }
            } label: {
              HStack(spacing: 14) {
                Image(systemName: style.systemImage)
                  .font(.title3)
                  .frame(width: 30)
                Text(style.title)
                  .font(.headline)
                Spacer()
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                  .font(.title3)
              }
              .padding(18)
              .foregroundStyle(isSelected ? Brand.owlInk : .white)
              .background(isSelected ? AnyShapeStyle(Brand.buy) : AnyShapeStyle(.white.opacity(0.08)), in: .rect(cornerRadius: 18))
              .scaleEffect(isSelected ? 1.02 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
          }
          if model.styles.contains(.other) {
            TextField("What would you like Dippy to help with?", text: $model.otherGoal, axis: .vertical)
              .lineLimit(1...3)
              .padding(16)
              .background(.white.opacity(0.1), in: .rect(cornerRadius: 16))
              .transition(.move(edge: .top).combined(with: .opacity))
          }
        }
        .padding(.horizontal, 24)
        .sensoryFeedback(.selection, trigger: model.styles)
      }
    }
    .scrollDismissesKeyboard(.interactively)
  }
}

private struct PickStep: View {
  var model: OnboardingModel

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        StepTitle(title: "Pick stocks to watch", message: "Choose up to five. You can add any stock later.")
          .padding(.top, 16)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
          ForEach(OnboardingModel.suggestions, id: \.self) { symbol in
            let isSelected = model.selected.contains(symbol)
            let quote = model.quotes[symbol]
            Button {
              withAnimation(.bouncy) { model.toggle(symbol) }
            } label: {
              HStack(spacing: 10) {
                TickerBadge(symbol: symbol, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                  Text(symbol).font(.headline)
                  if let quote {
                    Text(quote.change, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
                      .font(.caption.weight(.semibold).monospacedDigit())
                      .foregroundStyle(quote.change >= 0 ? Brand.buy : Brand.sell)
                  } else {
                    Text("—").font(.caption).foregroundStyle(.white.opacity(0.5))
                  }
                }
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                  .font(.title3)
                  .foregroundStyle(isSelected ? Brand.buy : .white.opacity(0.5))
              }
              .padding(12)
              .background(.white.opacity(isSelected ? 0.16 : 0.07), in: .rect(cornerRadius: 16))
              .overlay {
                RoundedRectangle(cornerRadius: 16).strokeBorder(isSelected ? Brand.buy : .clear, lineWidth: 2)
              }
              .scaleEffect(isSelected ? 1.03 : 1)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
          }
        }
        .padding(.horizontal, 20)
        .sensoryFeedback(.selection, trigger: model.selected)
      }
    }
  }
}

private struct ScrubStep: View {
  var model: OnboardingModel
  @State private var selectedIndex: Int?
  @State private var scrubs = 0

  var body: some View {
    let quote = model.focusQuote
    let series: (values: [Double], dates: [Date]) = quote?.recent(64) ?? ([], [])
    VStack(spacing: 22) {
      Spacer()
      MissionChip(text: "Slide along the chart until Dippy flies", isDone: model.completedMissions.contains("scrub"))
      VStack(alignment: .leading, spacing: 6) {
        if let selectedIndex, series.values.indices.contains(selectedIndex) {
          Text(series.dates.indices.contains(selectedIndex) ? series.dates[selectedIndex].formatted(date: .abbreviated, time: .omitted) : "")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.buy)
          Text(quote?.formatted(series.values[selectedIndex]) ?? "")
            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
        } else {
          Text("\(model.focusSymbol ?? "") · slide your finger along the chart")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
          Text(quote.map { $0.formatted($0.price) } ?? "")
            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 28)

      if series.values.count > 1 {
        InteractiveChart(values: series.values, dates: series.dates, gridColor: .white.opacity(0.08), owlSize: 56, owlMood: .calm, selectedIndex: $selectedIndex)
          .frame(height: 240)
          .padding(.horizontal, 20)
          .onChange(of: selectedIndex) { _, index in
            if index != nil { scrubs += 1 }
            if scrubs > 15 { model.complete("scrub") }
          }
      } else {
        ProgressView().tint(.white).frame(height: 240)
      }

      StepTitle(
        title: scrubs > 15 ? "You startled Dippy!" : "Glance, don't stare",
        message: scrubs > 15 ? "He always flies off to find the next dip. That's his job." : "Read any day's price at a touch. Get close to the owl and see what happens."
      )
      .animation(.smooth, value: scrubs > 15)
      Spacer()
    }
  }
}

private struct ZoneStep: View {
  @Bindable var model: OnboardingModel

  var body: some View {
    let quote = model.focusQuote
    VStack(spacing: 22) {
      Spacer()
      MissionChip(text: "Drag a green handle", isDone: model.completedMissions.contains("zone"))
      StepTitle(title: "Draw your buy zone", message: "Drag the green handles to the range where you'd happily buy \(model.focusSymbol ?? "more").")
      if let quote {
        ZoneEditorChart(values: quote.recent(64).values, side: .buy, lower: $model.zoneLower, upper: $model.zoneUpper,
                        crowdZone: nil, format: { quote.formatted($0) })
          .frame(height: 250)
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(.white.opacity(0.06), in: .rect(cornerRadius: 24))
          .padding(.horizontal, 16)
        Label("Buy between \(quote.formatted(model.zoneLower)) and \(quote.formatted(model.zoneUpper))", systemImage: "arrow.down.to.line.compact")
          .font(.headline)
          .foregroundStyle(Brand.buy)
          .contentTransition(.numericText())
          .onChange(of: model.zoneLower) { model.complete("zone") }
          .onChange(of: model.zoneUpper) { model.complete("zone") }
        if let odds = AlertOdds(rule: AlertRule(kind: .buyZone, lower: model.zoneLower, upper: model.zoneUpper), quote: quote) {
          Label("\(odds.monthChance.formatted(.percent.precision(.fractionLength(0)))) chance it's reached within 30 days", systemImage: "dice.fill")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.amber)
            .contentTransition(.numericText())
            .animation(.snappy, value: odds.monthChance)
        }
        HStack(spacing: 16) {
          Label("Green = buy", systemImage: "circle.fill").foregroundStyle(Brand.buy)
          Label("Red = sell", systemImage: "circle.fill").foregroundStyle(Brand.sell)
        }
        .font(.caption.weight(.semibold))
      }
      Spacer()
    }
  }
}

private struct FlockStep: View {
  @Bindable var model: OnboardingModel
  @State private var flights = 0

  private var votes: FlockVotes {
    FlockVotes(bullish: 612 + (model.vote == true ? 1 : 0), bearish: 288 + (model.vote == false ? 1 : 0))
  }

  var body: some View {
    VStack(spacing: 22) {
      Spacer()
      LivelyOwl(hopsOnTap: false, mood: .calm)
        .frame(width: 90, height: 104)
        .owlFlight(trigger: flights, height: 40)
      StepTitle(title: "Invest with the flock", message: model.vote == nil ? "Thousands of investors share their plans anonymously. What's your call?" : "You're part of the flock now. See where everyone buys and sells, on every stock.")
        .animation(.smooth, value: model.vote)
      MissionChip(text: "Vote with the flock", isDone: model.completedMissions.contains("flock"))
      VoteCard(symbol: model.focusSymbol ?? "NVDA", votes: votes, userVote: model.vote) { bullish in
        model.vote = bullish
        flights += 1
        model.complete("flock")
      }
      .padding(.horizontal, 20)
      Spacer()
    }
  }
}

private struct WidgetStep: View {
  var model: OnboardingModel
  @State private var index = 0
  @State private var showsZones = false

  private var symbols: [String] { model.selected.isEmpty ? ["NVDA", "AAPL", "MSFT"] : model.selected }

  /// Sample plans built from the stocks the user just picked, rendered with the real widget views.
  private var statuses: [TargetStatus] {
    symbols.enumerated().compactMap { offset, symbol in
      guard let quote = model.quotes[symbol] else { return nil }
      let rule = symbol == model.focusSymbol && model.zoneUpper > 0
        ? AlertRule(kind: .buyZone, lower: model.zoneLower, upper: model.zoneUpper)
        : AlertRule(kind: offset.isMultiple(of: 2) ? .buyZone : .sellZone,
                    lower: quote.price * (offset.isMultiple(of: 2) ? 0.88 : 1.08),
                    upper: quote.price * (offset.isMultiple(of: 2) ? 0.94 : 1.15))
      return TargetStatus(target: WatchedTarget(id: UUID(), symbol: symbol, name: quote.name, rule: rule), quote: quote)
    }
    .sorted { ($0.distance ?? 1) < ($1.distance ?? 1) }
  }

  var body: some View {
    VStack(spacing: 22) {
      Spacer(minLength: 8)
      VStack(spacing: 16) {
        HStack(alignment: .top, spacing: 16) {
          PlansWidgetView(entry: PlansEntry(date: .now, statuses: statuses, index: index), previewFamily: .systemSmall)
            .padding(14)
            .frame(width: 150, height: 150)
            .background(Brand.nightMiddle, in: .rect(cornerRadius: 24))
            .allowsHitTesting(false)
            .contentShape(.rect)
            .onTapGesture {
              withAnimation(.bouncy) { index += 1 }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Plans widget. Tap to see the next stock.")
            .accessibilityAddTraits(.isButton)
          LazyVGrid(columns: [GridItem(.fixed(58)), GridItem(.fixed(58))], spacing: 16) {
            Image(.appIconPreview).resizable().frame(width: 58, height: 58).clipShape(.rect(cornerRadius: 14))
            ForEach([Color.blue, .green, .orange], id: \.self) { color in
              RoundedRectangle(cornerRadius: 14).fill(color.gradient).frame(width: 58, height: 58)
            }
          }
        }
        StockPlanWidgetView(entry: StockPlanEntry(date: .now, symbol: model.focusSymbol ?? symbols.first,
                                                  quote: (model.focusSymbol ?? symbols.first).flatMap { model.quotes[$0] },
                                                  targets: statuses.map(\.target).filter { $0.symbol == (model.focusSymbol ?? symbols.first) }),
                            previewFamily: .systemMedium)
          .padding(14)
          .frame(width: 316, height: 150)
          .background(Brand.nightMiddle, in: .rect(cornerRadius: 24))
          .allowsHitTesting(false)
          .contentShape(.rect)
          .onTapGesture {
            WidgetState.showsZones.toggle()
            withAnimation(.smooth) { showsZones.toggle() }
          }
          .id(showsZones)
          .accessibilityElement(children: .combine)
          .accessibilityLabel("Stock plan widget. Tap to switch between chart and zones.")
          .accessibilityAddTraits(.isButton)
      }
      .padding(18)
      .background(Brand.nightTop, in: .rect(cornerRadius: 36))
      .overlay { RoundedRectangle(cornerRadius: 36).strokeBorder(.white.opacity(0.15), lineWidth: 2) }
      StepTitle(title: "Dippy on your Home Screen", message: "These are the real widgets. Tap them: they flip through your plans and switch between chart and zones.")
      Spacer(minLength: 8)
    }
    .sensoryFeedback(.selection, trigger: index)
    .sensoryFeedback(.selection, trigger: showsZones)
  }
}

private struct WatchStep: View {
  var model: OnboardingModel
  @State private var page = 0
  @State private var notification = false

  private var symbol: String { model.focusSymbol ?? "NVDA" }

  var body: some View {
    VStack(spacing: 26) {
      Spacer(minLength: 8)
      ZStack {
        RoundedRectangle(cornerRadius: 58)
          .fill(Color.black)
          .frame(width: 220, height: 264)
          .overlay { RoundedRectangle(cornerRadius: 58).strokeBorder(.white.opacity(0.25), lineWidth: 6) }
        Capsule().fill(.white.opacity(0.3)).frame(width: 8, height: 46).offset(x: 116, y: -40)
        Group {
          if page == 0 { face } else { plans }
        }
        .frame(width: 190, height: 234)
        .clipShape(.rect(cornerRadius: 46))
        .transition(.push(from: .bottom))
        if notification {
          VStack(spacing: 6) {
            Image(.appIconPreview).resizable().frame(width: 34, height: 34).clipShape(.circle)
            Text("\(symbol) entered your buy zone")
              .font(.footnote.weight(.semibold))
              .multilineTextAlignment(.center)
          }
          .padding(12)
          .frame(width: 180)
          .background(.ultraThinMaterial, in: .rect(cornerRadius: 26))
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .onTapGesture {
        withAnimation(.smooth) { page = (page + 1) % 2 }
        model.complete("watch")
      }
      .accessibilityElement(children: .combine)
      .accessibilityLabel("Apple Watch preview. Tap to switch screens.")
      .accessibilityAddTraits(.isButton)
      MissionChip(text: "Tap the watch", isDone: model.completedMissions.contains("watch"))
      StepTitle(title: "On your wrist", message: "A gentle tap when a stock reaches your zone, your nearest plan on the watch face, and every plan a glance away. Tap the watch.")
      Spacer(minLength: 8)
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: notification)
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2.5))
        withAnimation(.bouncy) { notification = true }
        try? await Task.sleep(for: .seconds(2.2))
        withAnimation(.smooth) { notification = false }
        try? await Task.sleep(for: .seconds(1.5))
      }
    }
  }

  private var face: some View {
    VStack(spacing: 10) {
      Text("10:09")
        .font(.system(size: 44, weight: .semibold, design: .rounded))
      HStack(spacing: 12) {
        ZStack {
          Circle().stroke(.white.opacity(0.2), lineWidth: 5)
          Circle().trim(from: 0, to: 0.78).stroke(Brand.buy, style: StrokeStyle(lineWidth: 5, lineCap: .round)).rotationEffect(.degrees(-90))
          Text(symbol.prefix(4)).font(.system(size: 11, weight: .bold))
        }
        .frame(width: 50, height: 50)
        ZStack {
          Circle().fill(.white.opacity(0.1))
          VStack(spacing: 0) {
            Image(systemName: "flame.fill").foregroundStyle(Brand.amber)
            Text("12").font(.system(size: 12, weight: .bold))
          }
        }
        .frame(width: 50, height: 50)
      }
      HStack(spacing: 6) {
        OwlMark().frame(width: 22)
        VStack(alignment: .leading, spacing: 1) {
          Text("\(symbol) · 2.4%").font(.system(size: 12, weight: .bold))
          Text("to buy zone").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
        }
      }
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }

  private var plans: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Plans").font(.system(size: 16, weight: .bold)).foregroundStyle(Brand.buy)
      ForEach((model.selected.isEmpty ? ["NVDA", "AAPL"] : Array(model.selected.prefix(3))), id: \.self) { item in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(item).font(.system(size: 13, weight: .bold))
            Spacer()
            Text(model.quotes[item].map { $0.change.formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())) } ?? "")
              .font(.system(size: 11, weight: .semibold))
              .foregroundStyle((model.quotes[item]?.change ?? 0) >= 0 ? Brand.buy : Brand.sell)
          }
          Capsule().fill(Brand.buy).frame(height: 4)
        }
        .padding(8)
        .background(Brand.nightMiddle, in: .rect(cornerRadius: 12))
      }
      Spacer(minLength: 0)
    }
    .padding(14)
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.black)
  }
}

/// A small task that teaches a feature; it turns green with a check when done.
private struct MissionChip: View {
  var text: String
  var isDone: Bool

  var body: some View {
    Label(isDone ? "\(text) · +\(OnboardingModel.missionPoints) XP" : text, systemImage: isDone ? "checkmark.circle.fill" : "target")
      .font(.subheadline.weight(.bold))
      .foregroundStyle(isDone ? Brand.owlInk : Brand.amber)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(isDone ? AnyShapeStyle(Brand.buy) : AnyShapeStyle(Brand.amber.opacity(0.15)), in: .capsule)
      .animation(.bouncy, value: isDone)
      .accessibilityLabel(isDone ? "Mission complete: \(text)" : "Mission: \(text)")
  }
}

private struct SmartStep: View {
  @Bindable var model: OnboardingModel

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        MissionChip(text: "Pick a smart alert", isDone: model.completedMissions.contains("smart"))
          .padding(.top, 12)
        HStack(alignment: .top, spacing: 12) {
          LivelyOwl(hopsOnTap: false, mood: .calm)
            .frame(width: 64, height: 74)
          SpeechBubble(text: model.smartKinds.isEmpty ? "I can watch more than prices. Pick as many as you like!" : "Great picks. I'll watch \(model.focusSymbol ?? "it") for those too.")
            .animation(.snappy, value: model.smartKinds.isEmpty)
        }
        VStack(spacing: 10) {
          ForEach(OnboardingModel.suggestedSmart) { kind in
            let isOn = model.smartKinds.contains(kind)
            Button {
              withAnimation(.snappy) {
                if isOn { model.smartKinds.remove(kind) } else { model.smartKinds.insert(kind) }
              }
              model.complete("smart")
            } label: {
              HStack(spacing: 12) {
                Image(systemName: kind.systemImage)
                  .font(.headline)
                  .foregroundStyle(isOn ? Brand.owlInk : kind.side.brandColor)
                  .frame(width: 34, height: 34)
                  .background(isOn ? AnyShapeStyle(.white.opacity(0.5)) : AnyShapeStyle(kind.side.brandColor.opacity(0.2)), in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                  Text(kind.title).font(.headline)
                  Text(kind.explanation)
                    .font(.caption)
                    .opacity(0.75)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: isOn ? "checkmark.square.fill" : "square")
                  .font(.title3)
              }
              .padding(14)
              .foregroundStyle(isOn ? Brand.owlInk : .white)
              .background(isOn ? AnyShapeStyle(Brand.buy) : AnyShapeStyle(.white.opacity(0.08)), in: .rect(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isOn ? .isSelected : [])
          }
        }
        .padding(.horizontal, 20)
        .sensoryFeedback(.selection, trigger: model.smartKinds)
        Text("Smart alerts are part of Dipwise Pro. Try it free for 7 days.")
          .font(.footnote)
          .foregroundStyle(.white.opacity(0.6))
      }
    }
  }
}

private struct AccountStep: View {
  @Environment(AccountStore.self) private var account

  var body: some View {
    VStack(spacing: 24) {
      Spacer(minLength: 8)
      LivelyOwl(mood: .calm)
        .frame(width: 120, height: 138)
      StepTitle(
        title: account.isSignedIn ? "Welcome, \(account.firstName ?? "friend")!" : "Make Dipwise yours",
        message: account.isSignedIn ? "You're signed in. Dippy will greet you by name." : "Sign in with Apple for a personal greeting and the same anonymous flock identity on all your devices. It's optional, and Dippy never sees your email unless you share it."
      )
      if !account.isSignedIn {
        SignInWithAppleButton(.continue) { account.configure($0) } onCompletion: { account.handle($0) }
          .signInWithAppleButtonStyle(.white)
          .frame(height: 50)
          .padding(.horizontal, 28)
        if let error = account.errorMessage {
          Text(error)
            .font(.caption)
            .foregroundStyle(Brand.sell)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 28)
        }
      } else {
        Image(systemName: "checkmark.seal.fill")
          .font(.system(size: 54))
          .foregroundStyle(Brand.buy)
          .symbolEffect(.bounce, value: account.isSignedIn)
      }
      Spacer(minLength: 8)
    }
  }
}

private struct NotifyStep: View {
  private struct Banner: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var symbol: String
    var color: Color
  }

  private static let samples: [Banner] = [
    Banner(title: "NVDA entered your buy zone", message: "Now $177.40, inside $170–178. Your plan: about 5.6 shares.", symbol: "arrow.down.to.line.compact", color: Brand.buy),
    Banner(title: "AAPL reached your sell zone", message: "Now $256.10. Time to take some profit?", symbol: "arrow.up.to.line.compact", color: Brand.sell),
    Banner(title: "Keep your streak going", message: "Your daily brief is ready. One minute with Dippy.", symbol: "flame.fill", color: Brand.amber),
  ]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visible: [Banner] = []

  var body: some View {
    VStack(spacing: 26) {
      Spacer(minLength: 8)
      VStack(spacing: 0) {
        LivelyOwl(mood: .calm)
          .frame(width: 84, height: 96)
          .padding(.bottom, -10)
          .zIndex(1)
        lockScreen
      }
      StepTitle(title: "Never miss your moment", message: "Dippy taps you on the shoulder the moment a stock enters your zone, with your plan right in the notification.")
      Spacer(minLength: 8)
    }
    .task { await play() }
  }

  private var lockScreen: some View {
    VStack(spacing: 4) {
      Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white.opacity(0.8))
        .padding(.top, 22)
      Text("9:41")
        .font(.system(size: 64, weight: .semibold, design: .rounded))
      VStack(spacing: 8) {
        ForEach(visible) { banner in
          HStack(alignment: .top, spacing: 10) {
            Image(.appIconPreview)
              .resizable()
              .frame(width: 34, height: 34)
              .clipShape(.rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
              HStack(spacing: 5) {
                Image(systemName: banner.symbol)
                  .font(.caption.weight(.bold))
                  .foregroundStyle(banner.color)
                Text(banner.title)
                  .font(.subheadline.weight(.semibold))
                  .lineLimit(1)
                  .minimumScaleFactor(0.8)
              }
              Text(banner.message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(2)
            }
            Spacer(minLength: 0)
            Text("now")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.6))
          }
          .padding(12)
          .background(.ultraThinMaterial, in: .rect(cornerRadius: 18))
          .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .top)))
          .accessibilityElement(children: .combine)
        }
      }
      .padding(.horizontal, 12)
      .padding(.top, 14)
      Spacer(minLength: 0)
    }
    .frame(width: 300, height: 360)
    .background(Brand.nightTop, in: .rect(cornerRadius: 40))
    .overlay {
      RoundedRectangle(cornerRadius: 40).strokeBorder(.white.opacity(0.18), lineWidth: 2)
    }
    .clipShape(.rect(cornerRadius: 40))
    .sensoryFeedback(.impact(weight: .light), trigger: visible.count)
  }

  private func play() async {
    if reduceMotion {
      visible = Self.samples
      return
    }
    while !Task.isCancelled {
      for banner in Self.samples {
        try? await Task.sleep(for: .seconds(1.1))
        withAnimation(.bouncy(duration: 0.5)) { visible.insert(banner, at: 0) }
      }
      try? await Task.sleep(for: .seconds(3))
      withAnimation(.smooth) { visible = [] }
      try? await Task.sleep(for: .seconds(0.6))
    }
  }
}

private struct RevealStep: View {
  var model: OnboardingModel
  var streak: Int
  @State private var shown = false

  var body: some View {
    VStack(spacing: 22) {
      Spacer()
      LivelyOwl(mood: .calm)
        .frame(width: 130, height: 150)
        .owlFlight(trigger: shown ? 1 : 0, height: 50)
      StepTitle(title: "Your owl is ready!", message: "Here's what Dippy will watch for you.")
      VStack(spacing: 12) {
        HStack(spacing: -8) {
          ForEach(model.selected, id: \.self) { symbol in
            TickerBadge(symbol: symbol, size: 44)
              .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Brand.nightMiddle, lineWidth: 3) }
          }
        }
        if let quote = model.focusQuote {
          Label("\(model.focusSymbol ?? "") buy zone \(quote.formatted(model.zoneLower))–\(quote.formatted(model.zoneUpper))", systemImage: "arrow.down.to.line.compact")
            .font(.headline)
            .foregroundStyle(Brand.buy)
        }
        if !model.smartKinds.isEmpty {
          Label("\(model.smartKinds.count) smart \(model.smartKinds.count == 1 ? "alert" : "alerts") ready to activate", systemImage: "sparkles")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.8))
        }
        HStack(spacing: 18) {
          Label("Day \(streak) streak", systemImage: "flame.fill")
            .foregroundStyle(Brand.amber)
          Label("+\(50 + model.earnedXP) XP", systemImage: "bolt.fill")
            .foregroundStyle(Brand.amber)
        }
        .font(.headline)
        Text("\(model.completedMissions.count) of 8 missions completed")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.6))
      }
      .padding(20)
      .frame(maxWidth: .infinity)
      .background(.white.opacity(0.07), in: .rect(cornerRadius: 24))
      .padding(.horizontal, 24)
      .scaleEffect(shown ? 1 : 0.8)
      .opacity(shown ? 1 : 0)
      Spacer()
    }
    .onAppear {
      withAnimation(.bouncy(duration: 0.6).delay(0.2)) { shown = true }
    }
  }
}

private struct SpeechBubble: View {
  var text: String

  var body: some View {
    Text(text)
      .font(.headline)
      .foregroundStyle(Brand.owlInk)
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .background(.white, in: .rect(cornerRadius: 18))
      .id(text)
      .transition(.scale(scale: 0.8).combined(with: .opacity))
  }
}
