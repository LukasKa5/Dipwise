import SwiftUI

/// An interactive first-launch tour: meet the owl, scrub a chart, drag a zone, and vote with the flock.
struct OnboardingView: View {
  var onFinish: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var page = 0
  @State private var showsPaywall = false
  private let pageCount = 5

  var body: some View {
    ZStack {
      Brand.nightMiddle.ignoresSafeArea()
      VStack(spacing: 0) {
        Group {
          switch page {
          case 0: WelcomePage()
          case 1: ScrubPage()
          case 2: ZonePage()
          case 3: FlockPage()
          default: NotificationsPage()
          }
        }
        .id(page)
        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
        .frame(maxWidth: 560, maxHeight: .infinity)

        PageDots(count: pageCount, current: page)
          .padding(.bottom, 20)

        VStack(spacing: 10) {
          Button(action: advance) {
            Text(page == pageCount - 1 ? "Allow Notifications" : "Continue")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
          }
          .buttonStyle(.borderedProminent)
          .tint(Brand.mint)
          .foregroundStyle(Brand.owlInk)

          HStack {
            if page > 0 {
              Button("Back") { withAnimation(.smooth) { page -= 1 } }
            }
            Spacer()
            Button(page == pageCount - 1 ? "Not Now" : "Skip") { showsPaywall = true }
          }
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
        .frame(maxWidth: 520)
      }
    }
    .foregroundStyle(.white)
    .environment(\.colorScheme, .dark)
    .sheet(isPresented: $showsPaywall, onDismiss: onFinish) {
      PaywallView()
    }
  }

  private func advance() {
    if page < pageCount - 1 {
      withAnimation(reduceMotion ? .easeInOut : .smooth) { page += 1 }
    } else {
      Task {
        await NotificationManager.requestAuthorization()
        showsPaywall = true
      }
    }
  }
}

// MARK: - Pages

private struct PageText: View {
  var title: String
  var message: String

  var body: some View {
    VStack(spacing: 10) {
      Text(title)
        .font(.largeTitle.bold())
        .multilineTextAlignment(.center)
      Text(message)
        .font(.title3)
        .foregroundStyle(.white.opacity(0.7))
        .multilineTextAlignment(.center)
    }
    .padding(.horizontal, 28)
  }
}

private struct WelcomePage: View {
  @State private var taps = 0
  @State private var arrived = false
  private let lines = [
    "Hoo! Tap me.",
    "I'm your stock-watching owl.",
    "I watch your stocks day and night…",
    "…so you can live your life.",
    "Okay, okay. Let's get started!",
  ]

  var body: some View {
    VStack(spacing: 26) {
      Spacer()
      SpeechBubble(text: lines[min(taps, lines.count - 1)])
        .animation(.snappy, value: taps)
      LivelyOwl()
        .frame(width: 170, height: 195)
        .simultaneousGesture(TapGesture().onEnded { taps += 1 })
        .offset(y: arrived ? 0 : -500)
        .rotationEffect(.degrees(arrived ? 0 : -25))
        .onAppear {
          withAnimation(.spring(duration: 1.1, bounce: 0.35)) { arrived = true }
        }
        .accessibilityLabel("Dipwise owl")
        .accessibilityAddTraits(.isButton)
      PageText(title: "Meet your investing owl", message: "Dipwise is the calm assistant between you and your broker.")
      Spacer()
    }
  }
}

private struct ScrubPage: View {
  @State private var selectedIndex: Int?
  @State private var scrubs = 0

  private static let values: [Double] = (0..<60).map { index in
    let x = Double(index) / 59
    return 100 + 14 * sin(x * .pi * 2.4) - 18 * x * (1 - x) * 4 + 22 * x
  }
  private static let dates: [Date] = (0..<60).map { Date.now.addingTimeInterval(Double($0 - 59) * 86_400) }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      VStack(alignment: .leading, spacing: 6) {
        if let selectedIndex {
          Text(Self.dates[selectedIndex], format: .dateTime.day().month(.abbreviated))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Brand.mint)
          Text(Self.values[selectedIndex], format: .currency(code: "USD"))
            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
        } else {
          Text("Slide your finger along the chart")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white.opacity(0.7))
          Text(Self.values.last ?? 0, format: .currency(code: "USD"))
            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 28)

