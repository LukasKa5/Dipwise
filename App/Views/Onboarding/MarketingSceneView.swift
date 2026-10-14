#if DEBUG
import SwiftUI

/// Development only: shows the intro's Home Screen or lock screen full size, so App Store screenshots
/// can be captured from the same views. Launch with `-marketingScene widgets` or `-marketingScene lock`, or
/// `-marketingScene watch` to render the Apple Watch pages at high resolution.
struct MarketingSceneView: View {
  var scene: String

  @State private var model = OnboardingModel()
  @State private var isReady = false

  static var requestedScene: String? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "-marketingScene"), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
  }

  /// Dippy in several poses on pure green, so the screenshot compositor can cut him out.
  private var owls: some View {
    let poses: [(blink: Double, look: CGSize, rightEye: Double)] = [
      (0, .zero, 0),
      (0, CGSize(width: -1, height: 0), 0),
      (0, CGSize(width: 0.3, height: -0.9), 0),
      (1, .zero, 1),
      (1, .zero, 0),
      (0, CGSize(width: 1, height: 0.2), 0),
    ]
    return ZStack {
      Color(red: 0, green: 1, blue: 0)
      LazyVGrid(columns: [GridItem(.fixed(200)), GridItem(.fixed(200))], spacing: 40) {
        ForEach(poses.indices, id: \.self) { index in
          let pose = poses[index]
          OwlMark(blink: pose.blink, lookOffset: pose.look, rightEyeOpen: pose.rightEye)
            .frame(width: 170, height: 196)
            .frame(width: 200, height: 250)
        }
      }
    }
  }

  var body: some View {
    Group {
      if scene == "owls" {
        owls
      } else if isReady {
        if scene == "watch" {
          MarketingWatchRenders(model: model)
        } else if scene == "lock" {
          NotifyStep(model: model, showsScreenOnly: true)
        } else {
          WidgetShowcaseStep(model: model, showsScreenOnly: true)
        }
      } else {
        Brand.nightMiddle
      }
    }
    .ignoresSafeArea()
    .statusBarHidden()
    .environment(\.colorScheme, .dark)
    .task {
      await model.loadQuotes()
      for symbol in ["NVDA", "MSFT", "AAPL"] { model.toggle(symbol) }
      model.prepareZone()
      isReady = true
    }
  }
}
#endif
