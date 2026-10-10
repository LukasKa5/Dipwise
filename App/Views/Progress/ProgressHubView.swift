import SwiftData
import SwiftUI

/// Streak calendar, level, achievements, and the Dip Journal's track record.
struct ProgressHubView: View {
  @Query(sort: \Holding.addedAt) private var holdings: [Holding]
  @Query(sort: \PriceAlert.journalDate, order: .reverse) private var alerts: [PriceAlert]
  @Environment(ProgressStore.self) private var progress
  @Environment(QuoteStore.self) private var quotes
  @Environment(Router.self) private var router
  @Environment(\.dismiss) private var dismiss
  @State private var selectedAchievement: Achievement?

  private var journal: [PriceAlert] { alerts.filter { $0.journalAction != nil && $0.holding != nil } }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 28) {
          streakCard
          levelCard
          achievements
          journalSection
        }
        .padding(20)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
      }
      .background(Palette.canvas)
      .navigationTitle("Your Progress")
      .sheet(item: $selectedAchievement) { item in
        AchievementDetailView(achievement: item)
          .presentationDetents([.medium])
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }

  private var streakCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 14) {
        Image(systemName: "flame.fill")
          .font(.system(size: 44))
          .foregroundStyle(progress.streak > 0 ? AnyShapeStyle(Palette.amber.gradient) : AnyShapeStyle(.tertiary))
        VStack(alignment: .leading, spacing: 2) {
          Text("\(progress.streak)-day streak")
            .font(.title2.bold())
          Text("Longest: \(progress.longestStreak) days")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
      }
      WeekStrip(progress: progress)
      if !progress.isBriefDoneToday {
        Button {
          dismiss()
          router.showsBrief = true
        } label: {
          Label("Do today's brief", systemImage: "play.fill")
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
      }
    }
    .padding(18)
    .cardStyle()
  }

  private var levelCard: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        LivelyOwl().frame(width: 44, height: 50)
        VStack(alignment: .leading, spacing: 2) {
          Text("Level \(progress.level)")
            .font(.headline)
          Text(progress.levelTitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Text("\(progress.xp) XP")
          .font(.headline.monospacedDigit())
          .foregroundStyle(Palette.amber)
      }
      ProgressView(value: progress.levelProgress)
        .tint(Palette.amber)
      Text("Earn XP by doing your daily brief, setting plans, voting, and logging decisions.")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding(18)
    .cardStyle()
  }

  private var achievements: some View {
    let items = Achievement.all(progress: progress, holdings: holdings, quotes: quotes.quotes)
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Achievements", subtitle: "\(items.filter(\.isUnlocked).count) of \(items.count) unlocked")
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
        ForEach(items) { item in
          Button {
            selectedAchievement = item
          } label: {
          VStack(spacing: 8) {
            ZStack {
              Circle()
                .trim(from: 0, to: item.progress)
                .stroke(Palette.amber, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
              Circle()
                .fill(item.isUnlocked ? AnyShapeStyle(Palette.amber.gradient) : AnyShapeStyle(.quaternary))
                .padding(6)
              Image(systemName: item.systemImage)
                .font(.title2)
                .foregroundStyle(item.isUnlocked ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
            .frame(width: 64, height: 64)
            Text(item.title)
              .font(.caption.weight(.semibold))
              .multilineTextAlignment(.center)
              .lineLimit(2)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .cardStyle(cornerRadius: 18)
          .accessibilityElement(children: .ignore)
          .accessibilityLabel(item.title)
          .accessibilityValue(item.isUnlocked ? "Unlocked" : "\(item.detail). \(item.progressLabel)")
          }
          .buttonStyle(.plain)
        }
      }
    }
  }

  private var journalSection: some View {
    let buys = journal.filter { $0.journalAction == .bought && $0.journalPrice > 0 }
    let returns = buys.compactMap { alert in quotes[alert.symbol].map { $0.price / alert.journalPrice - 1 } }
    return VStack(alignment: .leading, spacing: 14) {
      SectionHeader(title: "Dip Journal", subtitle: "What you did when your alerts fired")
      if journal.isEmpty {
        EmptyHint(systemImage: "book.closed", text: "When an alert fires, log whether you bought, sold, held, or skipped. Your own track record appears here.")
      } else {
        if !returns.isEmpty {
          HStack(spacing: 12) {
            MiniStat(title: "Your dip buys", value: (returns.reduce(0, +) / Double(returns.count)).formatted(.percent.precision(.fractionLength(1)).sign(strategy: .always())),
                     color: returns.reduce(0, +) >= 0 ? Palette.gain : Palette.loss)
            MiniStat(title: "In profit", value: (Double(returns.filter { $0 > 0 }.count) / Double(returns.count)).formatted(.percent.precision(.fractionLength(0))))
            MiniStat(title: "Decisions", value: "\(journal.count)")
          }
        }
        VStack(spacing: 0) {
          ForEach(journal.prefix(10)) { alert in
            HStack(spacing: 12) {
              TickerBadge(symbol: alert.symbol, size: 36)
              VStack(alignment: .leading, spacing: 2) {
                Text("\(alert.journalAction?.title ?? "") \(alert.symbol)")
                  .font(.headline)
                Text(alert.summary(for: quotes[alert.symbol]))
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
              Spacer()
              if alert.journalPrice > 0, let quote = quotes[alert.symbol] {
                VStack(alignment: .trailing, spacing: 2) {
                  Text("at \(quote.formatted(alert.journalPrice))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                  ChangeBadge(change: quote.price / alert.journalPrice - 1)
                    .font(.caption)
                }
              }
            }
            .padding(14)
            .accessibilityElement(children: .combine)
          }
        }
        .cardStyle()
      }
    }
  }
}

/// The last seven days, marked with flames or empty circles.
private struct WeekStrip: View {
  var progress: ProgressStore

  var body: some View {
    let calendar = Calendar.current
    let days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: .now) }
    HStack {
      ForEach(days, id: \.self) { day in
        VStack(spacing: 6) {
          Text(day, format: .dateTime.weekday(.narrow))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
          Group {
            if progress.wasCheckedIn(on: day) {
              Image(systemName: "flame.fill").foregroundStyle(Palette.amber)
            } else {
              Image(systemName: "circle").foregroundStyle(.quaternary)
            }
          }
          .font(.title3)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide)))
        .accessibilityValue(progress.wasCheckedIn(on: day) ? "Done" : "Missed")
      }
    }
  }
}

/// What an achievement means and how far along the user is.
private struct AchievementDetailView: View {
  var achievement: Achievement
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(spacing: 18) {
      ZStack {
        Circle()
          .stroke(.quaternary, lineWidth: 6)
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
          .symbolEffect(.bounce, value: achievement.isUnlocked)
      }
      .frame(width: 110, height: 110)
      .padding(.top, 28)

      VStack(spacing: 6) {
        Text(achievement.title)
          .font(.title2.bold())
        Text(achievement.detail)
          .font(.headline)
          .foregroundStyle(Palette.amber)
          .multilineTextAlignment(.center)
      }
      Text(achievement.explanation)
        .font(.body)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 28)

      VStack(spacing: 6) {
        ProgressView(value: achievement.progress)
          .tint(Palette.amber)
        Text(achievement.progressLabel)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(achievement.isUnlocked ? Palette.buy : .secondary)
      }
      .padding(.horizontal, 40)
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .background(Palette.canvas)
    .accessibilityElement(children: .combine)
  }
}
