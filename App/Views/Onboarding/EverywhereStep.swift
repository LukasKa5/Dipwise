import SwiftUI
import WidgetKit

/// The intro's "wow" moment: drag the user's own stock down into their buy zone and watch
/// the Home Screen widget, Apple Watch, and notification react together, all in the app's own navy style.
struct EverywhereStep: View {
  var model: OnboardingModel

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var price: Double?
  @State private var hasEntered = false
  @State private var celebrations = 0
  @State private var width: CGFloat = 0
  @State private var hintOffset: CGFloat = 0

  private var symbol: String { model.focusSymbol ?? "NVDA" }
  private var quote: Quote? { model.focusQuote }
  private var lower: Double { model.zoneLower }
  private var upper: Double { model.zoneUpper }

  /// The slider runs from just below the zone to a little above today's price.
  private var range: ClosedRange<Double> {
    guard let quote, lower > 0 else { return 0...1 }
    return (lower * 0.97)...max(quote.price * 1.03, upper * 1.05)
  }

  private var currentPrice: Double { price ?? quote?.price ?? 0 }
  private var isInZone: Bool { currentPrice <= upper && currentPrice >= lower * 0.9 }

  /// The user's real plan, priced at wherever they've dragged it.
  private var status: TargetStatus? {
    guard var quote, upper > 0 else { return nil }
    quote.price = currentPrice
    return TargetStatus(target: WatchedTarget(id: Self.previewID, symbol: symbol, name: quote.name,
                                              rule: AlertRule(kind: .buyZone, lower: lower, upper: upper)), quote: quote)
  }

  private static let previewID = UUID()

  /// The widget and watch side by side at real size, scaled to fit the screen.
  private var stageScale: CGFloat {
    guard width > 0 else { return 0.85 }
    return min(1, (width - 32) / Stage.width)
  }

  private enum Stage {
    static let widget: CGFloat = 158
    static let watch = CGSize(width: 176, height: 212)
    static let spacing: CGFloat = 20
    static let width = widget + spacing + watch.width + 10
    static let height = watch.height + 26
  }

