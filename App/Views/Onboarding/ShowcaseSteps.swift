import SwiftUI
import WidgetKit

// Three chapters of the intro — Home Screen, wrist, and alerts — built on one template:
// a single hero on the app's navy surface, one headline, one thing to try, and the same rise-in motion.

/// The shared layout of every showcase chapter.
struct ShowcaseLayout<Hero: View>: View {
  var eyebrow: String
  var title: String
  var message: String
  var mission: String
  var isMissionDone: Bool
  @ViewBuilder var hero: Hero

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var isShown = false

  var body: some View {
    VStack(spacing: 22) {
      Spacer(minLength: 8)
      hero
        .scaleEffect(isShown || reduceMotion ? 1 : 0.92)
        .offset(y: isShown || reduceMotion ? 0 : 30)
        .opacity(isShown || reduceMotion ? 1 : 0)
      MissionChip(text: mission, isDone: isMissionDone)
      VStack(spacing: 8) {
        Text(eyebrow)
          .font(.caption.weight(.heavy))
          .foregroundStyle(Brand.buy)
          .textCase(.uppercase)
          .tracking(1.2)
        StepTitle(title: title, message: message)
      }
      Spacer(minLength: 8)
    }
    .onAppear {
      withAnimation(.spring(duration: 0.9, bounce: 0.25).delay(0.1)) { isShown = true }
    }
  }
}

/// The app's navy card, lifted off the page with a hairline edge.
private struct ShowcaseSurface: ViewModifier {
  var cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content
      .background(Brand.nightMiddle, in: .rect(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(.white.opacity(0.16), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.4), radius: 22, y: 12)
  }
}

extension View {
  fileprivate func showcaseSurface(cornerRadius: CGFloat) -> some View {
    modifier(ShowcaseSurface(cornerRadius: cornerRadius))
  }
}

/// Ticks every few seconds so previews change the way the real widgets do through the day, just faster.
private struct LivingClock {
  static func tick(_ step: Int) -> Date { Date.now.addingTimeInterval(Double(step) * 300) }
}

// MARK: - Home Screen

/// The real widgets, alive: plans page by themselves, Dippy changes pose, and taps get a reaction.
struct WidgetShowcaseStep: View {
  var model: OnboardingModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var step = 0
  @State private var width: CGFloat = 0

  private enum Metrics {
    static let small: CGFloat = 158
    static let gap: CGFloat = 18
    static let medium = small * 2 + gap
    static let height = small * 2 + gap
  }

  private var scale: CGFloat {
    guard width > 0 else { return 0.85 }
    return min(1, (width - 48) / Metrics.medium)
  }

  private var focus: String? { model.focusSymbol ?? model.previewSymbols.first }

  var body: some View {
    ShowcaseLayout(
      eyebrow: "Home Screen",
      title: "Your plans, always in sight",
      message: "Widgets that live on your Home Screen. Plans turn the page, Dippy looks around, and one tap says hello.",
      mission: "Tap a widget",
      isMissionDone: model.completedMissions.contains("widget")
    ) {
      grid
        .scaleEffect(scale)
        .frame(width: Metrics.medium * scale, height: Metrics.height * scale)
    }
    .frame(maxWidth: .infinity)
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    .sensoryFeedback(.selection, trigger: step)
    .task {
      guard !reduceMotion else { return }
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(2.6))
        withAnimation(.smooth(duration: 0.6)) { step += 1 }
      }
    }
  }

  private var grid: some View {
    VStack(spacing: Metrics.gap) {
      widget(width: Metrics.medium) {
        PlansWidgetView(entry: PlansEntry(date: LivingClock.tick(step), statuses: model.sampleStatuses, index: step), previewFamily: .systemMedium)
      }
      HStack(spacing: Metrics.gap) {
        widget(width: Metrics.small) {
          StockPlanWidgetView(
            entry: StockPlanEntry(date: LivingClock.tick(step), symbol: focus, quote: focus.flatMap { model.quotes[$0] },
                                  targets: model.sampleStatuses.map(\.target).filter { $0.symbol == focus }),
            previewFamily: .systemSmall
          )
        }
        widget(width: Metrics.small) {
          StreakWidgetView(entry: StreakEntry(date: LivingClock.tick(step), progress: ProgressSnapshot(
            streak: 1, lastBrief: Calendar.current.date(byAdding: .day, value: -1, to: .now), level: 1, levelTitle: "Owlet")), isPreview: true)
        }
      }
    }
  }

  private func widget<Content: View>(width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
    Button {
      withAnimation(.smooth(duration: 0.5)) { step += 1 }
      model.complete("widget")
    } label: {
      content()
        .padding(16)
        .frame(width: width, height: Metrics.small)
        .clipShape(.rect(cornerRadius: 22, style: .continuous))
        .allowsHitTesting(false)
        .showcaseSurface(cornerRadius: 22)
        .contentShape(.rect(cornerRadius: 22))
    }
    .buttonStyle(ShowcasePressStyle())
    .accessibilityLabel("Dipwise widget. Tap to see it update.")
  }
}

