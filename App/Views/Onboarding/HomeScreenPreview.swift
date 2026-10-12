import SwiftUI
import WidgetKit

/// An iPhone Home Screen drawn at real size, with the app's real widgets among app icons, scaled to fit.
/// The widgets update on their own, and tapping them works like on a real Home Screen.
struct HomeScreenPreview: View {
  var statuses: [TargetStatus]
  var quotes: [String: Quote]
  var symbols: [String]
  /// Called the first time the user taps a widget.
  var onInteract: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var planIndex = 0
  @State private var stockIndex = 0
  @State private var showsZones = false
  @State private var width: CGFloat = 0

  /// Real iPhone Home Screen metrics, in points.
  private enum Metrics {
    static let screenWidth: CGFloat = 402
    static let visibleHeight: CGFloat = 575
    static let small: CGFloat = 158
    static let gap: CGFloat = 22
    static let medium = small * 2 + gap
    static let icon: CGFloat = 62
    static let iconSpacing = (medium - icon * 4) / 3
    static let margin: CGFloat = 16
    static let radius: CGFloat = 22
  }

  private var scale: CGFloat {
    guard width > 0 else { return 0.8 }
    return min(0.92, (width - 56) / Metrics.screenWidth)
  }

  private var stockSymbol: String? {
    symbols.isEmpty ? nil : symbols[stockIndex % symbols.count]
  }

  private var movers: [Quote] {
    MoversProvider.sorted(symbols.compactMap { quotes[$0] })
  }

  var body: some View {
    phone
      .frame(width: Metrics.screenWidth, height: Metrics.visibleHeight, alignment: .top)
      .scaleEffect(scale, anchor: .top)
      .frame(width: Metrics.screenWidth * scale, height: Metrics.visibleHeight * scale, alignment: .top)
      .frame(maxWidth: .infinity)
      .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
      .sensoryFeedback(.selection, trigger: planIndex)
      .sensoryFeedback(.selection, trigger: showsZones)
      .task { await liveUpdates() }
  }

  /// Plans flip and the stock widget tours your stocks, like their real timelines do, just faster.
  private func liveUpdates() async {
    guard !reduceMotion else { return }
    var tick = 0
    while !Task.isCancelled {
      try? await Task.sleep(for: .seconds(2.4))
      tick += 1
      withAnimation(.smooth) { planIndex += 1 }
      if tick.isMultiple(of: 2) {
        withAnimation(.smooth) { stockIndex += 1 }
      }
    }
  }

  // MARK: Phone

