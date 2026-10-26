import SwiftUI
import WidgetKit

// The Home Screen and Apple Watch chapters of the intro, built on one template:
// a single hero on the app's navy surface, one headline, one thing to try, and the same rise-in motion.

/// The shared layout of every showcase chapter.
struct ShowcaseLayout<Hero: View>: View {
  var eyebrow: LocalizedStringKey
  var title: LocalizedStringKey
  var message: LocalizedStringKey
  var mission: LocalizedStringKey
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

// MARK: - Devices

/// The same metal, glass, and button finish on every device in the intro, so the iPhone and Apple Watch match.
enum DeviceFinish {
  static let metal = LinearGradient(colors: [Color(white: 0.24), Color(white: 0.1)], startPoint: .top, endPoint: .bottom)
  static let edge = LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.06)], startPoint: .top, endPoint: .bottom)
  static let button = LinearGradient(colors: [Color(white: 0.34), Color(white: 0.16)], startPoint: .top, endPoint: .bottom)
  static let shadow = Color.black.opacity(0.5)

  /// The wallpaper on every Home Screen and lock screen Dipwise shows, in the intro and the App Store.
  static var wallpaper: some View { DipwiseWallpaper() }
}

/// iPhone 18 Pro Max, in points: Apple's own product frame, and where its screen sits inside it.
enum PhoneSize {
  static let device = CGSize(width: 490, height: 1000)
  static let screen = CGSize(width: 440, height: 956)
  static let screenOrigin = CGPoint(x: 25, y: 22)
  static let radius: CGFloat = 62
  static var totalWidth: CGFloat { device.width }
}

/// The real iPhone 18 Pro Max, Apple's product frame around a live screen, the same device the App Store shows.
/// Only the top of the phone shows; the rest fades into the page, so the screen stays large enough to read.
struct PhoneMockup<Screen: View>: View {
  /// How much of the screen shows, in points.
  var visibleHeight: CGFloat
  var scale: CGFloat
  @ViewBuilder var screen: Screen

  private typealias Size = PhoneSize

  private var height: CGFloat { visibleHeight + Size.screenOrigin.y }

