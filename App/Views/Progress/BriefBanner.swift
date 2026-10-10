import SwiftUI

/// The invitation to today's Daily Brief at the top of Home. It disappears once done, and can be dismissed or turned off.
struct BriefBanner: View {
  var streak: Int
  var open: () -> Void
  var dismissForToday: () -> Void
  var turnOff: () -> Void

  var body: some View {
    HStack(spacing: 14) {
      Button(action: open) {
        HStack(spacing: 14) {
          LivelyOwl(hopsOnTap: false)
            .frame(width: 46, height: 53)
          VStack(alignment: .leading, spacing: 3) {
            Text("Your daily brief is ready")
              .font(.headline)
            Text(streak > 0 ? "1 minute · keep your \(streak)-day streak" : "1 minute · start a streak today")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          Spacer(minLength: 0)
          Image(systemName: "play.circle.fill")
            .font(.title)
            .foregroundStyle(Palette.amber)
            .symbolEffect(.pulse)
        }
        .contentShape(.rect)
      }
      .buttonStyle(.plain)

      Menu {
        Button("Not Today", systemImage: "moon.zzz", action: dismissForToday)
        Button("Turn Off Daily Brief", systemImage: "eye.slash", role: .destructive, action: turnOff)
      } label: {
        Image(systemName: "xmark")
          .font(.footnote.weight(.bold))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
          .background(.quaternary.opacity(0.6), in: .circle)
      }
      .accessibilityLabel("Hide daily brief")
    }
    .padding(16)
    .cardStyle(cornerRadius: 24)
  }
}
