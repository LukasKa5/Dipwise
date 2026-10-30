import SwiftUI
import WidgetKit

/// Achievements and Dippy's outfits as one thing: every habit worth building is a badge, and the biggest ones dress
/// Dippy. A tile shows the reward itself, Dippy wearing it, so it's clear what each goal earns; once it's unlocked, one
/// tap puts it on, and he wears it everywhere, on widgets and Apple Watch too. The top hat comes with Pro.
struct AchievementsSection: View {
  var achievements: [Achievement]
  @Environment(SubscriptionManager.self) private var subscription
  @State private var equipped = DippyOutfit.equipped
  @State private var selected: Achievement?
  @State private var cheers = 0
  @State private var showsPaywall = false

  /// The habits, plus Pro, which earns the top hat.
  private var items: [Achievement] {
    achievements + [
      Achievement(id: "pro", title: String(localized: "Pro Member"), detail: String(localized: "Join Dipwise Pro."),
                  explanation: String(localized: "Every tool Dippy has, for investors who want the full picture. Pro members get the top hat."),
                  systemImage: "crown.fill", current: subscription.isPro ? 1 : 0, goal: 1),
    ]
  }

  var body: some View {
    let unlocked = items.filter(\.isUnlocked).count
    VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Achievements", subtitle: "\(unlocked) of \(items.count) unlocked · each outfit is a reward")
      wearing
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
        ForEach(items) { item in
          tile(item)
        }
      }
      flags
    }
    .sensoryFeedback(.success, trigger: cheers)
    .sheet(isPresented: $showsPaywall) { PaywallView() }
    .sheet(item: $selected) { item in
      AchievementDetail(achievement: item, equipped: $equipped, onWear: wear)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
  }

  private var wearing: some View {
    HStack(spacing: 16) {
      LivelyOwl(greeting: .blush)
        .environment(\.dippyOutfit, equipped)
        .frame(width: 80, height: 92)
        .id(equipped)
      VStack(alignment: .leading, spacing: 4) {
        Text(equipped == .none ? String(localized: "Just Dippy")
             : equipped.flag != nil ? String(localized: "Flying the flag of \(equipped.title)")
             : String(localized: "Wearing the \(equipped.title)"))
          .font(.headline)
        Text("Unlock an achievement to earn its outfit. Dippy wears it in the app, on widgets, and on your wrist.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
        if equipped != .none {
          Button("Take It Off") { wear(.none) }
            .font(.subheadline.weight(.semibold))
            .padding(.top, 2)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(16)
    .cardStyle()
  }

  private func tile(_ item: Achievement) -> some View {
    let reward = DippyOutfit.reward(for: item.id)
    let isWorn = reward != nil && reward == equipped
    return Button {
      selected = item
    } label: {
      VStack(spacing: 8) {
        Group {
          if let reward {
            OwlMark()
              .environment(\.dippyOutfit, reward)
              .frame(width: 56, height: 64)
              .opacity(item.isUnlocked ? 1 : 0.35)
          } else {
            ZStack {
              Circle()
                .fill(item.isUnlocked ? AnyShapeStyle(Palette.amber.gradient) : AnyShapeStyle(.quaternary))
              Image(systemName: item.systemImage)
                .font(.title2)
                .foregroundStyle(item.isUnlocked ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
            .frame(width: 56, height: 56)
            .frame(height: 64)
          }
        }
        .overlay(alignment: .topTrailing) {
          if !item.isUnlocked {
            Image(systemName: item.id == "pro" ? "crown.fill" : "lock.fill")
              .font(.caption.weight(.bold))
              .foregroundStyle(item.id == "pro" ? Palette.amber : .secondary)
          }
        }
        Text(item.title)
          .font(.caption.weight(.semibold))
          .multilineTextAlignment(.center)
          .lineLimit(2, reservesSpace: true)
          .minimumScaleFactor(0.8)
        if item.isUnlocked {
          Text(isWorn ? "Wearing" : (reward == nil ? "Unlocked" : "Tap to wear"))
            .font(.caption2.weight(.bold))
            .foregroundStyle(isWorn ? Palette.buy : .secondary)
        } else {
          ProgressView(value: item.progress)
            .tint(Palette.amber)
            .padding(.horizontal, 14)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .cardStyle(cornerRadius: 18)
      .overlay {
        RoundedRectangle(cornerRadius: 18).strokeBorder(isWorn ? Palette.green : .clear, lineWidth: 2.5)
      }
    }
    .buttonStyle(.plain)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(item.title)
    .accessibilityValue(item.isUnlocked ? (isWorn ? "Wearing its outfit" : "Unlocked") : "\(item.detail). \(item.progressLabel)")
  }

  /// Pro members can fly their country's flag.
  private var flags: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(title: "Fly Your Flag", subtitle: "Dippy, from wherever you invest") {
        if !subscription.isPro { ProBadge() }
      }
      .padding(.top, 10)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
        ForEach(DippyOutfit.flags) { flag in
          let isWorn = equipped == flag
          Button {
            if subscription.isPro {
              wear(isWorn ? .none : flag)
            } else {
              showsPaywall = true
            }
          } label: {
            VStack(spacing: 6) {
              OwlMark()
                .environment(\.dippyOutfit, flag)
                .frame(width: 60, height: 54)
              Text(flag.title)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .cardStyle(cornerRadius: 16)
            .overlay {
              RoundedRectangle(cornerRadius: 16).strokeBorder(isWorn ? Palette.green : .clear, lineWidth: 2.5)
            }
          }
          .buttonStyle(.plain)
          .accessibilityLabel(flag.title)
          .accessibilityValue(isWorn ? "Wearing" : (subscription.isPro ? "" : "Pro"))
        }
      }
    }
  }

  private func wear(_ outfit: DippyOutfit) {
    withAnimation(.bouncy) { equipped = outfit }
    DippyOutfit.equipped = outfit
    if outfit != .none {
      cheers += 1
      OwlCue.shared.play(.blush)
    }
    WidgetCenter.shared.reloadAllTimelines()
  }
}

/// One achievement: what it asks, why it matters, how close you are, and its outfit, ready to wear once unlocked.
private struct AchievementDetail: View {
  var achievement: Achievement
  @Binding var equipped: DippyOutfit
  var onWear: (DippyOutfit) -> Void
  @State private var showsPaywall = false

  private var reward: DippyOutfit? { DippyOutfit.reward(for: achievement.id) }

  var body: some View {
    ScrollView {
      VStack(spacing: 18) {
        if let reward {
          LivelyOwl(greeting: achievement.isUnlocked ? .blush : nil)
            .environment(\.dippyOutfit, reward)
            .frame(width: 120, height: 138)
            .opacity(achievement.isUnlocked ? 1 : 0.45)
            .padding(.top, 28)
        } else {
          ZStack {
            Circle().stroke(.quaternary, lineWidth: 6)
            Circle()
              .trim(from: 0, to: achievement.progress)
              .stroke(Palette.amber, style: StrokeStyle(lineWidth: 6, lineCap: .round))
              .rotationEffect(.degrees(-90))
            Circle()
              .fill(achievement.isUnlocked ? AnyShapeStyle(Palette.amber.gradient) : AnyShapeStyle(.quaternary))
              .padding(10)
            Image(systemName: achievement.systemImage)
              .font(.system(size: 38))
              .foregroundStyle(achievement.isUnlocked ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
          }
          .frame(width: 110, height: 110)
          .padding(.top, 28)
        }

        VStack(spacing: 6) {
          Text(achievement.title)
            .font(.title2.bold())
          Text(achievement.detail)
            .font(.headline)
            .foregroundStyle(Palette.amber)
            .multilineTextAlignment(.center)
          if let reward {
            Text("Reward: the \(reward.title)")
              .font(.subheadline.weight(.semibold))
              .foregroundStyle(.secondary)
          }
        }
        Text(achievement.explanation)
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .fixedSize(horizontal: false, vertical: true)
          .padding(.horizontal, 28)

        VStack(spacing: 6) {
          ProgressView(value: achievement.progress)
            .tint(Palette.amber)
          Text(achievement.progressLabel)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(achievement.isUnlocked ? Palette.buy : .secondary)
        }
        .padding(.horizontal, 40)

        if let reward {
          if achievement.isUnlocked {
            Button {
              onWear(equipped == reward ? .none : reward)
            } label: {
              Text(equipped == reward ? "Take It Off" : "Wear the \(reward.title)")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
          } else if reward.requiresPro {
            Button {
              showsPaywall = true
            } label: {
              Text("Unlock with Pro")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
          }
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.bottom, 24)
    }
    .background(Palette.canvas)
    .sheet(isPresented: $showsPaywall) { PaywallView() }
  }
}
