import SwiftData
import SwiftUI
import WidgetKit

/// An interactive tour that ends with the user's first stocks and buy zones being watched.
struct OnboardingView: View {
  var onFinish: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.horizontalSizeClass) private var sizeClass
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  @Environment(QuoteStore.self) private var quoteStore
  @Environment(FlockService.self) private var flock
  @Environment(ProgressStore.self) private var progress
  @Environment(SubscriptionManager.self) private var subscription
  @State private var model = OnboardingModel()
  @State private var page = Self.startPage
  @State private var showsPaywall = false
  @State private var celebration = 0

  private let pageCount = 10

  private var isRegular: Bool { sizeClass == .regular }

  /// Development only: `-onboardingPage 4` opens the tour at that step, for checking layouts on every device.
  private static var startPage: Int {
    #if DEBUG
    let arguments = ProcessInfo.processInfo.arguments
    if let index = arguments.firstIndex(of: "-onboardingPage"), arguments.indices.contains(index + 1), let page = Int(arguments[index + 1]) {
      return page
    }
    #endif
    return 0
  }

  private var canContinue: Bool {
    switch page {
    case 1: !model.styles.isEmpty
    case 2: !model.selected.isEmpty
    case 5: model.vote != nil
    default: true
    }
  }

  private var buttonTitle: LocalizedStringKey {
    switch page {
    case 2: model.selected.isEmpty ? "Pick at least one" : (model.selected.count == 1 ? "Watch 1 stock" : "Watch \(model.selected.count) stocks")
    case 5: model.vote == nil ? "Cast your vote" : "Continue"
    case 8: "Allow Notifications"
    case 9: "Start Watching"
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
          case 6: WidgetShowcaseStep(model: model).fitsScreen()
          case 7: WatchShowcaseStep(model: model).fitsScreen()
          case 8: NotifyStep(model: model).fitsScreen()
          default: RevealStep(model: model, streak: max(1, progress.streak)).fitsScreen()
          }
        }
        .id(page)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        .frame(maxWidth: isRegular ? 680 : 560, maxHeight: .infinity)
        // iPad has room to spare, so the whole tour reads a size larger there.
        .dynamicTypeSize(isRegular ? max(dynamicTypeSize, .xxLarge) : dynamicTypeSize)

        PageDots(count: pageCount, page: page)
          .padding(.bottom, 14)
        Button(action: advance) {
          Text(buttonTitle)
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(Brand.buy)
        .disabled(!canContinue)
        .phaseAnimator([1.0, 1.06, 1.0], trigger: model.missionCelebration) { view, scale in
          view.scaleEffect(scale)
        } animation: { _ in .spring(duration: 0.3, bounce: 0.5) }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
        .frame(maxWidth: 520)
        .sensoryFeedback(.impact(weight: .light), trigger: page)
      }
      Confetti(trigger: celebration)
    }
    .sensoryFeedback(.success, trigger: model.missionCelebration)
    .onChange(of: model.missionCelebration) { OwlCue.shared.play(.dance) }
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
        withAnimation(.smooth) { page -= (page == 6 && !flock.isAvailable) ? 2 : 1 }
      }
      .labelStyle(.iconOnly)
      .font(.title3.weight(.semibold))
      .opacity(page > 0 && page < pageCount - 1 ? 1 : 0)
      .disabled(page == 0 || page == pageCount - 1)
      .accessibilityHidden(page == 0 || page == pageCount - 1)
      Spacer()
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
    case 8:
      Task {
        await NotificationManager.requestAuthorization()
        withAnimation(.smooth) { page += 1 }
        celebration += 1
      }
      return
    case 9:
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
    // The Flock step is skipped until the Flock is live.
    withAnimation(reduceMotion ? .easeInOut : .smooth) { page += (page == 4 && !flock.isAvailable) ? 2 : 1 }
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

struct StepTitle: View {
  var title: LocalizedStringKey
  var message: LocalizedStringKey?

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
  private let lines: [LocalizedStringKey] = [
    "Hoo! Tap me four times.",
    "That tickles! Keep going…",
    "I'm Dippy, your stock-watching owl.",
    "I watch your stocks day and night…",
    "…and tell you when it's time to act.",
    "Let's set me up in one minute!",
  ]

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      MissionChip(text: "Tap Dippy 4 times", isDone: model.completedMissions.contains("welcome"))
      SpeechBubble(text: lines[min(taps, lines.count - 1)])
        .animation(.snappy, value: taps)
      LivelyOwl(mood: .calm, greeting: .wave, greetingDelay: 1.5)
        .frame(width: 180, height: 206)
        .simultaneousGesture(TapGesture().onEnded {
          taps += 1
          if taps >= 4 { model.complete("welcome") }
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
          SpeechBubble(text: model.lastStyle.map { LocalizedStringKey($0.owlReply) } ?? "What brings you here?")
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
  /// Tiles widen with the text size, so tickers and moves never get cut off.
  @ScaledMetric(relativeTo: .headline) private var tileWidth: CGFloat = 150

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        StepTitle(title: "Pick stocks to watch", message: "Choose up to five. You can add any stock later.")
          .padding(.top, 16)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: tileWidth), spacing: 12)], spacing: 12) {
          ForEach(OnboardingModel.suggestions, id: \.self) { symbol in
            let isSelected = model.selected.contains(symbol)
            let quote = model.quotes[symbol]
            Button {
              withAnimation(.bouncy) { model.toggle(symbol) }
            } label: {
              HStack(spacing: 10) {
                TickerBadge(symbol: symbol, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                  Text(symbol)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                  if let quote {
                    Text(quote.change, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
                      .font(.caption.weight(.semibold).monospacedDigit())
                      .lineLimit(1)
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

/// A gentle hint that teaches a feature by doing it; it turns green with a check when done.
struct MissionChip: View {
  var text: LocalizedStringKey
  var isDone: Bool

  var body: some View {
    Label {
      Text(isDone ? "Nice! \(Text(text))" : "Try it: \(Text(text))")
    } icon: {
      Image(systemName: isDone ? "checkmark.circle.fill" : "hand.tap.fill")
    }
      .font(.subheadline.weight(.bold))
      .foregroundStyle(isDone ? Brand.owlInk : Brand.amber)
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(isDone ? AnyShapeStyle(Brand.buy) : AnyShapeStyle(Brand.amber.opacity(0.15)), in: .capsule)
      .animation(.bouncy, value: isDone)
      .accessibilityLabel(isDone ? Text("Done: \(Text(text))") : Text("Try it: \(Text(text))"))
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
  var text: LocalizedStringKey

  var body: some View {
    Text(text)
      .font(.headline)
      .foregroundStyle(Brand.owlInk)
      .padding(.horizontal, 18)
      .padding(.vertical, 12)
      .background(.white, in: .rect(cornerRadius: 18))
      .id("\(text)")
      .transition(.scale(scale: 0.8).combined(with: .opacity))
  }
}

/// Where you are in the tour: a row of small dots, the current one a wider mint capsule.
private struct PageDots: View {
  var count: Int
  var page: Int

  var body: some View {
    HStack(spacing: 6) {
      ForEach(0..<count, id: \.self) { index in
        Capsule()
          .fill(index == page ? AnyShapeStyle(Brand.mint) : AnyShapeStyle(.white.opacity(index < page ? 0.45 : 0.18)))
          .frame(width: index == page ? 22 : 7, height: 7)
      }
    }
    .animation(.spring(duration: 0.45, bounce: 0.3), value: page)
    .accessibilityElement()
    .accessibilityLabel("Step \(page + 1) of \(count)")
  }
}
