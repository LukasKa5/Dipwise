import Foundation

/// Bite-sized investing lessons for the Daily Brief.
struct OwlTip {
  var title: String
  var body: String

  static let all: [OwlTip] = [
    OwlTip(title: String(localized: "Zones beat single prices"), body: String(localized: "Nobody catches the exact bottom. A buy zone lets you act anywhere in a range you're happy with, instead of missing out by a few cents.")),
    OwlTip(title: String(localized: "Ladder into a position"), body: String(localized: "Splitting a buy into tiers, say a third at each level, lowers your average price if the dip deepens and still gets you in if it doesn't.")),
    OwlTip(title: String(localized: "Write down why"), body: String(localized: "A one-line reason on each alert keeps you honest. When it fires, you'll remember whether the plan still makes sense.")),
    OwlTip(title: String(localized: "Dips aren't always bargains"), body: String(localized: "A falling price can mean the business changed. Before you buy, ask: is this a sale, or a warning?")),
    OwlTip(title: String(localized: "Trailing stops protect gains"), body: String(localized: "A trailing stop follows the price up and alerts you if it falls a set amount from the peak, so a winner doesn't turn into a loser.")),
    OwlTip(title: String(localized: "The 200-day average"), body: String(localized: "Many long-term investors watch the 200-day average. Falling below it often signals a shift in trend worth a closer look.")),
    OwlTip(title: String(localized: "Time in the market"), body: String(localized: "Missing just a handful of the market's best days can cut long-term returns dramatically. Patience usually beats perfect timing.")),
    OwlTip(title: String(localized: "Keep cash for dips"), body: String(localized: "A buy zone is only useful if you have money ready. Set a budget for each zone so you know you can act.")),
    OwlTip(title: String(localized: "Know your concentration"), body: String(localized: "If one stock is more than a third of your portfolio, a bad day for it is a bad day for you. Check your allocation.")),
    OwlTip(title: String(localized: "Dividends compound"), body: String(localized: "Reinvested dividends have historically made up a large share of long-term stock returns. Small payouts add up.")),
    OwlTip(title: String(localized: "Don't chase"), body: String(localized: "If a stock flew past your sell zone, that's fine. Plans protect you from the regret of buying high on emotion.")),
    OwlTip(title: String(localized: "Big moves need context"), body: String(localized: "A 5% daily move is news. Check for earnings, guidance, or market-wide moves before you react.")),
    OwlTip(title: String(localized: "The crowd is a signal, not a rule"), body: String(localized: "When many investors cluster at one level, prices often react there. Use the flock to inform your plan, not replace it.")),
    OwlTip(title: String(localized: "Review, don't stare"), body: String(localized: "Checking prices all day leads to rash decisions. A daily glance and a solid plan is enough.")),
    OwlTip(title: String(localized: "Fees and taxes matter"), body: String(localized: "Frequent trading adds costs that quietly eat returns. Fewer, planned trades usually win.")),
    OwlTip(title: String(localized: "Rebalance on purpose"), body: String(localized: "Selling some winners to buy laggards keeps your risk where you want it. Sell zones make this automatic.")),
    OwlTip(title: String(localized: "Earnings season"), body: String(localized: "Prices can swing sharply around earnings reports. Consider wider zones or waiting until the dust settles.")),
    OwlTip(title: String(localized: "Average cost matters"), body: String(localized: "Track your average purchase price. It turns vague feelings into clear numbers about gains and losses.")),
    OwlTip(title: String(localized: "One plan per stock"), body: String(localized: "Before you own something, know where you'd buy more and where you'd take profit. That's a complete plan.")),
    OwlTip(title: String(localized: "Learn from your journal"), body: String(localized: "Look back at your Dip Journal. Did your dip buys work? Patterns in your own decisions are the best teacher.")),
  ]

  /// A different tip each day.
  static var today: OwlTip {
    let day = Calendar.current.ordinality(of: .day, in: .era, for: .now) ?? 0
    return all[day % all.count]
  }
}
