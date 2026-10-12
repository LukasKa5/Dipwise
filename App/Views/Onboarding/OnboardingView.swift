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

  private let pageCount = 11

  private var canContinue: Bool {
    switch page {
    case 1: !model.styles.isEmpty
    case 2: !model.selected.isEmpty
    case 5: model.vote != nil
    default: true
    }
  }

  private var buttonTitle: String {
    switch page {
    case 2: model.selected.isEmpty ? "Pick at least one" : "Watch \(model.selected.count) \(model.selected.count == 1 ? "stock" : "stocks")"
    case 5: model.vote == nil ? "Cast your vote" : "Continue"
    case 8: "Allow Notifications"
    case 9: account.isSignedIn ? "Continue" : "Continue without an account"
    case 10: "Start Watching"
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
          case 0: WelcomeStep(model: model).fitsScreen()
          case 1: StyleStep(model: model)
          case 2: PickStep(model: model)
          case 3: ScrubStep(model: model).fitsScreen()
          case 4: ZoneStep(model: model).fitsScreen()
          case 5: FlockStep(model: model)
          case 6: WidgetStep(model: model).fitsScreen()
          case 7: WatchStep(model: model).fitsScreen()
          case 8: NotifyStep().fitsScreen()
          case 9: AccountStep().fitsScreen()
          default: RevealStep(model: model, streak: max(1, progress.streak)).fitsScreen()
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
    }
    .sensoryFeedback(.success, trigger: model.missionCelebration)
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
    .task { await model.loadQuotes() }
    .sheet(isPresented: $showsPaywall, onDismiss: {
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
      .frame(height: 6)
      .animation(.snappy, value: page)
      .accessibilityElement()
      .accessibilityLabel("Step \(page + 1) of \(pageCount)")
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
    case 9:
      if !account.isSignedIn { account.continueAsGuest() }
    case 8:
      Task {
        await NotificationManager.requestAuthorization()
        withAnimation(.smooth) { page += 1 }
        celebration += 1
      }
      return
    case 10:
      let created = model.commit(context: modelContext, quoteStore: quoteStore, isPro: subscription.isPro)
      for alert in created {
        Task { await flock.share(alert) }
      }
      progress.record(.onboarding)
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

extension View {
  /// Centers a step on screen, and lets it scroll only when it's taller than the screen, like on iPhone SE.
  fileprivate func fitsScreen() -> some View {
    modifier(FitsScreen())
  }
}

private struct FitsScreen: ViewModifier {
  @State private var contentHeight: CGFloat = 0
  @State private var containerHeight: CGFloat = 0

  func body(content: Content) -> some View {
    ScrollView {
      content
        .frame(maxWidth: .infinity)
        .frame(minHeight: containerHeight)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
    }
    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
    // Charts and zone handles need vertical drags, so only scroll when there's no other way.
    .scrollDisabled(contentHeight <= containerHeight + 1)
    .scrollBounceBehavior(.basedOnSize)
    .scrollIndicators(.hidden)
    // Dippy flies in from off screen, so don't cut him off at the edges.
    .scrollClipDisabled()
  }
}

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
      VStack(spacing: 18) {
        VStack(spacing: 10) {
          LivelyOwl(hopsOnTap: false, mood: .calm)
            .frame(width: 74, height: 86)
            .owlFlight(trigger: hops, height: 18)
          SpeechBubble(text: model.lastStyle?.owlReply ?? "What brings you here?")
            .animation(.snappy, value: model.lastStyle)
          Text("Choose all that apply")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 16)

        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
          ForEach(InvestorStyle.allCases) { style in
            let isSelected = model.styles.contains(style)
            Button {
              withAnimation(.snappy) { model.toggle(style: style) }
              if !isSelected { hops += 1 }
            } label: {
              VStack(alignment: .leading, spacing: 10) {
                HStack {
                  Image(systemName: style.systemImage)
                    .font(.title3)
                  Spacer()
                  Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.headline)
                    .opacity(isSelected ? 1 : 0.5)
                }
                Text(style.title)
                  .font(.subheadline.weight(.semibold))
                  .multilineTextAlignment(.leading)
                  .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
              }
              .padding(14)
              .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
              .foregroundStyle(isSelected ? Brand.owlInk : .white)
              .background(isSelected ? AnyShapeStyle(Brand.buy) : AnyShapeStyle(.white.opacity(0.08)), in: .rect(cornerRadius: 18))
              .overlay {
                RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(isSelected ? 0 : 0.12))
              }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
          }
        }

        if model.styles.contains(.other) {
          TextField("What should Dippy help you with?", text: $model.otherGoal, axis: .vertical)
            .lineLimit(1...3)
            .padding(16)
            .background(.white.opacity(0.1), in: .rect(cornerRadius: 16))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 12)
      .sensoryFeedback(.selection, trigger: model.styles)
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
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
        } else {
          Text("\(model.focusSymbol ?? "") · slide your finger along the chart")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
          Text(quote.map { $0.formatted($0.price) } ?? "")
            .lineLimit(1)
            .minimumScaleFactor(0.7)
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
    ScrollView {
      VStack(spacing: 20) {
        HStack(spacing: -14) {
          ForEach(0..<3) { index in
            LivelyOwl(hopsOnTap: false, mood: .calm)
              .frame(width: index == 1 ? 74 : 54, height: index == 1 ? 86 : 62)
              .owlFlight(trigger: flights, height: index == 1 ? 34 : 22)
              .zIndex(index == 1 ? 1 : 0)
          }
        }
        .padding(.top, 12)
        StepTitle(title: "Meet the flock", message: "The flock is every Dipwise investor. Each alert they set is shared anonymously, and Dippy combines them to show where the crowd plans to buy and sell.")

        if let quote = model.focusQuote {
          VStack(alignment: .leading, spacing: 10) {
            Text("\(model.focusSymbol ?? "") · what the crowd plans")
              .font(.subheadline.weight(.semibold))
            ZoneTrack(
              price: quote.price,
              bands: [
                ZoneTrack.Band(range: (quote.price * 0.86)...(quote.price * 0.93), side: .buy, isCrowd: true),
                ZoneTrack.Band(range: (quote.price * 1.12)...(quote.price * 1.2), side: .sell, isCrowd: true),
                ZoneTrack.Band(range: model.zoneLower...max(model.zoneLower, model.zoneUpper), side: .buy, isCrowd: false),
              ],
              low: nil,
              high: nil,
              format: { quote.formatted($0) }
            )
            ZoneLegend()
          }
          .padding(16)
          .background(.white.opacity(0.07), in: .rect(cornerRadius: 20))
          .padding(.horizontal, 20)
        }

        MissionChip(text: "Vote with the flock", isDone: model.completedMissions.contains("flock"))
        VoteCard(symbol: model.focusSymbol ?? "NVDA", votes: votes, userVote: model.vote) { bullish in
          model.vote = bullish
          flights += 1
          model.complete("flock")
        }
        .padding(.horizontal, 20)
        Text("Your own alerts stay private. Only the price levels are shared, never your name or holdings.")
          .font(.caption)
          .foregroundStyle(.white.opacity(0.55))
          .multilineTextAlignment(.center)
          .padding(.horizontal, 32)
      }
      .padding(.bottom, 12)
    }
  }
}