  var body: some View {
    VStack(spacing: 16) {
      StepTitle(title: "Dippy is everywhere you are", message: "Drag \(symbol) down into your buy zone. Watch every screen react.")
        .padding(.top, 8)

      stage
        .scaleEffect(stageScale, anchor: .top)
        .frame(width: Stage.width * stageScale, height: Stage.height * stageScale, alignment: .top)

      ZStack {
        if hasEntered, let status {
          DipwiseNotificationBanner(
            title: "\(symbol) entered your buy zone",
            message: "Now \(status.quote?.formatted(currentPrice) ?? ""), inside \(compactSummary(status).replacingOccurrences(of: "Buy ", with: "")). Your plan: buy a little.",
            symbol: "arrow.down.to.line.compact",
            color: Brand.buy
          )
          .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92, anchor: .top)))
        } else {
          Label("Your Lock Screen", systemImage: "lock.fill")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(maxWidth: .infinity, minHeight: 66)
            .background {
              RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
            }
            .transition(.opacity)
        }
      }
      .padding(.horizontal, 24)

      priceControl
        .padding(.horizontal, 24)

      MissionChip(text: hasEntered ? "Dippy caught the dip" : "Drag into the green zone", isDone: hasEntered)
    }
    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    .overlay { Confetti(trigger: celebrations).allowsHitTesting(false) }
    .sensoryFeedback(.success, trigger: hasEntered) { _, new in new }
    .sensoryFeedback(.selection, trigger: isInZone)
    .onChange(of: isInZone) { _, inZone in
      guard inZone, !hasEntered else { return }
      withAnimation(.bouncy(duration: 0.6)) { hasEntered = true }
      celebrations += 1
      model.complete("everywhere")
    }
    .task {
      // A gentle nudge on the slider until the user tries it.
      guard !reduceMotion else { return }
      try? await Task.sleep(for: .seconds(1.5))
      while !Task.isCancelled && price == nil {
        withAnimation(.smooth(duration: 0.5)) { hintOffset = -14 }
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.bouncy(duration: 0.6)) { hintOffset = 0 }
        try? await Task.sleep(for: .seconds(2.4))
      }
    }
  }

  // MARK: Stage

  private var stage: some View {
    HStack(alignment: .bottom, spacing: Stage.spacing) {
      VStack(spacing: 8) {
        PlansWidgetView(entry: PlansEntry(date: .now, statuses: status.map { [$0] } ?? [], index: 0), previewFamily: .systemSmall)
          .environment(\.colorScheme, .dark)
          .padding(16)
          .frame(width: Stage.widget, height: Stage.widget)
          .surface(cornerRadius: 22)
          .allowsHitTesting(false)
        SurfaceLabel(text: "Home Screen", systemImage: "square.grid.2x2.fill")
      }
      VStack(spacing: 8) {
        watch
        SurfaceLabel(text: "Apple Watch", systemImage: "applewatch")
      }
    }
    .frame(width: Stage.width, height: Stage.height, alignment: .bottom)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(status.map { "\(symbol) is \(distanceText($0.distance)) from your buy zone on your widget and Apple Watch." } ?? "")
  }

  /// The real watch app's Today screen, drawn with the same components it uses.
  private var watch: some View {
    ZStack {
      VStack(alignment: .leading, spacing: 6) {
        HStack {
          Text("Dipwise")
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(Brand.buy)
          Spacer()
          Text(Date.now, format: .dateTime.hour().minute())
            .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 6)
        if let status {
          WatchPlanCard(status: status)
        }
        Spacer(minLength: 0)
      }
      .padding(.horizontal, 10)
      .padding(.top, 14)
      .padding(.bottom, 10)

      if hasEntered {
        VStack(spacing: 5) {
          WidgetOwl(size: 30, isAsleep: false)
          Text("\(symbol) is in your buy zone")
            .font(.system(size: 14, weight: .semibold))
            .multilineTextAlignment(.center)
          Text(currentPriceText)
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .foregroundStyle(Brand.buy)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .background(Brand.nightTop, in: .rect(cornerRadius: 22, style: .continuous))
        .padding(8)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
    .foregroundStyle(.white)
    .frame(width: Stage.watch.width, height: Stage.watch.height)
    .clipShape(.rect(cornerRadius: 46, style: .continuous))
    .surface(cornerRadius: 46)
    .overlay(alignment: .trailing) {
      // The Digital Crown and side button, drawn in the same quiet outline style.
      VStack(spacing: 14) {
        Capsule().fill(.white.opacity(0.28)).frame(width: 6, height: 30)
        Capsule().fill(.white.opacity(0.16)).frame(width: 5, height: 40)
      }
      .offset(x: 8, y: -10)
    }
    .phaseAnimator([1.0, 1.04, 1.0], trigger: celebrations) { view, scale in
      view.scaleEffect(scale)
    }
  }

  private var currentPriceText: String {
    quote.map { "Now \($0.formatted(currentPrice))" } ?? ""
  }

  // MARK: Price control

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
          let span = range.upperBound - range.lowerBound
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
    .surface(cornerRadius: 22)
  }
}

/// A preview surface: the app's navy card, lifted off the page with a hairline edge.
private struct Surface: ViewModifier {
  var cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content
      .background(Brand.nightMiddle, in: .rect(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(.white.opacity(0.16), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
  }
}

extension View {
  fileprivate func surface(cornerRadius: CGFloat) -> some View {
    modifier(Surface(cornerRadius: cornerRadius))
  }
}

/// A small caption naming where a surface lives.
private struct SurfaceLabel: View {
  var text: String
  var systemImage: String

  var body: some View {
    Label(text, systemImage: systemImage)
      .font(.caption.weight(.semibold))
      .foregroundStyle(.white.opacity(0.6))
  }
}

/// A Dipwise notification, styled like the app's cards.
struct DipwiseNotificationBanner: View {
  var title: String
  var message: String
  var symbol: String
  var color: Color

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Image(.appIconPreview)
        .resizable()
        .frame(width: 36, height: 36)
        .clipShape(.rect(cornerRadius: 9, style: .continuous))
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 5) {
          Image(systemName: symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(color)
          Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
          Spacer(minLength: 4)
          Text("now")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.55))
        }
        Text(message)
          .font(.caption)
          .foregroundStyle(.white.opacity(0.8))
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .surface(cornerRadius: 20)
    .accessibilityElement(children: .combine)
  }
}

/// Asks for notification permission, with banners in the same style as the demo before it.
struct NotifyStep: View {
  var model: OnboardingModel
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var visible = 0

  private var symbol: String { model.focusSymbol ?? "NVDA" }

  private var banners: [(title: String, message: String, symbol: String, color: Color)] {
    let quote = model.focusQuote
    let zone = quote.map { "\($0.formatted(model.zoneLower))–\($0.formatted(model.zoneUpper))" } ?? "your zone"
    return [
      ("\(symbol) entered your buy zone", "Inside \(zone). Your plan: buy a little.", "arrow.down.to.line.compact", Brand.buy),
      ("Heads-up: \(symbol) is close", "Just 2% above your buy zone. Get ready.", "bell.badge.fill", Brand.amber),
      ("Your daily brief is ready", "One minute with Dippy keeps your streak alive.", "flame.fill", Brand.amber),
    ]
  }

  var body: some View {
    VStack(spacing: 22) {
      Spacer(minLength: 8)
      LivelyOwl(mood: .calm)
        .frame(width: 96, height: 110)
      VStack(spacing: 10) {
        ForEach(Array(banners.prefix(visible).enumerated()), id: \.offset) { _, banner in
          DipwiseNotificationBanner(title: banner.title, message: banner.message, symbol: banner.symbol, color: banner.color)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
      }
      .frame(minHeight: 230, alignment: .top)
      .padding(.horizontal, 24)
      StepTitle(title: "Never miss your moment", message: "Dippy taps you the moment a stock reaches your zone, with a heads-up just before and your plan right in the alert.")
      Spacer(minLength: 8)
    }
    .sensoryFeedback(.impact(weight: .light), trigger: visible)
    .task {
      if reduceMotion {
        visible = banners.count
        return
      }
      for count in 1...banners.count {
        try? await Task.sleep(for: .seconds(0.7))
        withAnimation(.bouncy(duration: 0.5)) { visible = count }
      }
    }
  }
}
