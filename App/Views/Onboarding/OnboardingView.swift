import SwiftUI

/// First-launch introduction: what Dipwise does, notification permission, and the Pro offer.
struct OnboardingView: View {
  var onFinish: () -> Void

  @State private var page = 0
  @State private var showsPaywall = false
  private let pageCount = 4

  var body: some View {
    ZStack {
      Brand.nightGradient.ignoresSafeArea()
      VStack(spacing: 0) {
        TabView(selection: $page) {
          OnboardingPage(
            title: "Meet your calm investing assistant",
            message: "Dipwise watches your stocks day and night, so you don't have to stare at charts."
          ) {
            DipChart(values: [100, 97, 93, 89, 86, 85.5, 88, 93, 99, 104, 108], owlSize: 74)
              .frame(height: 230)
          }
          .tag(0)

          OnboardingPage(
            title: "Set targets, not alarms",
            message: "Choose the price you'd buy or sell at. Add a note so future you remembers why."
          ) {
            OnboardingTargetsIllustration()
          }
          .tag(1)

          OnboardingPage(
            title: "Invest with the flock",
            message: "See where other investors are waiting to buy and sell, shared anonymously."
          ) {
            OnboardingFlockIllustration()
          }
          .tag(2)

          OnboardingPage(
            title: "Never miss your dip",
            message: "Allow notifications and Dipwise will tap you on the shoulder the moment a target is reached."
          ) {
            Image(systemName: "bell.badge.fill")
              .font(.system(size: 96))
              .symbolRenderingMode(.palette)
              .foregroundStyle(Brand.amber, .white)
              .frame(height: 230)
          }
          .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))

        PageDots(count: pageCount, current: page)
          .padding(.bottom, 24)

        VStack(spacing: 12) {
          Button(action: advance) {
            Text(page == pageCount - 1 ? "Allow Notifications" : "Continue")
              .font(.headline)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 8)
          }
          .buttonStyle(.borderedProminent)
          .tint(Brand.mint)
          .foregroundStyle(Brand.owlInk)

          if page == pageCount - 1 {
            Button("Not Now") { showsPaywall = true }
              .foregroundStyle(.white.opacity(0.7))
          }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
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
      withAnimation(.smooth) { page += 1 }
    } else {
      Task {
        await NotificationManager.requestAuthorization()
        showsPaywall = true
      }
    }
  }
}

private struct OnboardingPage<Illustration: View>: View {
  var title: String
  var message: String
  @ViewBuilder var illustration: Illustration

  var body: some View {
    VStack(spacing: 28) {
      Spacer(minLength: 12)
      illustration
        .padding(.horizontal, 28)
      VStack(spacing: 12) {
        Text(title)
          .font(.largeTitle.bold())
          .multilineTextAlignment(.center)
        Text(message)
          .font(.title3)
          .foregroundStyle(.white.opacity(0.7))
          .multilineTextAlignment(.center)
      }
      .padding(.horizontal, 32)
      Spacer(minLength: 12)
    }
    .frame(maxWidth: 560)
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

private struct OnboardingTargetsIllustration: View {
  var body: some View {
    VStack(spacing: 12) {
      ExampleTarget(symbol: "NVDA", title: "Buy below $178.00", progress: 0.88, note: "Waiting for a pullback")
      ExampleTarget(symbol: "AAPL", title: "Sell above $255.00", progress: 0.6, note: "Take some profit")
    }
    .frame(height: 230)
  }
}

private struct ExampleTarget: View {
  var symbol: String
  var title: String
  var progress: Double
  var note: String

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        TickerBadge(symbol: symbol, size: 34)
        Text(symbol).font(.headline)
        Spacer()
        Text(title)
          .font(.footnote.weight(.semibold))
          .foregroundStyle(Brand.amber)
      }
      TargetTrack(progress: progress)
      Text("\u{201C}\(note)\u{201D}")
        .font(.footnote)
        .italic()
        .foregroundStyle(.white.opacity(0.6))
    }
    .padding(16)
    .background(.white.opacity(0.08), in: .rect(cornerRadius: 20))
    .accessibilityHidden(true)
  }
}

private struct OnboardingFlockIllustration: View {
  private let heights: [Double] = [0.15, 0.3, 0.55, 0.9, 1, 0.7, 0.4, 0.2, 0, 0.15, 0.35, 0.6, 0.45, 0.25, 0.1]

  var body: some View {
    HStack(alignment: .bottom, spacing: 5) {
      ForEach(Array(heights.enumerated()), id: \.offset) { index, height in
        RoundedRectangle(cornerRadius: 4)
          .fill(index < 8 ? Brand.amber : Brand.mint)
          .frame(height: max(4, 180 * height))
      }
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(.white.opacity(0.7))
        .frame(width: 2, height: 210)
        .offset(x: 21)
    }
    .frame(height: 230, alignment: .bottom)
    .accessibilityHidden(true)
  }
}
