import SwiftUI

extension View {
  /// Reports whether this device folds, as soon as it's known. Only iPhone Duo has a hinge.
  func onFoldableChange(_ action: @escaping (Bool) -> Void) -> some View {
    modifier(HingeObserver(action: action))
  }
}

private struct HingeObserver: ViewModifier {
  var action: (Bool) -> Void

  func body(content: Content) -> some View {
    if #available(iOS 27.1, *) {
      content.onHingeChange { _, context in action(context.hinge != nil) }
    } else {
      content
    }
  }
}