/// Shrinks a little while pressed, like a Home Screen widget.
private struct ShowcasePressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.snappy(duration: 0.2), value: configuration.isPressed)
  }
}

// MARK: - Wrist

/// The real Apple Watch Today screen, scrolling gently as if the Digital Crown were turning.
struct WatchShowcaseStep: View {
  var model: OnboardingModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var scroll: CGFloat = 0
  @State private var hops = 0

  private static let screen = CGSize(width: 198, height: 242)

  private var movers: [Quote] { MoversProvider.sorted(model.previewSymbols.compactMap { model.quotes[$0] }) }

  var body: some View {
    ShowcaseLayout(
      eyebrow: "Apple Watch",
      title: "A glance is enough",
      message: "Your portfolio, closest plans, and today's movers on your wrist, with a gentle tap when a stock reaches your zone.",
      mission: "Tap Dippy on the watch",
      isMissionDone: model.completedMissions.contains("watch")
    ) {
      watch
    }
    .task {
      // Scrolls down through the screen and back, like turning the Crown.
      guard !reduceMotion else { return }
      try? await Task.sleep(for: .seconds(1.6))
      while !Task.isCancelled {
        withAnimation(.smooth(duration: 2.2)) { scroll = -150 }
        try? await Task.sleep(for: .seconds(3.4))
        withAnimation(.smooth(duration: 1.8)) { scroll = 0 }
        try? await Task.sleep(for: .seconds(3.2))
      }
    }
  }

  private var watch: some View {
    VStack(alignment: .leading, spacing: 8) {
      WatchDippyHeader(greeting: WatchGreeting.text(), message: "All quiet. I'm watching your zones.", isAsleep: false, hops: hops)
        .contentShape(.rect)
        .onTapGesture {
          hops += 1
          model.complete("watch")
        }
      ForEach(model.sampleStatuses.prefix(2)) { status in
        WatchPlanCard(status: status)
      }
      WatchSectionTitle(title: "Today's movers")
      ForEach(movers.prefix(2), id: \.symbol) { quote in
        WatchMoverRow(quote: quote)
      }
    }
    .padding(.horizontal, 10)
    .padding(.top, 34)
    .offset(y: scroll)
    .frame(width: Self.screen.width, height: Self.screen.height, alignment: .top)
    .overlay(alignment: .top) {
      // The watch's title bar stays put while the content scrolls beneath it.
      HStack {
        Text("Dipwise")
          .foregroundStyle(Brand.buy)
        Spacer()
        Text(Date.now, format: .dateTime.hour().minute())
      }
      .font(.system(size: 14, weight: .semibold, design: .rounded))
      .padding(.horizontal, 18)
      .padding(.top, 10)
      .padding(.bottom, 6)
      .background(Brand.nightMiddle)
    }
    .foregroundStyle(.white)
    .clipShape(.rect(cornerRadius: 48, style: .continuous))
    .showcaseSurface(cornerRadius: 48)
    .overlay(alignment: .trailing) {
      // The Digital Crown and side button, in the same quiet style as the screen's edge.
      VStack(spacing: 16) {
        Capsule().fill(.white.opacity(0.3)).frame(width: 6, height: 34)
        Capsule().fill(.white.opacity(0.16)).frame(width: 5, height: 44)
      }
      .offset(x: 9, y: -14)
    }
    .sensoryFeedback(.impact(weight: .light), trigger: hops)
    .accessibilityElement(children: .contain)
  }
}

// MARK: - Alerts

/// The wow moment: drag your own stock into your buy zone and the alert arrives, just as it will for real.
struct AlertShowcaseStep: View {
  var model: OnboardingModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var price: Double?
  @State private var hasEntered = false
  @State private var celebrations = 0
  @State private var hintOffset: CGFloat = 0

  private var symbol: String { model.focusSymbol ?? "NVDA" }
  private var quote: Quote? { model.focusQuote }
  private var lower: Double { model.zoneLower }
  private var upper: Double { model.zoneUpper }

  private var range: ClosedRange<Double> {
    guard let quote, lower > 0 else { return 0...1 }
    return (lower * 0.97)...max(quote.price * 1.03, upper * 1.05)
  }

  private var currentPrice: Double { price ?? quote?.price ?? 0 }
  private var isInZone: Bool { upper > 0 && currentPrice <= upper && currentPrice >= lower * 0.9 }

