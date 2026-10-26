import SwiftUI
import WidgetKit

/// Dippy's Wardrobe: outfits earned with achievements (and two that come with Pro). Tap one to try it on; Dippy
/// wears it everywhere, on widgets and Apple Watch too.
struct WardrobeSection: View {
  var achievements: [Achievement]
  @Environment(SubscriptionManager.self) private var subscription
  @State private var equipped = DippyOutfit.equipped
  @State private var showsPaywall = false
  @State private var hint: String?
  @State private var cheers = 0

  private func isUnlocked(_ outfit: DippyOutfit) -> Bool {
    if outfit.requiresPro { return subscription.isPro }
    guard let id = outfit.achievementID else { return true }
    return achievements.first { $0.id == id }?.isUnlocked ?? false
  }

  var body: some View {
    let unlocked = DippyOutfit.allCases.filter(isUnlocked).count
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Dippy's Wardrobe", subtitle: "\(unlocked) of \(DippyOutfit.allCases.count) outfits")
      HStack(spacing: 16) {
        LivelyOwl(greeting: .blush)
          .environment(\.dippyOutfit, equipped)
          .frame(width: 90, height: 104)
          .id(equipped)
        VStack(alignment: .leading, spacing: 4) {
          Text(equipped.title)
            .font(.title3.bold())
          Text(hint ?? "Earn outfits with good habits. Dippy wears his favorite in the app, on widgets, and on your wrist.")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .contentTransition(.opacity)
        }
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .cardStyle()

      LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 12)], spacing: 12) {
        ForEach(DippyOutfit.allCases) { outfit in
          let isOpen = isUnlocked(outfit)
          Button {
            select(outfit, isOpen: isOpen)
          } label: {
            VStack(spacing: 6) {
              OwlMark()
                .environment(\.dippyOutfit, outfit)
                .frame(width: 44)
                .frame(height: 74, alignment: .bottom)
                .opacity(isOpen ? 1 : 0.35)
                .overlay(alignment: .topTrailing) {
                  if !isOpen {
                    Image(systemName: outfit.requiresPro ? "crown.fill" : "lock.fill")
                      .font(.caption.weight(.bold))
                      .foregroundStyle(outfit.requiresPro ? Palette.amber : .secondary)
                  }
                }
              Text(outfit.title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .cardStyle(cornerRadius: 18)
            .overlay {
              RoundedRectangle(cornerRadius: 18).strokeBorder(equipped == outfit ? Palette.green : .clear, lineWidth: 2.5)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(outfit.title)
          .accessibilityValue(equipped == outfit ? "Wearing" : (isOpen ? "Unlocked" : "Locked"))
        }
      }
    }
    .sensoryFeedback(.success, trigger: cheers)
    .sheet(isPresented: $showsPaywall) { PaywallView() }
  }

  private func select(_ outfit: DippyOutfit, isOpen: Bool) {
    guard isOpen else {
      if outfit.requiresPro {
        showsPaywall = true
      } else if let id = outfit.achievementID, let achievement = achievements.first(where: { $0.id == id }) {
        withAnimation(.smooth) { hint = String(localized: "Unlock with \u{201C}\(achievement.title)\u{201D}: \(achievement.detail)") }
      }
      return
    }
    withAnimation(.bouncy) {
      equipped = outfit
      hint = nil
    }
    DippyOutfit.equipped = outfit
    cheers += 1
    OwlCue.shared.play(.blush)
    WidgetCenter.shared.reloadAllTimelines()
  }
}
