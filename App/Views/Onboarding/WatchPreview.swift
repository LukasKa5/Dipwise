import SwiftUI

/// An Apple Watch drawn at real size, showing what Dipwise looks like on watchOS:
/// a watch face with complications, then the app's portfolio, plans, and a stock you scrub with the Digital Crown.
struct WatchPreview: View {
  enum Screen: Int, CaseIterable {
    case face
    case portfolio
    case plans
    case stock

    var title: String {
      switch self {
      case .face: "Watch face with Dipwise complications"
      case .portfolio: "Portfolio at a glance"
      case .plans: "Every plan, closest first"
      case .stock: "Scrub the chart with the Digital Crown"
      }
    }
  }

  var statuses: [TargetStatus]
  var quotes: [String: Quote]
  var symbol: String
  @Binding var screen: Screen

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var notification = false
  @State private var crownTurns = 0.0
  @State private var scrub = 0.0

  /// Apple Watch 46 mm display, in points.
  private static let display = CGSize(width: 208, height: 248)

  private var nearest: TargetStatus? { statuses.first }
  private var quote: Quote? { quotes[symbol] }

  var body: some View {
    ZStack {
      band
      caseShape
      crown
      Capsule()
        .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.28)], startPoint: .top, endPoint: .bottom))
        .frame(width: 6, height: 50)
        .offset(x: 128, y: 40)
      display
    }
    .frame(width: 280, height: 380)
    .compositingGroup()
    .sensoryFeedback(.impact(weight: .medium), trigger: notification)
    .onChange(of: screen) { _, _ in
      withAnimation(.smooth(duration: 0.5)) { crownTurns += 1 }
    }
    .task { await play() }
  }

  /// A notification now and then, and a gentle Crown scrub on the stock screen.
  private func play() async {
    guard !reduceMotion else { return }
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(3))
      if screen == .stock {
        withAnimation(.easeInOut(duration: 1.6)) { scrub = scrub > 0.5 ? 0.15 : 0.85 }
        withAnimation(.easeInOut(duration: 1.6)) { crownTurns += 0.6 }
      } else if screen == .face {
        withAnimation(.bouncy) { notification = true }
        try? await Task.sleep(for: .seconds(2.6))
        withAnimation(.smooth) { notification = false }
      }
    }
  }

  // MARK: Hardware

  private var band: some View {
    VStack(spacing: 0) {
      UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
        .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.16, blue: 0.22), Color(red: 0.2, green: 0.24, blue: 0.3)], startPoint: .top, endPoint: .bottom))
        .frame(width: 176, height: 70)
      Spacer()
      UnevenRoundedRectangle(bottomLeadingRadius: 22, bottomTrailingRadius: 22)
        .fill(LinearGradient(colors: [Color(red: 0.2, green: 0.24, blue: 0.3), Color(red: 0.13, green: 0.16, blue: 0.22)], startPoint: .top, endPoint: .bottom))
        .frame(width: 176, height: 70)
    }
    .frame(height: 380)
  }

  private var caseShape: some View {
    RoundedRectangle(cornerRadius: 64, style: .continuous)
      .fill(LinearGradient(colors: [Color(white: 0.5), Color(white: 0.2), Color(white: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing))
      .frame(width: 244, height: 288)
      .overlay {
        RoundedRectangle(cornerRadius: 64, style: .continuous)
          .strokeBorder(.white.opacity(0.25), lineWidth: 1)
      }
      .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
  }

  /// The Digital Crown, whose ridges roll when the screen scrolls.
  private var crown: some View {
    let phase = crownTurns.truncatingRemainder(dividingBy: 1)
    return ZStack {
      RoundedRectangle(cornerRadius: 5)
        .fill(LinearGradient(colors: [Color(white: 0.62), Color(white: 0.32)], startPoint: .top, endPoint: .bottom))
      VStack(spacing: 3) {
        ForEach(0..<8, id: \.self) { _ in
          Rectangle().fill(.black.opacity(0.28)).frame(height: 1.5)
        }
      }
      .offset(y: phase * 4.5)
      .clipped()
      RoundedRectangle(cornerRadius: 2)
        .fill(Brand.amber)
        .frame(width: 3)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .frame(width: 13, height: 42)
    .clipShape(.rect(cornerRadius: 5))
    .offset(x: 127, y: -46)
  }

  // MARK: Display

  private var display: some View {
    ZStack {
      Color.black
      Group {
        switch screen {
        case .face: face
        case .portfolio: portfolio
        case .plans: plans
        case .stock: stock
        }
      }
      .transition(.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.94)),
        removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.94))
      ))
      if screen != .face { pageDots }
      if notification { notificationCard.transition(.move(edge: .bottom).combined(with: .opacity)) }
    }
    .frame(width: Self.display.width, height: Self.display.height)
    .clipShape(.rect(cornerRadius: 50, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 50, style: .continuous).strokeBorder(.black, lineWidth: 5)
    }
    .environment(\.colorScheme, .dark)
  }

  private var pageDots: some View {
    VStack(spacing: 4) {
      ForEach(1..<Screen.allCases.count, id: \.self) { index in
        Circle()
          .fill(.white.opacity(index == screen.rawValue ? 0.95 : 0.3))
          .frame(width: 5, height: 5)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
    .padding(.trailing, 6)
  }

  /// The title bar every watchOS app shows: app name on the left, time on the right.
  private func titleBar(_ title: String) -> some View {
    HStack {
      Text(title)
        .font(.system(size: 15, weight: .semibold, design: .rounded))
        .foregroundStyle(Brand.buy)
      Spacer()
      Text("10:09")
        .font(.system(size: 15, weight: .semibold, design: .rounded))
    }
    .padding(.horizontal, 22)
    .padding(.top, 12)
  }

  // Face: Modular style, with a large plan complication and three small ones.
  private var face: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        Text(Date.now, format: .dateTime.weekday(.abbreviated).day())
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(Brand.amber)
          .textCase(.uppercase)
          .lineLimit(1)
        Spacer(minLength: 4)
        Text("10:09")
          .font(.system(size: 34, weight: .medium, design: .rounded))
          .monospacedDigit()
          .lineLimit(1)
          .fixedSize()
      }
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 5) {
          OwlMark().frame(width: 13)
          Text("DIPWISE")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Brand.buy)
        }
        Text("\(nearest?.target.symbol ?? symbol) · \(distanceText(nearest?.distance))")
          .font(.system(size: 17, weight: .semibold, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Text(nearest.map(compactSummary) ?? "Buy zone")
          .font(.system(size: 12))
          .foregroundStyle(.white.opacity(0.7))
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        WidgetTrack(progress: nearest?.progress ?? 0.7, color: nearest?.target.rule.kind.side.brandColor ?? Brand.buy)
      }
      HStack(spacing: 8) {
        ring(progress: statuses.dropFirst().first?.progress ?? 0.5, color: Brand.sell, label: String((statuses.dropFirst().first?.target.symbol ?? "AAPL").prefix(4)))
        ZStack {
          Circle().fill(.white.opacity(0.12))
          VStack(spacing: -1) {
            Image(systemName: "flame.fill").font(.system(size: 13)).foregroundStyle(Brand.amber)
            Text("1").font(.system(size: 13, weight: .bold, design: .rounded))
          }
        }
        .frame(width: 48, height: 48)
        ZStack {
          Circle().fill(.white.opacity(0.12))
          VStack(spacing: 0) {
            Image(systemName: MarketClock.isOpen() ? "sun.max.fill" : "moon.fill")
              .font(.system(size: 13))
              .foregroundStyle(MarketClock.isOpen() ? Brand.amber : .white.opacity(0.8))
            Text(MarketClock.isOpen() ? "OPEN" : "SHUT")
              .font(.system(size: 9, weight: .bold))
          }
        }
        .frame(width: 48, height: 48)
      }
      .frame(maxWidth: .infinity)
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func ring(progress: Double, color: Color, label: String) -> some View {
    ZStack {
      Circle().stroke(.white.opacity(0.2), lineWidth: 4)
      Circle().trim(from: 0, to: progress).stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round)).rotationEffect(.degrees(-90))
      Text(label).font(.system(size: 10, weight: .bold)).minimumScaleFactor(0.6).padding(5)
    }
    .frame(width: 48, height: 48)
  }

  private var portfolio: some View {
    let movers = MoversProvider.sorted(Array(quotes.values)).prefix(2)
    return VStack(alignment: .leading, spacing: 6) {
      titleBar("Dipwise")
      VStack(alignment: .leading, spacing: 2) {
        Text("Portfolio")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.white.opacity(0.6))
        Text("$24,318")
          .font(.system(size: 30, weight: .semibold, design: .rounded))
          .monospacedDigit()
        Text("+$286 · +1.2% today")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Brand.buy)
      }
      WidgetSparkline(values: quote.map { Array($0.closes.suffix(30)) } ?? [1, 2, 1.5, 2.5, 2.2, 3])
        .frame(height: 34)
      ForEach(Array(movers), id: \.symbol) { mover in
        HStack {
          Text(mover.symbol).font(.system(size: 13, weight: .semibold))
          Spacer()
          Text(changeText(mover.change))
            .font(.system(size: 12, weight: .semibold).monospacedDigit())
            .foregroundStyle(mover.change >= 0 ? Brand.buy : Brand.sell)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(white: 0.14), in: .rect(cornerRadius: 12, style: .continuous))
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .foregroundStyle(.white)
  }

  private var plans: some View {
    VStack(alignment: .leading, spacing: 6) {
      titleBar("Plans")
      ForEach(statuses.prefix(3)) { status in
        let color = status.target.rule.kind.side.brandColor
        VStack(alignment: .leading, spacing: 5) {
          HStack {
            Text(status.target.symbol)
              .font(.system(size: 14, weight: .semibold))
            Spacer(minLength: 4)
            Text(distanceText(status.distance))
              .font(.system(size: 13, weight: .semibold).monospacedDigit())
              .foregroundStyle(color)
          }
          WidgetTrack(progress: status.progress, color: color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(white: 0.14), in: .rect(cornerRadius: 14, style: .continuous))
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .foregroundStyle(.white)
  }

  private var stock: some View {
    let values = quote.map { Array($0.closes.suffix(30)) } ?? []
    let index = values.isEmpty ? 0 : min(values.count - 1, Int(scrub * Double(values.count - 1)))
    return VStack(alignment: .leading, spacing: 4) {
      titleBar(symbol)
      if let quote, !values.isEmpty {
        Text(quote.formatted(values[index]))
          .font(.system(size: 26, weight: .semibold, design: .rounded))
          .monospacedDigit()
          .contentTransition(.numericText())
          .lineLimit(1)
          .minimumScaleFactor(0.6)
        Label("Turn the Crown to scrub", systemImage: "digitalcrown.arrow.clockwise.fill")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(.white.opacity(0.6))
        GeometryReader { geometry in
          WidgetSparkline(values: values)
            .overlay(alignment: .leading) {
              Rectangle()
                .fill(.white.opacity(0.8))
                .frame(width: 1.5)
                .offset(x: geometry.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1)))
            }
        }
        .frame(height: 70)
        HStack(spacing: 6) {
          Text("1W").foregroundStyle(.white.opacity(0.5))
          Text("1M").padding(.horizontal, 7).padding(.vertical, 2).background(.white.opacity(0.2), in: .capsule)
          Text("3M").foregroundStyle(.white.opacity(0.5))
          Text("1Y").foregroundStyle(.white.opacity(0.5))
        }
        .font(.system(size: 11, weight: .semibold))
        .frame(maxWidth: .infinity)
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 14)
    .foregroundStyle(.white)
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
    .foregroundStyle(.white)
    .padding(12)
    .frame(maxWidth: .infinity)
    .background(Color(white: 0.17), in: .rect(cornerRadius: 22, style: .continuous))
    .padding(10)
    .frame(maxHeight: .infinity, alignment: .bottom)
  }
}