      InteractiveChart(values: Self.values, dates: Self.dates, owlSize: 56, selectedIndex: $selectedIndex)
        .frame(height: 240)
        .padding(.horizontal, 20)
        .onChange(of: selectedIndex) { _, index in if index != nil { scrubs += 1 } }

      PageText(
        title: scrubs > 15 ? "You startled the owl!" : "Glance, don't stare",
        message: scrubs > 15 ? "It always flies off to find the next dip. That's its job." : "Read any day's price at a touch. Get too close to the owl and see what happens."
      )
      .animation(.smooth, value: scrubs > 15)
      Spacer()
    }
  }
}

private struct ZonePage: View {
  @State private var lower = 92.0
  @State private var upper = 97.0

  private static let values: [Double] = (0..<50).map { index in
    let x = Double(index) / 49
    return 104 + 6 * sin(x * .pi * 3) - 4 * x
  }

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      ZoneEditorChart(values: Self.values, side: .buy, lower: $lower, upper: $upper, crowdZone: 90...95,
                      format: { $0.formatted(.currency(code: "USD").precision(.fractionLength(0))) })
        .frame(height: 260)
        .padding(.horizontal, 20)
      Label("You'd buy between \(lower.formatted(.currency(code: "USD"))) and \(upper.formatted(.currency(code: "USD")))", systemImage: "scope")
        .font(.headline)
        .foregroundStyle(Brand.amber)
        .contentTransition(.numericText())
      PageText(title: "Plan your zones", message: "Drag the handles to set where you'd buy and sell. The shaded band shows where the crowd plans to buy.")
      Spacer()
    }
  }
}

private struct FlockPage: View {
  @State private var vote: Bool?
  @State private var flights = 0

  var body: some View {
    VStack(spacing: 24) {
      Spacer()
      LivelyOwl(hopsOnTap: false)
        .frame(width: 90, height: 104)
        .owlFlight(trigger: flights, height: 40)
      VoteCard(symbol: "NVDA", votes: FlockVotes(bullish: vote == true ? 613 : 612, bearish: vote == false ? 289 : 288), userVote: vote) { bullish in
        vote = bullish
        flights += 1
      }
      .environment(\.colorScheme, .dark)
      .padding(.horizontal, 20)
      PageText(
        title: "Invest with the flock",
        message: vote == nil ? "Vote, then see what thousands of investors think, all anonymous." : "See where the crowd buys and sells every stock, and how their dip-buys worked out."
      )
      .animation(.smooth, value: vote)
      Spacer()
    }
  }
}

private struct NotificationsPage: View {
  @State private var rings = 0

  var body: some View {
    VStack(spacing: 28) {
      Spacer()
      ZStack(alignment: .topTrailing) {
        LivelyOwl()
          .frame(width: 150, height: 172)
        Image(systemName: "bell.badge.fill")
          .font(.system(size: 44))
          .symbolRenderingMode(.palette)
          .foregroundStyle(Brand.amber, .white)
          .symbolEffect(.wiggle, value: rings)
          .offset(x: 30, y: -10)
      }
      .onTapGesture { rings += 1 }
      .task {
        while !Task.isCancelled {
          try? await Task.sleep(for: .seconds(2.5))
          rings += 1
        }
      }
      PageText(title: "Never miss your dip", message: "The owl taps you on the shoulder the moment a stock enters your zone, with your plan and your note.")
      Spacer()
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
      .overlay(alignment: .bottom) {
        Image(systemName: "arrowtriangle.down.fill")
          .foregroundStyle(.white)
          .offset(y: 12)
      }
      .id(text)
      .transition(.scale(scale: 0.8).combined(with: .opacity))
  }
}

private struct PageDots: View {
  var count: Int
  var current: Int

  var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<count, id: \.self) { index in
        Capsule()
          .fill(index == current ? Brand.mint : .white.opacity(0.25))
          .frame(width: index == current ? 22 : 8, height: 8)
      }
    }
    .animation(.smooth, value: current)
    .accessibilityElement()
    .accessibilityLabel("Page \(current + 1) of \(count)")
  }
}
