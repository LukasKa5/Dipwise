import SwiftUI
import UIKit

/// A company's logo on a rounded tile, like the App Store's icons: white for most logos, the app's navy for logos that
/// are themselves white. Until the logo arrives, or if a ticker has none, a colorful monogram stands in, and the same
/// ticker always gets the same color.
struct TickerBadge: View {
  var symbol: String
  var size: CGFloat = 44
  @State private var logo: StockLogo?

  private var hue: Double {
    var hash: UInt64 = 5381
    for scalar in symbol.unicodeScalars { hash = (hash &* 33) &+ UInt64(scalar.value) }
    return Double(hash % 360) / 360
  }

  var body: some View {
    ZStack {
      if let logo {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
          .fill(logo.isLight ? Brand.nightMiddle : .white)
        Image(uiImage: logo.image)
          .resizable()
          .scaledToFit()
          // Logos drawn on their own square background fill the tile; the rest get a little room.
          .padding(logo.hasBackground ? 0 : size * 0.16)
          .clipShape(.rect(cornerRadius: size * 0.28, style: .continuous))
          .transition(.opacity)
      } else {
        Text(symbol.prefix(symbol.count > 4 ? 1 : 2))
          .font(.system(size: size * 0.36, weight: .heavy, design: .rounded))
          .foregroundStyle(.white)
          .minimumScaleFactor(0.5)
          .frame(width: size, height: size)
          .background(Color(hue: hue, saturation: 0.62, brightness: 0.72), in: .rect(cornerRadius: size * 0.28, style: .continuous))
      }
    }
    .frame(width: size, height: size)
    .overlay {
      RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
        .strokeBorder(.black.opacity(logo == nil ? 0 : 0.08), lineWidth: 0.5)
    }
    .accessibilityHidden(true)
    .task(id: symbol) {
      let loaded = await StockLogoStore.shared.logo(for: symbol)
      withAnimation(.smooth(duration: 0.2)) { logo = loaded }
    }
  }
}

/// A downloaded logo and whether it's mostly white, so it can sit on a dark tile instead.
struct StockLogo: Equatable {
  var image: UIImage
  var isLight: Bool
  /// True when the image comes with its own opaque background.
  var hasBackground: Bool
}

/// Fetches company logos once and keeps them in memory and on disk, so lists scroll without reloading.
actor StockLogoStore {
  static let shared = StockLogoStore()

  private var memory: [String: StockLogo] = [:]
  private var missing: Set<String> = []
  private let folder: URL = {
    let url = URL.cachesDirectory.appending(path: "Logos", directoryHint: .isDirectory)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }()

  func logo(for symbol: String) async -> StockLogo? {
    let key = symbol.uppercased()
    if let cached = memory[key] { return cached }
    if missing.contains(key) || key.hasPrefix("^") { return nil }
    let file = folder.appending(path: "\(key).png")
    var data = try? Data(contentsOf: file)
    if data == nil, let url = URL(string: "https://financialmodelingprep.com/image-stock/\(key).png") {
      if let (fetched, response) = try? await URLSession.shared.data(from: url),
         (response as? HTTPURLResponse)?.statusCode == 200, fetched.count > 200 {
        data = fetched
        try? fetched.write(to: file)
      }
    }
    guard let data, let image = UIImage(data: data) else {
      missing.insert(key)
      return nil
    }
    let opaque = Self.hasOpaqueCorners(image)
    let logo = StockLogo(image: image, isLight: !opaque && Self.isMostlyLight(image), hasBackground: opaque)
    memory[key] = logo
    return logo
  }

  /// True when all four corners are solid, meaning the logo brings its own background.
  private static func hasOpaqueCorners(_ image: UIImage) -> Bool {
    guard let cgImage = image.cgImage else { return false }
    let side = 8
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
    let corners = [0, side - 1, side * (side - 1), side * side - 1]
    return corners.allSatisfy { pixels[$0 * 4 + 3] > 240 }
  }

  /// True when the logo's visible pixels are nearly all light, like Amazon's white smile.
  private static func isMostlyLight(_ image: UIImage) -> Bool {
    guard let cgImage = image.cgImage else { return false }
    let side = 24
    var pixels = [UInt8](repeating: 0, count: side * side * 4)
    guard let context = CGContext(data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
    var visible = 0.0, light = 0.0
    for index in stride(from: 0, to: pixels.count, by: 4) {
      let alpha = Double(pixels[index + 3]) / 255
      guard alpha > 0.5 else { continue }
      let luminance = (0.299 * Double(pixels[index]) + 0.587 * Double(pixels[index + 1]) + 0.114 * Double(pixels[index + 2])) / 255 / alpha
      visible += 1
      if luminance > 0.88 { light += 1 }
    }
    return visible > 0 && light / visible > 0.7
  }
}
