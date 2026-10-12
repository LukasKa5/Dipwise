import SwiftUI

/// Asks for notification permission, with a lock screen where Dipwise alerts drop in one by one.
struct NotifyStep: View {
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