  var body: some View {
    ShowcaseLayout(
      eyebrow: "Alerts",
      title: "Never miss your moment",
      message: "Drag \(symbol) into your buy zone. Dippy taps you the second it gets there, with your plan right in the alert.",
      mission: hasEntered ? "Dippy caught the dip" : "Drag into the green zone",
      isMissionDone: hasEntered
    ) {
      VStack(spacing: 14) {
        LivelyOwl(mood: hasEntered ? .celebrating : .calm)
          .frame(width: 76, height: 88)
          .owlFlight(trigger: celebrations, height: 40, isEnabled: !reduceMotion)
        banner
          .frame(height: 76)
        priceControl
      }
      .padding(.horizontal, 24)
    }
    .overlay { Confetti(trigger: celebrations).allowsHitTesting(false) }
    .sensoryFeedback(.success, trigger: hasEntered) { _, new in new }
    .onChange(of: isInZone) { _, inZone in
      guard inZone, !hasEntered else { return }
      withAnimation(.bouncy(duration: 0.6)) { hasEntered = true }
      celebrations += 1
      model.complete("alert")
    }
    .task {
      // A gentle nudge on the slider until the user tries it.
      guard !reduceMotion else { return }
      try? await Task.sleep(for: .seconds(1.4))
      while !Task.isCancelled && price == nil {
        withAnimation(.smooth(duration: 0.5)) { hintOffset = -14 }
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.bouncy(duration: 0.6)) { hintOffset = 0 }
        try? await Task.sleep(for: .seconds(2.4))
      }
    }
  }

  @ViewBuilder
  private var banner: some View {
    if hasEntered, let quote {
      HStack(alignment: .top, spacing: 10) {
        Image(.appIconPreview)
          .resizable()
          .frame(width: 38, height: 38)
          .clipShape(.rect(cornerRadius: 9, style: .continuous))
        VStack(alignment: .leading, spacing: 2) {
          HStack(spacing: 5) {
            Text("\(symbol) entered your buy zone")
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
              .minimumScaleFactor(0.75)
            Spacer(minLength: 4)
            Text("now")
              .font(.caption2)
              .foregroundStyle(.white.opacity(0.55))
          }
          Text("Now \(quote.formatted(currentPrice)). Your buy zone: \(quote.formatted(lower))–\(quote.formatted(upper)). Time to buy a little.")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.8))
            .lineLimit(2)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .showcaseSurface(cornerRadius: 20)
      .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .top)))
      .accessibilityElement(children: .combine)
    } else {
      HStack(spacing: 10) {
        Image(systemName: "bell.badge")
          .font(.title3)
          .foregroundStyle(.white.opacity(0.5))
        Text("Dippy is waiting for \(symbol) to reach your zone…")
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.75))
        Spacer(minLength: 0)
      }
      .padding(12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
      }
      .transition(.opacity)
    }
  }

  private var priceControl: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Text(symbol)
          .font(.headline)
        Spacer()
        Text(quote?.formatted(currentPrice) ?? "")
          .font(.system(.title2, design: .rounded).weight(.bold))
          .monospacedDigit()
          .foregroundStyle(isInZone ? Brand.buy : .white)
          .contentTransition(.numericText())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
      }
      ZStack {
        GeometryReader { geometry in
          let span = max(range.upperBound - range.lowerBound, 0.0001)
          let start = CGFloat((lower - range.lowerBound) / span) * geometry.size.width
          let end = CGFloat((upper - range.lowerBound) / span) * geometry.size.width
          Capsule()
            .fill(Brand.buy.opacity(0.3))
            .frame(width: max(8, end - start), height: 28)
            .offset(x: start)
            .frame(maxHeight: .infinity)
        }
        .allowsHitTesting(false)
        Slider(value: Binding(get: { currentPrice }, set: { price = $0 }), in: range) {
          Text("\(symbol) price")
        }
        .tint(Brand.buy)
        .offset(x: price == nil ? hintOffset : 0)
      }
      .frame(height: 32)
      HStack {
        Label("Buy zone \(quote?.formatted(lower) ?? "")–\(quote?.formatted(upper) ?? "")", systemImage: "arrow.down.to.line.compact")
          .foregroundStyle(Brand.buy)
        Spacer()
        if price != nil {
          Button("Reset") {
            withAnimation(.smooth) {
              price = nil
              hasEntered = false
            }
          }
          .foregroundStyle(.white.opacity(0.7))
        }
      }
      .font(.caption.weight(.semibold))
      .lineLimit(1)
      .minimumScaleFactor(0.7)
    }
    .padding(16)
    .showcaseSurface(cornerRadius: 22)
  }
}
