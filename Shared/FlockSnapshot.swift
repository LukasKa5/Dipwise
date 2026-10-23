import Foundation

/// What the flock is doing, saved by the app so the Flock widgets can show it.
struct FlockSnapshot: Codable, Hashable {
  struct Pick: Codable, Hashable, Identifiable {
    var symbol: String
    var name: String
    var price: Double
    var currency: String
    var zoneLower: Double
    var zoneUpper: Double
    /// 0–100, how eager the crowd is to buy.
    var conviction: Int
    var watchers: Int

    var id: String { symbol }
    var isInZone: Bool { price <= zoneUpper && price >= zoneLower * 0.9 }
    /// How far above the crowd's zone the price is; zero inside it.
    var distance: Double { price <= zoneUpper ? 0 : price / zoneUpper - 1 }
  }

  struct Trend: Codable, Hashable, Identifiable {
    var symbol: String
    var alertsThisWeek: Int
    var buyShare: Double
    var id: String { symbol }
  }

  var picks: [Pick]
  var trending: [Trend]
  var bullShare: Double
  var investors: Int
  var alertsThisWeek: Int
  var updatedAt: Date

  private static let key = "flockSnapshot.v1"

  static func load() -> FlockSnapshot? {
    guard let data = AppGroup.defaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(FlockSnapshot.self, from: data)
  }

  func save() {
    AppGroup.defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
  }

  static let sample = FlockSnapshot(
    picks: [
      Pick(symbol: "NVDA", name: "NVIDIA", price: 176.2, currency: "USD", zoneLower: 168, zoneUpper: 178, conviction: 84, watchers: 412),
      Pick(symbol: "AMZN", name: "Amazon", price: 219.8, currency: "USD", zoneLower: 205, zoneUpper: 216, conviction: 77, watchers: 286),
      Pick(symbol: "AAPL", name: "Apple", price: 243.1, currency: "USD", zoneLower: 228, zoneUpper: 238, conviction: 71, watchers: 351),
    ],
    trending: [
      Trend(symbol: "AMD", alertsThisWeek: 122, buyShare: 0.72),
      Trend(symbol: "PLTR", alertsThisWeek: 110, buyShare: 0.74),
      Trend(symbol: "META", alertsThisWeek: 85, buyShare: 0.66),
    ],
    bullShare: 0.64,
    investors: 2_480,
    alertsThisWeek: 1_312,
    updatedAt: .now
  )
}