private struct WidgetStep: View {
  var model: OnboardingModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var index = 0
  @State private var showsZones = false
  @State private var width: CGFloat = 0

  /// Real iPhone widget metrics, so the preview matches the Home Screen exactly.
  private enum Metrics {
    static let small: CGFloat = 158
    static let gap: CGFloat = 22
    static let medium = small * 2 + gap
    static let margin: CGFloat = 16
    static let radius: CGFloat = 22
    static let wallpaperPadding: CGFloat = 18
    static let total = medium + wallpaperPadding * 2
  }

  private var statuses: [TargetStatus] { model.sampleStatuses }
  private var focus: String? { model.focusSymbol ?? model.previewSymbols.first }

  /// Scales the full-size Home Screen to the width available, never larger than life.
  private var scale: CGFloat {
    guard width > 0 else { return 0.85 }
    return min(1, (width - 40) / Metrics.total)
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer(minLength: 8)
      homeScreen
        .scaleEffect(scale)
        .frame(width: Metrics.total * scale, height: Metrics.total * scale)
      MissionChip(text: "Tap a widget", isDone: model.completedMissions.contains("widget"))
      StepTitle(title: "Dippy on your Home Screen", message: "Your plans at a glance, without opening the app. Tap the widgets to flip through plans and switch to zones.")
      Spacer(minLength: 8)
    }
    .frame(maxWidth: .infinity)
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    .sensoryFeedback(.selection, trigger: index)
    .sensoryFeedback(.selection, trigger: showsZones)
    .task {
      // A gentle hint: the plans widget flips on its own until the user tries it.
      guard !reduceMotion else { return }
      while !Task.isCancelled && !model.completedMissions.contains("widget") {
        try? await Task.sleep(for: .seconds(2.6))
        guard !model.completedMissions.contains("widget") else { break }
        withAnimation(.smooth) { index += 1 }
      }
    }
  }

  private var homeScreen: some View {
    VStack(spacing: Metrics.gap) {
      HStack(spacing: Metrics.gap) {
        widget(width: Metrics.small, label: "Plans widget. Tap to see the next plan.") {
          PlansWidgetView(entry: PlansEntry(date: .now, statuses: statuses, index: index), previewFamily: .systemSmall)
        } action: {
          withAnimation(.smooth) { index += 1 }
          model.complete("widget")
        }
        widget(width: Metrics.small, label: "Streak widget") {
          StreakWidgetView(entry: StreakEntry(date: .now, progress: ProgressSnapshot(
            streak: 1, lastBrief: Calendar.current.date(byAdding: .day, value: -1, to: .now), level: 1, levelTitle: "Owlet")))
        } action: {}
      }
      widget(width: Metrics.medium, label: "Stock plan widget. Tap to switch between chart and zones.") {
        StockPlanWidgetView(
          entry: StockPlanEntry(date: .now, symbol: focus, quote: focus.flatMap { model.quotes[$0] },
                                targets: statuses.map(\.target).filter { $0.symbol == focus }),
          previewFamily: .systemMedium,
          previewShowsZones: showsZones
        )
        .id(showsZones)
        .transition(.opacity.combined(with: .scale(scale: 0.97)))
      } action: {
        withAnimation(.smooth) { showsZones.toggle() }
        model.complete("widget")
      }
    }
    .padding(Metrics.wallpaperPadding)
    .frame(width: Metrics.total, height: Metrics.total)
    .background {
      RoundedRectangle(cornerRadius: 44)
        .fill(LinearGradient(
          colors: [Color(red: 0.36, green: 0.42, blue: 0.86), Color(red: 0.55, green: 0.33, blue: 0.78), Color(red: 0.93, green: 0.55, blue: 0.45)],
          startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay { RoundedRectangle(cornerRadius: 44).strokeBorder(.white.opacity(0.18), lineWidth: 1.5) }
    }
  }

  private func widget<Content: View>(width: CGFloat, label: String, @ViewBuilder content: () -> Content, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      content()
        .padding(Metrics.margin)
        .frame(width: width, height: Metrics.small)
        .background(Brand.nightMiddle, in: .rect(cornerRadius: Metrics.radius))
        .clipShape(.rect(cornerRadius: Metrics.radius))
        // The widgets' own buttons and links stay inert; the whole widget is one tap target.
        .allowsHitTesting(false)
        .overlay { Color.clear.contentShape(.rect(cornerRadius: Metrics.radius)) }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
    .buttonStyle(WidgetPressStyle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(label)
  }
}

/// Widgets shrink slightly while pressed, like on the Home Screen.
private struct WidgetPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.snappy(duration: 0.2), value: configuration.isPressed)
  }
}