  private var phone: some View {
    ZStack(alignment: .top) {
      wallpaper
      VStack(spacing: 0) {
        statusBar
        VStack(alignment: .leading, spacing: 18) {
          HStack(alignment: .top, spacing: Metrics.gap) {
            labeled("Dipwise") {
              widget(width: Metrics.small, glow: statuses.isEmpty ? nil : statuses[planIndex % statuses.count].target.rule.kind.side.brandColor,
                     label: "Plans widget. Tap to see the next plan.") {
                PlansWidgetView(entry: PlansEntry(date: .now, statuses: statuses, index: planIndex), previewFamily: .systemSmall)
              } action: {
                withAnimation(.smooth) { planIndex += 1 }
                onInteract()
              }
            }
            labeled("Dipwise") {
              widget(width: Metrics.small, glow: movers.first.map { $0.change >= 0 ? Brand.buy : Brand.sell }, label: "Today's movers widget") {
                MoversWidgetView(entry: MoversEntry(date: .now, quotes: movers), previewFamily: .systemSmall)
              } action: {
                onInteract()
              }
            }
          }
          HStack(spacing: Metrics.iconSpacing) {
            AppIcon(label: "Dipwise", badge: 2) {
              Image(.appIconPreview).resizable()
            }
            AppIcon(label: "Calendar") { CalendarGlyph() }
            AppIcon(label: "Weather") {
              GlyphIcon(systemImage: "cloud.sun.fill", colors: [Color(red: 0.25, green: 0.55, blue: 0.95), Color(red: 0.12, green: 0.32, blue: 0.75)], symbolColors: true)
            }
            AppIcon(label: "Camera") {
              GlyphIcon(systemImage: "camera.fill", colors: [Color(white: 0.85), Color(white: 0.62)], foreground: Color(white: 0.2))
            }
          }
          labeled("Dipwise") {
            widget(width: Metrics.medium, glow: stockSymbol.flatMap { quotes[$0] }.map { $0.change >= 0 ? Brand.buy : Brand.sell },
                   label: "Stock plan widget. Tap to switch between chart and zones.") {
              StockPlanWidgetView(
                entry: StockPlanEntry(date: .now, symbol: stockSymbol, quote: stockSymbol.flatMap { quotes[$0] },
                                      targets: statuses.map(\.target).filter { $0.symbol == stockSymbol }),
                previewFamily: .systemMedium,
                previewShowsZones: showsZones
              )
              .id("\(stockSymbol ?? "")-\(showsZones)")
              .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } action: {
              withAnimation(.smooth) { showsZones.toggle() }
              onInteract()
            }
          }
          HStack(spacing: Metrics.iconSpacing) {
            AppIcon(label: "Mail") {
              GlyphIcon(systemImage: "envelope.fill", colors: [Color(red: 0.3, green: 0.65, blue: 1), Color(red: 0.1, green: 0.4, blue: 0.95)])
            }
            AppIcon(label: "Notes") {
              GlyphIcon(systemImage: "note.text", colors: [Color(red: 1, green: 0.86, blue: 0.35), Color(red: 0.98, green: 0.74, blue: 0.1)], foreground: .white)
            }
            AppIcon(label: "Maps") {
              GlyphIcon(systemImage: "map.fill", colors: [Color(red: 0.45, green: 0.82, blue: 0.5), Color(red: 0.2, green: 0.6, blue: 0.38)])
            }
            AppIcon(label: "Settings") {
              GlyphIcon(systemImage: "gearshape.fill", colors: [Color(white: 0.7), Color(white: 0.45)])
            }
          }
        }
        .padding(.top, 14)
      }
    }
    .frame(width: Metrics.screenWidth, height: Metrics.visibleHeight, alignment: .top)
    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 58, topTrailingRadius: 58, style: .continuous))
    .overlay {
      UnevenRoundedRectangle(topLeadingRadius: 58, topTrailingRadius: 58, style: .continuous)
        .strokeBorder(Color(white: 0.12), lineWidth: 10)
    }
    .overlay(alignment: .bottom) {
      // The phone fades into the page, so only the top of the Home Screen shows.
      LinearGradient(colors: [Brand.nightMiddle.opacity(0), Brand.nightMiddle], startPoint: .top, endPoint: .bottom)
        .frame(height: 120)
    }
  }

  private var wallpaper: some View {
    ZStack {
      LinearGradient(colors: [Color(red: 0.13, green: 0.2, blue: 0.45), Color(red: 0.36, green: 0.24, blue: 0.62), Color(red: 0.86, green: 0.45, blue: 0.42)],
                     startPoint: .top, endPoint: .bottom)
      RadialGradient(colors: [Color(red: 0.3, green: 0.85, blue: 0.75).opacity(0.45), .clear], center: UnitPoint(x: 0.15, y: 0.25), startRadius: 10, endRadius: 320)
    }
  }

  private var statusBar: some View {
    ZStack {
      HStack {
        Text("9:41")
          .font(.system(size: 17, weight: .semibold))
          .padding(.leading, 34)
        Spacer()
        HStack(spacing: 6) {
          Image(systemName: "cellularbars")
          Image(systemName: "wifi")
          Image(systemName: "battery.100percent")
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.trailing, 30)
      }
      Capsule()
        .fill(.black)
        .frame(width: 124, height: 36)
    }
    .foregroundStyle(.white)
    .frame(height: 54)
    .padding(.top, 10)
    .accessibilityHidden(true)
  }

  private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 5) {
      content()
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .accessibilityHidden(true)
    }
  }

  private func widget<Content: View>(width: CGFloat, glow: Color?, label: String, @ViewBuilder content: () -> Content, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      content()
        .padding(Metrics.margin)
        .frame(width: width, height: Metrics.small)
        .background { WidgetBackdrop(glow: glow) }
        .clipShape(.rect(cornerRadius: Metrics.radius, style: .continuous))
        // The widgets' own buttons and links stay inert; the whole widget is one tap target.
        .allowsHitTesting(false)
        .overlay { Color.clear.contentShape(.rect(cornerRadius: Metrics.radius)) }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
    }
    .buttonStyle(PressScaleStyle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(label)
  }
}

/// Shrinks slightly while pressed, like Home Screen icons and widgets.
struct PressScaleStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.94 : 1)
      .animation(.snappy(duration: 0.2), value: configuration.isPressed)
  }
}

/// An app icon with its name below, and an optional notification badge.
private struct AppIcon<Artwork: View>: View {
  var label: String
  var badge: Int = 0
  @ViewBuilder var artwork: Artwork

  var body: some View {
    VStack(spacing: 5) {
      artwork
        .frame(width: 62, height: 62)
        .clipShape(.rect(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        .overlay(alignment: .topTrailing) {
          if badge > 0 {
            Text("\(badge)")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(.white)
              .frame(minWidth: 24, minHeight: 24)
              .background(Color.red, in: .circle)
              .offset(x: 7, y: -7)
          }
        }
      Text(label)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .lineLimit(1)
    }
    .frame(width: 62)
    .accessibilityHidden(true)
  }
}

/// A generic icon: a gradient tile with a symbol.
private struct GlyphIcon: View {
  var systemImage: String
  var colors: [Color]
  var foreground: Color = .white
  var symbolColors = false

  var body: some View {
    ZStack {
      LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
      Image(systemName: systemImage)
        .font(.system(size: 28, weight: .semibold))
        .symbolRenderingMode(symbolColors ? .multicolor : .monochrome)
        .foregroundStyle(foreground)
    }
  }
}

/// A calendar icon showing today's weekday and date.
private struct CalendarGlyph: View {
  var body: some View {
    ZStack {
      Color.white
      VStack(spacing: -2) {
        Text(Date.now, format: .dateTime.weekday(.abbreviated))
          .font(.system(size: 11, weight: .semibold))
          .foregroundStyle(.red)
          .textCase(.uppercase)
        Text(Date.now, format: .dateTime.day())
          .font(.system(size: 32, weight: .light))
          .foregroundStyle(.black)
      }
    }
  }
}
