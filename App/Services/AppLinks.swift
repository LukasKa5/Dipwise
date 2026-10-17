import Foundation

/// Public URLs and contact details. The privacy policy is shown inside the app (PrivacyPolicyView); App Store
/// Connect also needs it hosted at a public URL. Terms use Apple's standard EULA.
enum AppLinks {
  static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
  static let supportEmail = "support@example.com"
}
