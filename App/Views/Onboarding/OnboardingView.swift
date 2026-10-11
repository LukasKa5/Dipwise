import SwiftData
import SwiftUI

/// An interactive tour that ends with the user's first stocks and buy zones being watched.
struct OnboardingView: View {
  var onFinish: () -> Void

  @Environment(\.modelContext) private var modelContext
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(QuoteStore.self) private var quoteStore
  @Environment(FlockService.self) private var flock
  @Environment(ProgressStore.self) private var progress
  @Environment(SubscriptionManager.self) private var subscription
  @State private var model = OnboardingModel()
  @State private var page = 0
  @State private var showsPaywall = false
  @State private var celebration = 0

  private let pageCount = 8

  private var canContinue: Bool {
    switch page {
    case 1: model.style != nil
    case 2: !model.selected.isEmpty
    case 5: model.vote != nil
    default: true
    }
  }

  private var buttonTitle: String {
    switch page {
    case 2: model.selected.isEmpty ? "Pick at least one" : "Watch \(model.selected.count) \(model.selected.count == 1 ? "stock" : "stocks")"
    case 5: model.vote == nil ? "Cast your vote" : "Continue"
    case 6: "Allow Notifications"
    case 7: "Start Watching"
    default: "Continue"
    }
  }

  var body: some View {
    ZStack {
      Brand.nightMiddle.ignoresSafeArea()
      StarField().ignoresSafeArea()
      VStack(spacing: 0) {
        topBar
        Group {
          switch page {
          case 0: WelcomeStep()
          case 1: StyleStep(model: model)
          case 2: PickStep(model: model)
          case 3: ScrubStep(model: model)
          case 4: ZoneStep(model: model)
          case 5: FlockStep(model: model)
          case 6: NotifyStep()
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
    }
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
    .task { await model.loadQuotes() }
    .sheet(isPresented: $showsPaywall, onDismiss: onFinish) {
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
    case 6:
      Task {
        await NotificationManager.requestAuthorization()
        withAnimation(.smooth) { page += 1 }
        celebration += 1
      }
      return
    case 7:
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
  @State private var taps = 0
  @State private var arrived = false
  private let lines = [
    "Hoo! Tap me.",
    "I'm Dipp, your stock-watching owl.",
    "I watch your stocks day and night…",
    "…and tell you when it's time to act.",
    "Let's set me up in one minute!",
  ]

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      SpeechBubble(text: lines[min(taps, lines.count - 1)])
        .animation(.snappy, value: taps)
      LivelyOwl()
        .frame(width: 180, height: 206)
        .simultaneousGesture(TapGesture().onEnded { taps += 1 })
        .offset(x: arrived ? 0 : 260, y: arrived ? 0 : -520)
        .rotationEffect(.degrees(arrived ? 0 : 30))
        .owlFlight(trigger: arrived ? 1 : 0, height: 30)
        .onAppear {
          withAnimation(.spring(duration: 1.2, bounce: 0.35)) { arrived = true }
        }
        .accessibilityLabel("Dipp the owl")
        .accessibilityAddTraits(.isButton)
      StepTitle(title: "Invest calmly. Let the owl watch.", message: "Dipwise sits between you and your broker, watching your plan so you don't have to.")
      Spacer()
    }
  }
}

private struct StyleStep: View {
  var model: OnboardingModel
  @State private var hops = 0

  var body: some View {
    VStack(spacing: 20) {
      Spacer(minLength: 8)
      HStack(alignment: .top, spacing: 12) {
        LivelyOwl(hopsOnTap: false)
          .frame(width: 70, height: 80)
          .owlFlight(trigger: hops, height: 24)
        SpeechBubble(text: model.style?.owlReply ?? "What brings you here?")
          .animation(.snappy, value: model.style)
      }
      VStack(spacing: 12) {
        ForEach(InvestorStyle.allCases) { style in
          let isSelected = model.style == style
          Button {
            withAnimation(.snappy) { model.style = style }
            hops += 1
          } label: {
            HStack(spacing: 14) {
              Image(systemName: style.systemImage)
                .font(.title3)
                .frame(width: 30)
              Text(style.title)
                .font(.headline)
              Spacer()
              Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
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
      }
      .padding(.horizontal, 24)
      .sensoryFeedback(.selection, trigger: model.style)
      Spacer(minLength: 8)
    }
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
        InteractiveChart(values: series.values, dates: series.dates, gridColor: .white.opacity(0.08), owlSize: 56, selectedIndex: $selectedIndex)
          .frame(height: 240)
          .padding(.horizontal, 20)
          .onChange(of: selectedIndex) { _, index in if index != nil { scrubs += 1 } }
      } else {
        ProgressView().tint(.white).frame(height: 240)
      }

      StepTitle(
        title: scrubs > 15 ? "You startled Dipp!" : "Glance, don't stare",
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
      LivelyOwl(hopsOnTap: false)
        .frame(width: 90, height: 104)
        .owlFlight(trigger: flights, height: 40)
      StepTitle(title: "Invest with the flock", message: model.vote == nil ? "Thousands of investors share their plans anonymously. What's your call?" : "You're part of the flock now. See where everyone buys and sells, on every stock.")
        .animation(.smooth, value: model.vote)
      VoteCard(symbol: model.focusSymbol ?? "NVDA", votes: votes, userVote: model.vote) { bullish in
        model.vote = bullish
        flights += 1
      }
      .padding(.horizontal, 20)
      Spacer()
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
    Banner(title: "Keep your streak going", message: "Your daily brief is ready. One minute with Dipp.", symbol: "flame.fill", color: Brand.amber),
  ]

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visible: [Banner] = []

  var body: some View {
    VStack(spacing: 26) {
      Spacer(minLength: 8)
      VStack(spacing: 0) {
        LivelyOwl()
          .frame(width: 84, height: 96)
          .padding(.bottom, -10)
          .zIndex(1)
        lockScreen
      }
      StepTitle(title: "Never miss your moment", message: "Dipp taps you on the shoulder the moment a stock enters your zone, with your plan right in the notification.")
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
      LivelyOwl()
        .frame(width: 130, height: 150)
        .owlFlight(trigger: shown ? 1 : 0, height: 50)
      StepTitle(title: "Your owl is ready!", message: "Here's what Dipp will watch for you.")
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
        HStack(spacing: 18) {
          Label("Day \(streak) streak", systemImage: "flame.fill")
            .foregroundStyle(Brand.amber)
          Label("+50 XP", systemImage: "sparkles")
            .foregroundStyle(Brand.amber)
        }
        .font(.headline)
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

/// Gently twinkling stars for the night sky behind onboarding.
private struct StarField: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private static let stars: [(x: Double, y: Double, size: Double, phase: Double)] = {
    var generator = SystemRandomNumberGenerator()
    return (0..<70).map { _ in
      (Double.random(in: 0...1, using: &generator), Double.random(in: 0...0.7, using: &generator),
       Double.random(in: 1...2.6, using: &generator), Double.random(in: 0...6.28, using: &generator))
    }
  }()

  var body: some View {
    TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
      Canvas { context, size in
        let t = timeline.date.timeIntervalSinceReferenceDate
        for star in Self.stars {
          let alpha = 0.25 + 0.35 * (1 + sin(t * 1.3 + star.phase)) / 2
          let rect = CGRect(x: star.x * size.width, y: star.y * size.height, width: star.size, height: star.size)
          context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
        }
      }
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}