private struct WatchStep: View {
  var model: OnboardingModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var page = 0
  @State private var notification = false

  private var symbol: String { model.focusSymbol ?? "NVDA" }
  private var statuses: [TargetStatus] { Array(model.sampleStatuses.prefix(3)) }

  var body: some View {
    VStack(spacing: 26) {
      Spacer(minLength: 8)
      watch
        .onTapGesture {
          withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.45)) { page = (page + 1) % 2 }
          model.complete("watch")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(page == 0 ? "Apple Watch face with your nearest plan" : "Apple Watch plans list")
        .accessibilityHint("Tap to switch screens.")
        .accessibilityAddTraits(.isButton)
      MissionChip(text: "Tap the watch", isDone: model.completedMissions.contains("watch"))
      StepTitle(title: "On your wrist", message: "A gentle tap when a stock reaches your zone, your nearest plan on the watch face, and every plan a glance away.")
      Spacer(minLength: 8)
    }
    .sensoryFeedback(.impact(weight: .medium), trigger: notification)
    .sensoryFeedback(.selection, trigger: page)
    .task {
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2.5))
        withAnimation(.bouncy) { notification = true }
        try? await Task.sleep(for: .seconds(2.4))
        withAnimation(.smooth) { notification = false }
        try? await Task.sleep(for: .seconds(1.8))
      }
    }
  }

  /// An Apple Watch drawn to scale: case, Digital Crown, side button, and a screen that clips its content.
  private var watch: some View {
    ZStack {
      // Band
      VStack(spacing: 0) {
        UnevenRoundedRectangle(topLeadingRadius: 18, topTrailingRadius: 18)
          .fill(LinearGradient(colors: [Color(white: 0.16), Color(white: 0.22)], startPoint: .top, endPoint: .bottom))
          .frame(width: 150, height: 60)
        Spacer()
        UnevenRoundedRectangle(bottomLeadingRadius: 18, bottomTrailingRadius: 18)
          .fill(LinearGradient(colors: [Color(white: 0.22), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
          .frame(width: 150, height: 60)
      }
      .frame(height: 360)

      // Case
      RoundedRectangle(cornerRadius: 56, style: .continuous)
        .fill(LinearGradient(colors: [Color(white: 0.42), Color(white: 0.2), Color(white: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .frame(width: 214, height: 256)
        .shadow(color: .black.opacity(0.45), radius: 20, y: 10)

      // Digital Crown and side button
      RoundedRectangle(cornerRadius: 4)
        .fill(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.3)], startPoint: .top, endPoint: .bottom))
        .frame(width: 10, height: 38)
        .overlay { RoundedRectangle(cornerRadius: 3).fill(Brand.amber).frame(width: 4, height: 30).offset(x: 3) }
        .offset(x: 110, y: -48)
      Capsule()
        .fill(Color(white: 0.35))
        .frame(width: 6, height: 48)
        .offset(x: 108, y: 30)

      // Screen
      ZStack {
        Color.black
        Group {
          if page == 0 { face } else { plans }
        }
        .transition(.asymmetric(
          insertion: .scale(scale: 0.86).combined(with: .opacity),
          removal: .scale(scale: 1.12).combined(with: .opacity)
        ))
        if notification {
          notificationCard
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
      .frame(width: 192, height: 234)
      .clipShape(.rect(cornerRadius: 44, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 44, style: .continuous).strokeBorder(.black, lineWidth: 4)
      }
    }
    .frame(width: 240, height: 360)
    .compositingGroup()
  }

  private var notificationCard: some View {
    VStack(spacing: 6) {
      Image(.appIconPreview).resizable().frame(width: 32, height: 32).clipShape(.circle)
      Text("\(symbol) entered your buy zone")
        .font(.system(size: 14, weight: .semibold))
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
      Text("Your plan: buy a little")
        .font(.system(size: 12))
        .foregroundStyle(.white.opacity(0.65))
    }
    .padding(12)
    .frame(maxWidth: .infinity)
    .background(Color(white: 0.17), in: .rect(cornerRadius: 22, style: .continuous))
    .padding(10)
    .frame(maxHeight: .infinity, alignment: .bottom)
  }

  private var face: some View {
    let nearest = statuses.first
    return VStack(spacing: 10) {
      Text(Date.now, format: .dateTime.weekday(.abbreviated).day())
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(Brand.amber)
        .textCase(.uppercase)
      Text("10:09")
        .font(.system(size: 46, weight: .semibold, design: .rounded))
        .monospacedDigit()
      HStack(spacing: 12) {
        ZStack {
          Circle().stroke(.white.opacity(0.2), lineWidth: 5)
          Circle()
            .trim(from: 0, to: nearest?.progress ?? 0.78)
            .stroke(nearest?.target.rule.kind.side.brandColor ?? Brand.buy, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            .rotationEffect(.degrees(-90))
          Text(symbol.prefix(4))
            .font(.system(size: 11, weight: .bold))
            .minimumScaleFactor(0.6)
            .padding(6)
        }
        .frame(width: 50, height: 50)
        ZStack {
          Circle().fill(.white.opacity(0.1))
          VStack(spacing: 0) {
            Image(systemName: "flame.fill").foregroundStyle(Brand.amber)
            Text("1").font(.system(size: 12, weight: .bold))
          }
        }
        .frame(width: 50, height: 50)
      }
      HStack(spacing: 6) {
        OwlMark().frame(width: 20)
        VStack(alignment: .leading, spacing: 1) {
          Text("\(nearest?.target.symbol ?? symbol) · \(distanceText(nearest?.distance))")
            .font(.system(size: 12, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
          Text(nearest?.target.rule.kind.side == .sell ? "to sell zone" : "to buy zone")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.6))
        }
      }
    }
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var plans: some View {
    VStack(alignment: .leading, spacing: 7) {
      Text("Plans")
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(Brand.buy)
        .padding(.leading, 4)
      ForEach(statuses) { status in
        let color = status.target.rule.kind.side.brandColor
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            Text(status.target.symbol)
              .font(.system(size: 13, weight: .bold))
              .lineLimit(1)
            Spacer(minLength: 4)
            Text(distanceText(status.distance))
              .font(.system(size: 12, weight: .semibold).monospacedDigit())
              .foregroundStyle(color)
              .lineLimit(1)
          }
          WidgetTrack(progress: status.progress, color: color)
        }
        .padding(9)
        .background(Color(white: 0.14), in: .rect(cornerRadius: 14, style: .continuous))
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.top, 18)
    .foregroundStyle(.white)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// A gentle hint that teaches a feature by doing it; it turns green with a check when done.
private struct MissionChip: View {
  var text: String
  var isDone: Bool

  var body: some View {
    Label(isDone ? "Nice! \(text)" : "Try it: \(text)", systemImage: isDone ? "checkmark.circle.fill" : "hand.tap.fill")
      .font(.subheadline.weight(.bold))
      .foregroundStyle(isDone ? Brand.owlInk : Brand.amber)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(isDone ? AnyShapeStyle(Brand.buy) : AnyShapeStyle(Brand.amber.opacity(0.15)), in: .capsule)
      .animation(.bouncy, value: isDone)
      .accessibilityLabel(isDone ? "Done: \(text)" : "Try it: \(text)")
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
        Label("Your streak starts today", systemImage: "flame.fill")
          .font(.headline)
          .foregroundStyle(Brand.amber)
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
