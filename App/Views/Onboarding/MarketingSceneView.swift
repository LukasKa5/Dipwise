#if DEBUG
import SwiftUI

/// Development only: shows the intro's Home Screen or lock screen full size, so App Store screenshots
/// can be captured from the same views. Launch with `-marketingScene widgets` or `-marketingScene lock`.
struct MarketingSceneView: View {
  var scene: String

  @State private var model = OnboardingModel()
  @State private var isReady = false

  static var requestedScene: String? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "-marketingScene"), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
  }

  var body: some View {
    Group {
      if isReady {
        if scene == "lock" {
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
