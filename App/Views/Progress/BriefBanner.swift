import SwiftUI

/// The invitation to today's Daily Brief at the top of Home.
struct BriefBanner: View {
  var streak: Int
  var isDone: Bool
  var open: () -> Void

  var body: some View {
    Button(action: open) {
      HStack(spacing: 14) {
        LivelyOwl(hopsOnTap: false)
          .frame(width: 46, height: 53)
        VStack(alignment: .leading, spacing: 3) {
          Text(isDone ? "Brief done. See you tomorrow!" : "Your daily brief is ready")
            .font(.headline)
          Text(isDone ? "\(streak)-day streak. Tap to review again." : streak > 0 ? "1 minute · keep your \(streak)-day streak" : "1 minute · start a streak today")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: isDone ? "checkmark.circle.fill" : "play.circle.fill")
          .font(.title)
          .foregroundStyle(isDone ? Palette.buy : Palette.amber)
          .symbolEffect(.pulse, isActive: !isDone)
      }
      .padding(16)
      .cardStyle(cornerRadius: 24)
      .overlay {
        if !isDone {
          RoundedRectangle(cornerRadius: 24)
            .strokeBorder(Palette.amber.opacity(0.6), lineWidth: 2)
        }
      }
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
  }
}
