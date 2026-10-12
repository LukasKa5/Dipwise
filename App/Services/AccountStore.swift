import AuthenticationServices
import CryptoKit
import Foundation
import Observation
import Security

/// Optional Sign in with Apple. Everything in Dipwise also works without an account.
@MainActor
@Observable
final class AccountStore {
  struct Account: Codable, Equatable {
    var userID: String
    var name: String
    var email: String?
  }

  private static let accountKey = "account.profile"
  private static let choiceKey = "account.choiceMade"

  private(set) var account: Account?
  private(set) var errorMessage: String?
  /// True once the user signed in or chose to continue without an account.
  private(set) var hasChosen: Bool

  init() {
    hasChosen = UserDefaults.standard.bool(forKey: Self.choiceKey)
    if let data = Keychain.read(Self.accountKey), let decoded = try? JSONDecoder().decode(Account.self, from: data) {
      account = decoded
    }
  }

  var isSignedIn: Bool { account != nil }
  var firstName: String? { account?.name.split(separator: " ").first.map(String.init) }

  func configure(_ request: ASAuthorizationAppleIDRequest) {
    request.requestedScopes = [.fullName, .email]
  }

  func handle(_ result: Result<ASAuthorization, Error>) {
    switch result {
    case .success(let authorization):
      guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
      // Apple only shares the name and email the first time, so keep what we already have.
      let name = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }.joined(separator: " ")
      let account = Account(
        userID: credential.user,
        name: name.isEmpty ? (self.account?.name ?? "") : name,
        email: credential.email ?? self.account?.email
      )
      save(account)
      errorMessage = nil
    case .failure(let error):
      if (error as? ASAuthorizationError)?.code == .canceled { return }
      errorMessage = "Sign in with Apple isn't available right now. You can keep using Dipwise without an account."
    }
  }

  func continueAsGuest() {
    hasChosen = true
    UserDefaults.standard.set(true, forKey: Self.choiceKey)
  }

  func signOut() {
    account = nil
    Keychain.delete(Self.accountKey)
  }

  /// Signs out if the user revoked Dipwise in their Apple Account settings.
  func refreshCredentialState() async {
    guard let userID = account?.userID else { return }
    let state = try? await ASAuthorizationAppleIDProvider().credentialState(forUserID: userID)
    if state == .revoked || state == .notFound { signOut() }
  }

  /// An anonymous, stable identifier for the flock, shared across the user's devices when signed in.
  var flockIdentity: String? {
    account.map { account in
      SHA256.hash(data: Data(account.userID.utf8)).map { String(format: "%02x", $0) }.joined()
    }
  }

  private func save(_ account: Account) {
    self.account = account
    hasChosen = true
    UserDefaults.standard.set(true, forKey: Self.choiceKey)
    if let data = try? JSONEncoder().encode(account) { Keychain.write(data, for: Self.accountKey) }
    if let identity = flockIdentity { UserDefaults.standard.set(identity, forKey: "flockInstallID") }
  }
}

/// A tiny wrapper for storing small values in the keychain.
private enum Keychain {
  static func write(_ data: Data, for key: String) {
    delete(key)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
    ]
    SecItemAdd(query as CFDictionary, nil)
  }

  static func read(_ key: String) -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: AnyObject?
    return SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess ? result as? Data : nil
  }

  static func delete(_ key: String) {
    let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrAccount as String: key]
    SecItemDelete(query as CFDictionary)
  }
}
