import CoreGraphics
import Foundation
import ImageIO
import RealityKit
import SwiftUI

struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct StarSpec: Equatable, Sendable {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var brightness: CGFloat
}

enum GalaxyBackground {
    static let defaultWidth = 1024
    static let defaultHeight = 512

    static func stars(
        width: Int = defaultWidth,
        height: Int = defaultHeight,
        count: Int = 2_400,
        seed: UInt64 = 20_261_107
    ) -> [StarSpec] {
        guard width > 0, height > 0, count > 0 else { return [] }
        var generator = SplitMix64(seed: seed)
        return (0..<count).map { _ in
            StarSpec(
                x: CGFloat.random(in: 0..<CGFloat(width), using: &generator),
                y: CGFloat.random(in: 0..<CGFloat(height), using: &generator),
                radius: CGFloat.random(in: 0.4...1.7, using: &generator),
                brightness: CGFloat.random(in: 0.35...1.0, using: &generator)
            )
        }
    }

    static func makeEquirectangular(
        width: Int = defaultWidth,
        height: Int = defaultHeight,
        seed: UInt64 = 20_261_107
    ) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let bounds = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.setFillColor(CGColor(srgbRed: 0.012, green: 0.016, blue: 0.038, alpha: 1))
        context.fill(bounds)

        var generator = SplitMix64(seed: seed &+ 0x5EED)
        let palette: [(CGFloat, CGFloat, CGFloat)] = [
            (0.18, 0.10, 0.42),
            (0.05, 0.16, 0.36),
            (0.32, 0.11, 0.30),
            (0.06, 0.24, 0.34),
        ]

        for _ in 0..<22 {
            let centerX = CGFloat.random(in: 0...CGFloat(width), using: &generator)
            let centerY = CGFloat.random(in: 0...CGFloat(height), using: &generator)
            let radius = CGFloat.random(in: 90...300, using: &generator)
            let tint = palette[Int.random(in: 0..<palette.count, using: &generator)]
            let alpha = CGFloat.random(in: 0.04...0.14, using: &generator)
            let colors = [
                CGColor(srgbRed: tint.0, green: tint.1, blue: tint.2, alpha: alpha),
                CGColor(srgbRed: tint.0, green: tint.1, blue: tint.2, alpha: 0),
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else {
                continue
            }
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: centerX, y: centerY),
                startRadius: 0,
                endCenter: CGPoint(x: centerX, y: centerY),
                endRadius: radius,
                options: []
            )
        }

        let bandY = CGFloat(height) * 0.52
        for _ in 0..<3 {
            let spread = CGFloat.random(in: 40...120, using: &generator)
            let colors = [
                CGColor(srgbRed: 0.30, green: 0.34, blue: 0.55, alpha: 0.10),
                CGColor(srgbRed: 0.30, green: 0.34, blue: 0.55, alpha: 0),
            ] as CFArray
            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) else {
                continue
            }
            context.drawRadialGradient(
                gradient,
                startCenter: CGPoint(x: CGFloat(width) * 0.5, y: bandY),
                startRadius: 0,
                endCenter: CGPoint(x: CGFloat(width) * 0.5, y: bandY),
                endRadius: CGFloat(width) * 0.45,
                options: []
            )
            context.setFillColor(CGColor(srgbRed: 0.3, green: 0.34, blue: 0.55, alpha: 0.05))
            context.fill(CGRect(x: 0, y: bandY - spread / 2, width: CGFloat(width), height: spread))
        }

        for star in stars(width: width, height: height, seed: seed) {
            let tint = CGFloat.random(in: 0.85...1.0, using: &generator)
            context.setFillColor(
                CGColor(
                    srgbRed: star.brightness * tint,
                    green: star.brightness * tint,
                    blue: star.brightness * (0.9 + tint * 0.1),
                    alpha: 0.35 + star.brightness * 0.65
                )
            )
            let rect = CGRect(
                x: star.x - star.radius,
                y: star.y - star.radius,
                width: star.radius * 2,
                height: star.radius * 2
            )
            context.fillEllipse(in: rect)
        }

        return context.makeImage()
    }
}

@MainActor
enum SpaceEnvironment {
    static let resourceName = "galaxy"
    static let bundledAsset = "galaxy-equirect"

    static func load() -> RealityViewEnvironment? {
        if let image = bundledImage(), let environment = makeEnvironment(from: image) {
            return environment
        }
        guard let fallback = GalaxyBackground.makeEquirectangular() else { return nil }
        return makeEnvironment(from: fallback)
    }

    static func bundledImage() -> CGImage? {
        guard let url = Bundle.main.url(forResource: bundledAsset, withExtension: "jpg"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }
        return image
    }

    private static func makeEnvironment(from image: CGImage) -> RealityViewEnvironment? {
        guard let resource = try? EnvironmentResource(
            equirectangular: image,
            withName: resourceName
        ) else {
            return nil
        }
        return .skybox(resource)
    }
}
