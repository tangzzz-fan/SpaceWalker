import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: extract_frames <video> <outdir> [fps]")
    exit(1)
}
let url = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
let fps = args.count > 3 ? Double(args[3]) ?? 30 : 30
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let asset = AVURLAsset(url: url)
let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
let duration = CMTimeGetSeconds(asset.duration)
print("duration=\(duration)")

var frameIndex = 0
var stats: [(Int, Double, Double)] = []
let step = 1.0 / fps
var t = 0.0
while t < duration {
    let time = CMTime(seconds: t, preferredTimescale: 600)
    do {
        let cg = try generator.copyCGImage(at: time, actualTime: nil)
        let name = String(format: "frame_%04d.png", frameIndex)
        let dest = outDir.appendingPathComponent(name)
        if let destIO = CGImageDestinationCreateWithURL(dest as CFURL, UTType.png.identifier as CFString, 1, nil) {
            CGImageDestinationAddImage(destIO, cg, nil)
            CGImageDestinationFinalize(destIO)
        }
        let (mean, white) = luminance(cg)
        stats.append((frameIndex, mean, white))
        frameIndex += 1
    } catch {
        print("skip t=\(t): \(error.localizedDescription)")
    }
    t += step
}
let csv = outDir.appendingPathComponent("luminance.csv")
let rows = stats.map { "\($0.0),\(String(format: "%.2f", $0.1)),\(String(format: "%.4f", $0.2))" }
try (["frame,meanLuma,whiteRatio"] + rows).joined(separator: "\n").write(to: csv, atomically: true, encoding: .utf8)
print("frames=\(frameIndex)")

func luminance(_ image: CGImage) -> (Double, Double) {
    let w = 64, h = 128
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    var pixels = [UInt8](repeating: 0, count: w * h * 4)
    guard let ctx = CGContext(
        data: &pixels, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
        space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return (-1, -1) }
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    var sum = 0.0
    var whiteCount = 0
    for i in stride(from: 0, to: pixels.count, by: 4) {
        let l = 0.2126 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.0722 * Double(pixels[i + 2])
        sum += l
        if l > 245 { whiteCount += 1 }
    }
    let n = Double(w * h)
    return (sum / n, Double(whiteCount) / n)
}