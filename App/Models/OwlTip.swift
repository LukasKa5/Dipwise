import Foundation

/// Bite-sized investing lessons for the Daily Brief.
struct OwlTip {
  var title: String
  var body: String

  static let all: [OwlTip] = [
    OwlTip(title: "Zones beat single prices", body: "Nobody catches the exact bottom. A buy zone lets you act anywhere in a range you're happy with, instead of missing out by a few cents."),
    OwlTip(title: "Ladder into a position", body: "Splitting a buy into tiers, say a third at each level, lowers your average price if the dip deepens and still gets you in if it doesn't."),
    OwlTip(title: "Write down why", body: "A one-line reason on each alert keeps you honest. When it fires, you'll remember whether the plan still makes sense."),
    OwlTip(title: "Dips aren't always bargains", body: "A falling price can mean the business changed. Before you buy, ask: is this a sale, or a warning?"),
    OwlTip(title: "Trailing stops protect gains", body: "A trailing stop follows the price up and alerts you if it falls a set amount from the peak, so a winner doesn't turn into a loser."),
    OwlTip(title: "The 200-day average", body: "Many long-term investors watch the 200-day average. Falling below it often signals a shift in trend worth a closer look."),
    OwlTip(title: "Time in the market", body: "Missing just a handful of the market's best days can cut long-term returns dramatically. Patience usually beats perfect timing."),
    OwlTip(title: "Keep cash for dips", body: "A buy zone is only useful if you have money ready. Set a budget for each zone so you know you can act."),
    OwlTip(title: "Know your concentration", body: "If one stock is more than a third of your portfolio, a bad day for it is a bad day for you. Check your allocation."),
    OwlTip(title: "Dividends compound", body: "Reinvested dividends have historically made up a large share of long-term stock returns. Small payouts add up."),
    OwlTip(title: "Don't chase", body: "If a stock flew past your sell zone, that's fine. Plans protect you from the regret of buying high on emotion."),
    OwlTip(title: "Big moves need context", body: "A 5% daily move is news. Check for earnings, guidance, or market-wide moves before you react."),
    OwlTip(title: "The crowd is a signal, not a rule", body: "When many investors cluster at one level, prices often react there. Use the flock to inform your plan, not replace it."),
    OwlTip(title: "Review, don't stare", body: "Checking prices all day leads to rash decisions. A daily glance and a solid plan is enough."),
    OwlTip(title: "Fees and taxes matter", body: "Frequent trading adds costs that quietly eat returns. Fewer, planned trades usually win."),
    OwlTip(title: "Rebalance on purpose", body: "Selling some winners to buy laggards keeps your risk where you want it. Sell zones make this automatic."),
    OwlTip(title: "Earnings season", body: "Prices can swing sharply around earnings reports. Consider wider zones or waiting until the dust settles."),
    OwlTip(title: "Average cost matters", body: "Track your average purchase price. It turns vague feelings into clear numbers about gains and losses."),
    OwlTip(title: "One plan per stock", body: "Before you own something, know where you'd buy more and where you'd take profit. That's a complete plan."),
    OwlTip(title: "Learn from your journal", body: "Look back at your Dip Journal. Did your dip buys work? Patterns in your own decisions are the best teacher."),
  ]

  /// A different tip each day.
  static var today: OwlTip {
    let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
    return all[day % all.count]
  }
}