  var body: some View {
    ZStack(alignment: .topLeading) {
      screen
        .frame(width: Size.screen.width, height: Size.screen.height, alignment: .top)
        .clipShape(.rect(cornerRadius: Size.radius, style: .continuous))
        .offset(x: Size.screenOrigin.x, y: Size.screenOrigin.y)
      Image(.deviceIPhone)
        .resizable()
        .frame(width: Size.device.width, height: Size.device.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .frame(width: Size.device.width, height: height, alignment: .top)
    .clipped()
    // Only the top of the phone shows; it fades softly into the page.
    .mask {
      LinearGradient(stops: [
        .init(color: .black, location: 0),
        .init(color: .black, location: 0.8),
        .init(color: .clear, location: 1),
      ], startPoint: .top, endPoint: .bottom)
    }
    .shadow(color: DeviceFinish.shadow, radius: 24, y: 14)
    .scaleEffect(scale, anchor: .top)
    .frame(width: Size.device.width * scale, height: height * scale, alignment: .top)
  }
}

/// The iPhone status bar, drawn at real size.
private struct PhoneStatusBar: View {
  var showsTime = true

  var body: some View {
    HStack {
      if showsTime {
        Text("9:41")
          .font(.system(size: 17, weight: .semibold))
          .padding(.leading, 40)
      }
      Spacer()
      HStack(spacing: 6) {
        Image(systemName: "cellularbars")
        Image(systemName: "wifi")
        Image(systemName: "battery.100percent")
      }
      .font(.system(size: 15, weight: .semibold))
      .padding(.trailing, 34)
    }
    .foregroundStyle(.white)
    .frame(height: 54)
    .padding(.top, 4)
    .accessibilityHidden(true)
  }
}

/// Ticks every few seconds so previews change the way the real widgets do through the day, just faster.
private struct LivingClock {
  static func tick(_ step: Int) -> Date { Date.now.addingTimeInterval(Double(step) * 300) }
}

/// Scales a phone to the width available, never past a size that keeps the chapter on one screen.
private func phoneScale(for width: CGFloat) -> CGFloat {
  guard width > 0 else { return 0.7 }
  // Bigger on iPad, where there's room.
  return min(width > 600 ? 0.92 : 0.74, (width - 56) / PhoneSize.totalWidth)
}

// MARK: - Home Screen

/// The real widgets on a Home Screen, alive: plans page by themselves, Dippy changes pose, and taps get a reaction.
struct WidgetShowcaseStep: View {
  var model: OnboardingModel
  /// Shows just the Home Screen, full size, for App Store screenshots.
  var showsScreenOnly = false

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var step = 0
  @State private var width: CGFloat = 0

  private enum Metrics {
    static let small: CGFloat = 158
    static let gap: CGFloat = 22
    static let medium = small * 2 + gap
  }

  private var focus: String? { model.focusSymbol ?? model.previewSymbols.first }

  var body: some View {
    if showsScreenOnly {
      homeScreen
    } else {
      showcase
    }
  }

  private var showcase: some View {
    ShowcaseLayout(
      eyebrow: "Home Screen",
      title: "Your plans, always in sight",
      message: "Your portfolio and every buy zone on your Home Screen, spelled out so a glance is enough.",
      mission: "Tap a widget",
      isMissionDone: model.completedMissions.contains("widget")
    ) {
      PhoneMockup(visibleHeight: 470, scale: phoneScale(for: width)) {
        homeScreen
      }
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

  private var homeScreen: some View {
    ZStack(alignment: .top) {
      DeviceFinish.wallpaper
      VStack(spacing: 0) {
        PhoneStatusBar()
        VStack(spacing: 14) {
          labeled {
            widget(width: Metrics.medium) {
              PortfolioWidgetView(entry: PortfolioEntry(date: LivingClock.tick(step), portfolio: model.samplePortfolio,
                                                        closest: model.sampleStatuses.first, movers: []), previewFamily: .systemMedium)
            }
          }
          labeled {
            widget(width: Metrics.medium) {
              PlansWidgetView(entry: PlansEntry(date: LivingClock.tick(step), statuses: model.sampleStatuses, index: step), previewFamily: .systemMedium)
            }
          }
          HStack(alignment: .top, spacing: Metrics.gap) {
            labeled {
              widget(width: Metrics.small) {
                StockPlanWidgetView(
                  entry: StockPlanEntry(date: LivingClock.tick(step), symbol: focus, quote: focus.flatMap { model.quotes[$0] },
                                        targets: model.sampleStatuses.map(\.target).filter { $0.symbol == focus }),
                  previewFamily: .systemSmall
                )
              }
            }
            labeled {
              widget(width: Metrics.small) {
                PortfolioWidgetView(entry: PortfolioEntry(date: LivingClock.tick(step), portfolio: model.samplePortfolio,
                                                          closest: nil, movers: []), previewFamily: .systemSmall)
              }
            }
          }
        }
        .padding(.top, 18)
      }
    }
  }

  /// Widgets on the Home Screen carry the app's name beneath them.
  private func labeled<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 6) {
      content()
      Text("Dipwise")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .accessibilityHidden(true)
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
        .background(Brand.nightMiddle)
        .clipShape(.rect(cornerRadius: 24, style: .continuous))
        .allowsHitTesting(false)
        .overlay {
          RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        .contentShape(.rect(cornerRadius: 24))
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
  @State private var hops = 0

  /// Apple Watch Series 11 (46 mm), in points: Apple's own product frame, and where its display sits inside it.
  private enum Size {
    static let device = CGSize(width: 280, height: 440)
    static let display = CGSize(width: 208, height: 248)
    static let displayOrigin = CGPoint(x: 36, y: 96)
    static let displayRadius: CGFloat = 42
    /// The title bar sits inside the rounded corners, like every watchOS app.
    static let titleInset: CGFloat = 22
    static let titleTop: CGFloat = 10
    /// Content begins below the title, and fades out fully before reaching it.
    static let contentTop: CGFloat = 58
    static let fadeStart: CGFloat = 46
    static let fadeEnd: CGFloat = 70
    static let scrollDistance: CGFloat = 300
  }

  private var movers: [Quote] { model.previewSymbols.compactMap { model.quotes[$0] }.sorted { abs($0.change) > abs($1.change) } }

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
    withAnimation(.smooth(duration: duration)) { scroll = offset }
    try? await Task.sleep(for: .seconds(duration))
    withAnimation(.easeIn(duration: 0.4)) { isScrolling = false }
  }

  // MARK: Hardware

  /// The real Apple Watch Series 11, Apple's product frame around the live display, the same device the App Store shows.
  private var watch: some View {
    ZStack(alignment: .topLeading) {
      display
        .frame(width: Size.display.width, height: Size.display.height)
        .clipShape(.rect(cornerRadius: Size.displayRadius, style: .continuous))
        .offset(x: Size.displayOrigin.x, y: Size.displayOrigin.y)
      Image(.deviceWatch)
        .resizable()
        .frame(width: Size.device.width, height: Size.device.height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
    .frame(width: Size.device.width, height: Size.device.height)
    .shadow(color: DeviceFinish.shadow, radius: 24, y: 14)
    .accessibilityElement(children: .contain)
  }

  // MARK: Display

  private var display: some View {
    ZStack(alignment: .top) {
      Brand.nightMiddle
      content
        .padding(.horizontal, 8)
        .padding(.top, Size.contentTop)
        // Full natural height, like a scroll view, so no text gets squeezed.
        .fixedSize(horizontal: false, vertical: true)
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

  /// The same top as the real watch app: the time, with the app's title in green beneath it, both on the right.
  private var titleBar: some View {
    VStack(alignment: .trailing, spacing: 0) {
      Text(Date.now, format: .dateTime.hour().minute())
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .monospacedDigit()
      Text("Dipwise")
        .font(.system(size: 17, weight: .semibold, design: .rounded))
        .foregroundStyle(Brand.buy)
    }
    .lineLimit(1)
    .frame(maxWidth: .infinity, alignment: .trailing)
    .padding(.trailing, Size.titleInset)
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

  private var portfolio: WatchPortfolio? { model.samplePortfolio }

  /// The real watch app's Today page, in the same order: Dippy, portfolio, closest plans, movers, and market hours.
  private var content: some View {
    VStack(alignment: .leading, spacing: 8) {
      WatchDippyHeader(greeting: WatchGreeting.text(), message: OwlMood.calm.watchMessage, isAsleep: false, hops: hops)
        .contentShape(.rect)
        .onTapGesture {
          hops += 1
          model.complete("watch")
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Tap Dippy")
      if let portfolio {
        WatchPortfolioHero(portfolio: portfolio)
      }
      WatchSectionTitle(title: "Closest plans")
      ForEach(model.sampleStatuses.prefix(2)) { status in
        WatchPlanCard(status: status)
      }
      WatchSectionTitle(title: "Today's movers")
      ForEach(movers.prefix(2), id: \.symbol) { quote in
        WatchMoverRow(quote: quote)
      }
      WatchMarketStatus(isOpen: MarketClock.isOpen(), nextChange: MarketClock.nextChange(), market: nil)
        .padding(.top, 2)
    }
    .sensoryFeedback(.impact(weight: .light), trigger: hops)
  }
}

// MARK: - Notifications

/// A lock screen on the same iPhone, where the user's own alerts arrive one by one. Tap one to expand it.
struct NotifyStep: View {
  var model: OnboardingModel
  /// Shows just the lock screen, full size with every alert, for App Store screenshots.
  var showsScreenOnly = false

  private struct Alert: Identifiable, Equatable {
    var id: String
    var title: LocalizedStringKey
    var message: LocalizedStringKey
    var symbol: String
    var values: [Double]
    var color: Color
  }

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visible: [Alert] = []
  @State private var expanded: String?
  @State private var width: CGFloat = 0

  /// Alerts built from the stocks and zone the user chose a moment ago.
  private var alerts: [Alert] {
    let statuses = model.sampleStatuses
    var list: [Alert] = []
    if let symbol = model.focusSymbol, let quote = model.focusQuote, model.zoneUpper > 0 {
      let price = (model.zoneLower + model.zoneUpper) / 2
      list.append(Alert(id: "buy", title: "\(symbol) entered your buy zone",
                        message: "Now \(quote.formatted(price)), inside \(quote.formatted(model.zoneLower))–\(quote.formatted(model.zoneUpper)). Your plan: buy 3 shares.",
                        symbol: "arrow.down.to.line.compact", values: Array(quote.closes.suffix(30)) + [price], color: Brand.buy))
    }
    if let sell = statuses.first(where: { $0.target.rule.kind.side == .sell }), let quote = sell.quote {
      list.append(Alert(id: "sell", title: "\(sell.target.symbol) is close to your sell zone",
                        message: "Now \(quote.formatted(quote.price)), just \(distanceText(sell.distance)) away. Ready to take some profit?",
                        symbol: "arrow.up.to.line.compact", values: Array(quote.closes.suffix(30)), color: Brand.sell))
    }
    list.append(Alert(id: "brief", title: "Your daily brief is ready",
                      message: "One minute with Dippy keeps your streak alive.", symbol: "flame.fill", values: [], color: Brand.amber))
    return list
  }

  var body: some View {
    if showsScreenOnly {
      lockScreen
        .task {
          visible = alerts
          expanded = alerts.first?.id
        }
    } else {
      showcase
    }
  }

  private var showcase: some View {
    ShowcaseLayout(
      eyebrow: "Notifications",
      title: "Never miss your moment",
      message: "Dippy taps you the second a stock reaches your zone, with your plan right in the alert.",
      mission: "Tap an alert",
      isMissionDone: model.completedMissions.contains("alert")
    ) {
      PhoneMockup(visibleHeight: 470, scale: phoneScale(for: width)) {
        lockScreen
      }
    }
    .frame(maxWidth: .infinity)
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    .sensoryFeedback(.impact(weight: .light), trigger: visible.count)
    .task { await play() }
  }

  /// Today, or the screenshot day when capturing for the App Store.
  private var lockDate: Date {
    #if DEBUG
    if showsScreenOnly, let day = QuoteService.marketingDate { return day }
    #endif
    return .now
  }

  private var lockScreen: some View {
    ZStack(alignment: .top) {
      DeviceFinish.wallpaper
      if showsScreenOnly {
        // The flashlight and camera buttons of a real lock screen.
        HStack {
          lockButton("flashlight.off.fill")
          Spacer()
          lockButton("camera.fill")
        }
        .padding(.horizontal, 48)
        .padding(.bottom, 52)
        .frame(maxHeight: .infinity, alignment: .bottom)
      }
      VStack(spacing: 0) {
        PhoneStatusBar(showsTime: false)
        // In the screenshot, Face ID has just unlocked the phone, so the full alerts show.
        Image(systemName: showsScreenOnly ? "lock.open.fill" : "lock.fill")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.white.opacity(0.85))
        Text(lockDate, format: .dateTime.weekday(.wide).day().month(.wide))
          .font(.system(size: 20, weight: .semibold))
          .foregroundStyle(.white.opacity(0.85))
          .padding(.top, 10)
        Text("9:41")
          .font(.system(size: 92, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .padding(.top, -4)
        VStack(spacing: 10) {
          ForEach(visible) { alert in
            notification(alert)
              .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.92, anchor: .bottom)))
          }
        }
        .padding(.horizontal, 14)
        .padding(.top, 18)
      }
    }
  }

  private func notification(_ alert: Alert) -> some View {
    let isExpanded = expanded == alert.id
    return Button {
      withAnimation(.spring(duration: 0.45, bounce: 0.2)) { expanded = isExpanded ? nil : alert.id }
      model.complete("alert")
    } label: {
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .top, spacing: 12) {
          Image(.appIconPreview)
            .resizable()
            .frame(width: 40, height: 40)
            .clipShape(.rect(cornerRadius: 10, style: .continuous))
          VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
              Image(systemName: alert.symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(alert.color)
              Text(alert.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
              Spacer(minLength: 4)
              Text("now")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.6))
            }
            Text(alert.message)
              .font(.system(size: 15))
              .foregroundStyle(.white.opacity(0.85))
              .lineLimit(isExpanded ? 4 : 2)
              .multilineTextAlignment(.leading)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        if isExpanded {
          if alert.values.count > 1 {
            WidgetSparkline(values: alert.values)
              .frame(height: 64)
              .padding(10)
              .background(.white.opacity(0.06), in: .rect(cornerRadius: 14, style: .continuous))
          }
          HStack(spacing: 8) {
            actionLabel(alert.id == "brief" ? "Start Brief" : "Open Plan")
            actionLabel(alert.id == "brief" ? "Later" : "Snooze 1 Hour")
          }
        }
      }
      .foregroundStyle(.white)
      .padding(14)
      .frame(maxWidth: .infinity, alignment: .leading)
      // A dark, solid card so the alert reads clearly on any wallpaper.
      .background(Color.black.opacity(0.42), in: .rect(cornerRadius: 26, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1)
      }
    }
    .buttonStyle(ShowcasePressStyle())
    .accessibilityElement(children: .combine)
    .accessibilityHint(isExpanded ? "Collapses the alert" : "Expands the alert")
  }

  private func lockButton(_ systemImage: String) -> some View {
    Image(systemName: systemImage)
      .font(.system(size: 22, weight: .medium))
      .foregroundStyle(.white)
      .frame(width: 54, height: 54)
      .background(.white.opacity(0.14), in: .circle)
      .accessibilityHidden(true)
  }

  private func actionLabel(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 15, weight: .semibold))
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(.white.opacity(0.1), in: .rect(cornerRadius: 14, style: .continuous))
  }

  /// Alerts arrive one by one, newest on top, then the screen clears and it starts again.
  private func play() async {
    let alerts = alerts
    if reduceMotion {
      visible = alerts
      return
    }
    while !Task.isCancelled {
      for alert in alerts.reversed() where !visible.contains(alert) {
        try? await Task.sleep(for: .seconds(1.2))
        withAnimation(.spring(duration: 0.55, bounce: 0.25)) { visible.insert(alert, at: 0) }
      }
      // Stays put while someone is reading an expanded alert.
      try? await Task.sleep(for: .seconds(4))
      while expanded != nil && !Task.isCancelled {
        try? await Task.sleep(for: .seconds(1))
      }
      withAnimation(.smooth(duration: 0.5)) { visible = [] }
      try? await Task.sleep(for: .seconds(0.8))
    }
  }
}
