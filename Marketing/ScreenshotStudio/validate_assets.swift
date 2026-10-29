// Checks every App Store creative asset against App Store Connect's specifications before upload: header and search
// results images (exact pixel sizes, formats, no alpha) and header videos (3840 x 1646, 30 or 60 fps, 5-30 s, H.264
// or HEVC, one video track, no audio).  Usage: swift validate_assets.swift Marketing/AppStore

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Marketing/AppStore")
let imageSizes: [String: [(Int, Int)]] = [
    "Header": [(5244, 2950), (3840, 1646), (1500, 500)],
    "Search": [(3840, 2560), (5244, 2950)],
    "HeaderVideo": [(3840, 1646)],
]

var failures = 0
var checked = 0

func fail(_ path: String, _ reason: String) {
    failures += 1
    print("FAIL  \(path): \(reason)")
}

func relative(_ url: URL) -> String {
    String(url.path.dropFirst(root.path.count + 1))
}

func checkImage(_ url: URL, allowed: [(Int, Int)]) {
    checked += 1
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return fail(relative(url), "can't be read as an image")
    }
    if !allowed.contains(where: { $0 == (image.width, image.height) }) {
        fail(relative(url), "\(image.width) x \(image.height) is not an accepted size")
    }
    switch image.alphaInfo {
    case .none, .noneSkipFirst, .noneSkipLast: break
    default: fail(relative(url), "has an alpha channel")
    }
}

func checkVideo(_ url: URL) async {
    checked += 1
    let asset = AVURLAsset(url: url)
    do {
        let video = try await asset.loadTracks(withMediaType: .video)
        let audio = try await asset.loadTracks(withMediaType: .audio)
        guard video.count == 1, let track = video.first else { return fail(relative(url), "needs exactly one video track") }
        if !audio.isEmpty { fail(relative(url), "has an audio track") }
        let size = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let shown = size.applying(transform)
        if (Int(abs(shown.width)), Int(abs(shown.height))) != (3840, 1646) {
            fail(relative(url), "\(Int(abs(shown.width))) x \(Int(abs(shown.height))) instead of 3840 x 1646")
        }
        let formats = try await track.load(.formatDescriptions)
        if let format = formats.first {
            let coded = CMVideoFormatDescriptionGetDimensions(format)
            if (coded.width, coded.height) != (3840, 1646) {
                fail(relative(url), "encoded at \(coded.width) x \(coded.height)")
            }
            let codec = CMFormatDescriptionGetMediaSubType(format)
            if codec != kCMVideoCodecType_H264 && codec != kCMVideoCodecType_HEVC {
                fail(relative(url), "codec isn't H.264 or HEVC")
            }
        }
        let fps = try await track.load(.nominalFrameRate)
        if abs(fps - 30) > 0.01 && abs(fps - 60) > 0.01 { fail(relative(url), "\(fps) fps; needs 30 or 60") }
        let seconds = try await asset.load(.duration).seconds
        if seconds < 5 || seconds > 30 { fail(relative(url), "\(seconds) s; needs 5 to 30") }
    } catch {
        fail(relative(url), "can't be read as a video: \(error.localizedDescription)")
    }
}

let done = DispatchSemaphore(value: 0)
Task {
    let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
        .compactMap { $0 as? URL }
        .sorted { $0.path < $1.path }
    for url in files {
        let path = relative(url)
        guard let folder = path.split(separator: "/").first.map(String.init), let allowed = imageSizes[folder] else { continue }
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg": checkImage(url, allowed: allowed)
        case "mov", "mp4", "m4v": await checkVideo(url)
        default: continue
        }
    }
    print(failures == 0 ? "All \(checked) assets meet App Store Connect's specifications." : "\(failures) problem(s) in \(checked) assets.")
    done.signal()
}
done.wait()
exit(failures == 0 ? 0 : 1)
