import SwiftUI
import WidgetKit

// The Home Screen and Apple Watch chapters of the intro, built on one template:
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

/// The real Apple Watch Today screen on a watch drawn to scale, scrolling gently as if the Digital Crown were turning.
struct WatchShowcaseStep: View {
  var model: OnboardingModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var scroll: CGFloat = 0
  @State private var isScrolling = false
  @State private var crownTurn: CGFloat = 0
  @State private var hops = 0

  /// Apple Watch proportions: display, the black border around it, and the case.
  private enum Size {
    static let display = CGSize(width: 198, height: 236)
    static let displayRadius: CGFloat = 42
    static let border: CGFloat = 7
    static let caseInset: CGFloat = 9
    static var bezel: CGSize { CGSize(width: display.width + border * 2, height: display.height + border * 2) }
    static var watchCase: CGSize { CGSize(width: bezel.width + caseInset * 2, height: bezel.height + caseInset * 2) }
    /// The title bar sits inside the rounded corners, like every watchOS app.
    static let titleInset: CGFloat = 24
    static let titleTop: CGFloat = 14
    /// Content begins below the title, and fades out fully before reaching it.
    static let contentTop: CGFloat = 50
    static let fadeStart: CGFloat = 36
    static let fadeEnd: CGFloat = 66
    static let scrollDistance: CGFloat = 170
  }

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
      // Let people meet Dippy at the top before the tour starts.
      try? await Task.sleep(for: .seconds(3))
      while !Task.isCancelled {
        await scrollTo(-Size.scrollDistance, duration: 2.4)
        try? await Task.sleep(for: .seconds(2.2))
        await scrollTo(0, duration: 2.0)
        try? await Task.sleep(for: .seconds(2.8))
      }
    }
  }

  private func scrollTo(_ offset: CGFloat, duration: Double) async {
    withAnimation(.easeOut(duration: 0.2)) { isScrolling = true }
    withAnimation(.smooth(duration: duration)) {
      crownTurn += (scroll - offset) / 40
      scroll = offset
    }
    try? await Task.sleep(for: .seconds(duration))
    withAnimation(.easeIn(duration: 0.4)) { isScrolling = false }
  }

  // MARK: Hardware

  private var watch: some View {
    ZStack {
      RoundedRectangle(cornerRadius: Size.displayRadius + Size.border + Size.caseInset, style: .continuous)
        .fill(LinearGradient(colors: [Color(white: 0.24), Color(white: 0.1)], startPoint: .top, endPoint: .bottom))
        .overlay {
          RoundedRectangle(cornerRadius: Size.displayRadius + Size.border + Size.caseInset, style: .continuous)
            .strokeBorder(LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
        }
        .frame(width: Size.watchCase.width, height: Size.watchCase.height)
        .shadow(color: .black.opacity(0.5), radius: 24, y: 14)
      RoundedRectangle(cornerRadius: Size.displayRadius + Size.border, style: .continuous)
        .fill(.black)
        .frame(width: Size.bezel.width, height: Size.bezel.height)
      display
        .frame(width: Size.display.width, height: Size.display.height)
        .clipShape(.rect(cornerRadius: Size.displayRadius, style: .continuous))
    }
    .overlay(alignment: .topTrailing) { crown }
    .overlay(alignment: .trailing) { sideButton }
    .accessibilityElement(children: .contain)
  }

  /// The Digital Crown, whose ridges roll as the screen scrolls.
  private var crown: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 4, style: .continuous)
        .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.22)], startPoint: .top, endPoint: .bottom))
      VStack(spacing: 3.5) {
        ForEach(0..<9, id: \.self) { _ in
          Rectangle().fill(.black.opacity(0.35)).frame(height: 1)
        }
      }
      .offset(y: (crownTurn.truncatingRemainder(dividingBy: 1)) * 4.5)
      .padding(.vertical, -4)
    }
    .frame(width: 9, height: 40)
    .clipShape(.rect(cornerRadius: 4, style: .continuous))
    .offset(x: 6, y: Size.watchCase.height * 0.2)
    .accessibilityHidden(true)
  }

  private var sideButton: some View {
    Capsule()
      .fill(LinearGradient(colors: [Color(white: 0.34), Color(white: 0.16)], startPoint: .top, endPoint: .bottom))
      .frame(width: 5, height: 50)
      .offset(x: 4, y: Size.watchCase.height * 0.16)
      .accessibilityHidden(true)
  }

  // MARK: Display

  private var display: some View {
    ZStack(alignment: .top) {
      Brand.nightMiddle
      content
        .padding(.horizontal, 8)
        .padding(.top, Size.contentTop)
        .offset(y: scroll)
        .frame(width: Size.display.width, height: Size.display.height, alignment: .top)
        // Content fades out beneath the title instead of hitting a hard edge, as on watchOS.
        .mask {
          LinearGradient(stops: [
            .init(color: .clear, location: 0),
            .init(color: .clear, location: Size.fadeStart / Size.display.height),
            .init(color: .black, location: Size.fadeEnd / Size.display.height),
            .init(color: .black, location: 1),
          ], startPoint: .top, endPoint: .bottom)
        }
      titleBar
      scrollIndicator
    }
    .foregroundStyle(.white)
  }

  private var titleBar: some View {
    HStack(alignment: .firstTextBaseline) {
      Text("Dipwise")
        .foregroundStyle(Brand.buy)
      Spacer()
      Text(Date.now, format: .dateTime.hour().minute())
        .monospacedDigit()
    }
    .font(.system(size: 15, weight: .semibold, design: .rounded))
    .lineLimit(1)
    .padding(.horizontal, Size.titleInset)
    .padding(.top, Size.titleTop)
    .accessibilityHidden(true)
  }

  /// watchOS shows a small indicator beside the Crown while scrolling.
  private var scrollIndicator: some View {
    let progress = min(1, max(0, -scroll / Size.scrollDistance))
    return Capsule()
      .fill(.white.opacity(0.75))
      .frame(width: 3, height: 22)
      .offset(y: Size.display.height * 0.22 + progress * 26)
      .frame(maxWidth: .infinity, alignment: .trailing)
      .padding(.trailing, 5)
      .opacity(isScrolling ? 1 : 0)
      .accessibilityHidden(true)
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 8) {
      WatchDippyHeader(greeting: WatchGreeting.text(), message: "All quiet. I'm watching your zones.", isAsleep: false, hops: hops)
        .padding(.horizontal, 4)
        .contentShape(.rect)
        .onTapGesture {
          hops += 1
          model.complete("watch")
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap Dippy")
      ForEach(model.sampleStatuses.prefix(2)) { status in
        WatchPlanCard(status: status)
      }
      WatchSectionTitle(title: "Today's movers")
        .padding(.horizontal, 4)
      ForEach(movers.prefix(2), id: \.symbol) { quote in
        WatchMoverRow(quote: quote)
      }
    }
    .sensoryFeedback(.impact(weight: .light), trigger: hops)
  }
}
