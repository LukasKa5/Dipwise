import SwiftUI

/// One anonymous investor from the flock: how they've done, how they invest, what they hold, and what they did lately.
/// Following them sends a notification when they add or trim a position.
struct InvestorView: View {
  var id: String

  @Environment(FlockService.self) private var flock
  @Environment(SubscriptionManager.self) private var subscription
  @State private var showsPaywall = false

  private var isPro: Bool { subscription.isPro }

  var body: some View {
    ScrollView {
      if let investor = flock.investor(id) {
        VStack(alignment: .leading, spacing: 20) {
          header(investor)
          stats(investor)
          holdings(investor)
          moves(investor)
          Text("Investors are anonymous members who chose to share their portfolio mix. Results are for today's holdings over the past 12 months and aren't advice.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
      } else {
        ContentUnavailableView("Investor Not Found", systemImage: "person.crop.circle.badge.questionmark",
                               description: Text("This investor stopped sharing their portfolio."))
      }
    }
    .background(Palette.canvas)
    .navigationTitle(flock.investor(id)?.nickname ?? "Investor")
    .navigationBarTitleDisplayMode(.inline)
    .sheet(isPresented: $showsPaywall) { PaywallView() }
  }

  private func header(_ investor: FlockInvestor) -> some View {
    HStack(spacing: 16) {
      InvestorAvatar(investor: investor, size: 72)
      VStack(alignment: .leading, spacing: 4) {
        Text(investor.nickname)
          .font(.title2.bold())
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(investor.yearReturn, format: .percent.precision(.fractionLength(1)).sign(strategy: .always()))
            .font(.title3.bold().monospacedDigit())
            .foregroundStyle(investor.yearReturn >= 0 ? Palette.gain : Palette.loss)
          Text("past 12 months")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 0)
    }
    .overlay(alignment: .topTrailing) {
      let isFollowing = flock.isFollowing(investor.id)
      Button(isFollowing ? "Following" : "Follow", systemImage: isFollowing ? "checkmark" : "bell.badge") {
        if isPro { flock.toggleFollow(investor.id) } else { showsPaywall = true }
      }
      .buttonStyle(.borderedProminent)
      .tint(isFollowing ? .secondary : Palette.green)
      .controlSize(.small)
      .sensoryFeedback(.selection, trigger: isFollowing)
    }
    .padding(.top, 8)
  }

  private func stats(_ investor: FlockInvestor) -> some View {
    let thisMonth = investor.moves.filter { Date.now.timeIntervalSince($0.date) < 30 * 24 * 3600 }
    return HStack(spacing: 10) {
      MiniStat(title: "Risk", value: "\(investor.riskScore) of 7")
      MiniStat(title: "Holdings", value: "\(investor.portfolio.positions.count)")
      MiniStat(title: "Moves this month", value: "\(thisMonth.count)")
    }
  }

  private func holdings(_ investor: FlockInvestor) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Portfolio mix")
          .font(.headline)
        Spacer()
        if !isPro { ProBadge() }
      }
      VStack(spacing: 10) {
        ForEach(Array(investor.portfolio.positions.enumerated()), id: \.element.symbol) { index, position in
          NavigationLink {
            FlockDetailView(symbol: position.symbol)
          } label: {
            HStack(spacing: 12) {
              TickerBadge(symbol: position.symbol, size: 32)
              Text(position.symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 70, alignment: .leading)
              GeometryReader { geometry in
                ZStack(alignment: .leading) {
                  Capsule().fill(.quaternary)
                  Capsule().fill(Palette.green.gradient)
                    .frame(width: max(6, geometry.size.width * position.weight / max(investor.portfolio.positions.first?.weight ?? 1, 0.01)))
                }
              }
              .frame(height: 8)
              Text(position.weight, format: .percent.precision(.fractionLength(0)))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(width: 44, alignment: .trailing)
            }
            .contentShape(.rect)
          }
          .buttonStyle(.plain)
          // The top holding is free to see; the full mix is Pro.
          .proLocked(!isPro && index >= 1, message: "See every holding with Pro", prompt: index == 1)
        }
      }
    }
    .padding(18)
    .cardStyle()
  }

  private func moves(_ investor: FlockInvestor) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Latest moves")
          .font(.headline)
        Spacer()
        if !isPro { ProBadge() }
      }
      if investor.moves.isEmpty {
        Text("No moves yet.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      VStack(spacing: 12) {
        ForEach(investor.moves.prefix(12)) { move in
          HStack(spacing: 12) {
            Image(systemName: move.isBuy ? "plus.circle.fill" : "minus.circle.fill")
              .font(.title3)
              .foregroundStyle(move.isBuy ? Palette.buy : Palette.sell)
            Text(move.isBuy ? "Added to \(move.symbol)" : "Trimmed \(move.symbol)")
              .font(.subheadline.weight(.semibold))
            Spacer()
            Text(move.date, format: .relative(presentation: .named))
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          .accessibilityElement(children: .combine)
        }
      }
      .proLocked(!isPro, message: "See every move and get notified with Pro")
    }
    .padding(18)
    .cardStyle()
  }
}
