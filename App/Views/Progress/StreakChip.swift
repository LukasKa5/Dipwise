import SwiftUI

/// Flame and day count shown in the Home toolbar, like a language-learning streak.
struct StreakChip: View {
  var streak: Int
  var isDoneToday: Bool

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "flame.fill")
        .foregroundStyle(isDoneToday ? AnyShapeStyle(Palette.amber) : AnyShapeStyle(.secondary))
        .symbolEffect(.bounce, value: streak)
      Text("\(streak)")
        .font(.headline.monospacedDigit())
        .contentTransition(.numericText())
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(streak)-day streak")
    .accessibilityHint(isDoneToday ? "Today's brief is done" : "Today's brief is waiting")
  }
}
