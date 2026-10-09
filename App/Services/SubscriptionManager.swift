import Foundation
import Observation
import StoreKit

/// Tracks Dipwise Pro entitlement through StoreKit 2.
@MainActor
@Observable
final class SubscriptionManager {
  static let monthlyID = "dipwise.pro.monthly"
  static let yearlyID = "dipwise.pro.yearly"
  static let productIDs = [monthlyID, yearlyID]

  private(set) var hasActiveSubscription = AlertSettings.isPro
  #if DEBUG
  /// Lets you try Pro features in the simulator, where sandbox purchases can't complete.
  var previewPro = UserDefaults.standard.bool(forKey: "previewPro") {
    didSet {
      UserDefaults.standard.set(previewPro, forKey: "previewPro")
      cacheProState()
    }
  }
  #endif

  private var updatesTask: Task<Void, Never>?

  var isPro: Bool {
    #if DEBUG
    hasActiveSubscription || previewPro
    #else
    hasActiveSubscription
    #endif
  }

  func start() {
    guard updatesTask == nil else { return }
    updatesTask = Task { [weak self] in
      for await update in Transaction.updates {
        if case .verified(let transaction) = update {
          await transaction.finish()
        }
        await self?.refreshEntitlements()
      }
    }
    Task { await refreshEntitlements() }
  }

  func refreshEntitlements() async {
    var active = false
    for await result in Transaction.currentEntitlements {
      if case .verified(let transaction) = result,
         Self.productIDs.contains(transaction.productID),
         transaction.revocationDate == nil {
        active = true
      }
    }
    hasActiveSubscription = active
    cacheProState()
  }

  func restore() async {
    try? await AppStore.sync()
    await refreshEntitlements()
  }

  private func cacheProState() {
    UserDefaults.standard.set(isPro, forKey: AlertSettings.isProKey)
  }
}
