import RealityKit
import UIKit

/// C 阶段的表面质感全部靠程序化贴图，仓库里不放任何图片资源（ADR-0005）。
/// 贴图只生成一次并缓存：`rebuild()` 每次进路由都会重建实体，跟着重建就会反复解码。
@MainActor
enum TiangongMaterials {
    enum Surface: String, CaseIterable {
        case mli
        case gold
        case cells
    }

    private(set) static var generationCount = 0
    private static var cache: [Surface: TextureResource] = [:]

    static func texture(_ surface: Surface) -> TextureResource? {
        if let cached = cache[surface] {
            return cached
        }
        guard let image = makeImage(surface) else { return nil }
        guard let resource = try? TextureResource(
            image: image,
            withName: "tiangong-\(surface.rawValue)",
            options: .init(semantic: .color)
        ) else {
            return nil
        }
        generationCount += 1
        cache[surface] = resource
        return resource
    }

    static func labBody() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = base(.white, .mli)
        material.roughness = .init(floatLiteral: 0.72)
        material.metallic = .init(floatLiteral: 0)
        return material
    }

    static func labCone() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.52, alpha: 1))
        material.roughness = .init(floatLiteral: 0.66)
        material.metallic = .init(floatLiteral: 0)
        return material
    }

    static func resource() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = base(UIColor(red: 0.95, green: 0.88, blue: 0.72, alpha: 1), .gold)
        material.roughness = .init(floatLiteral: 0.38)
        material.metallic = .init(floatLiteral: 0.85)
        return material
    }

    static func wing() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = base(UIColor(white: 1, alpha: 1), .cells)
        material.roughness = .init(floatLiteral: 0.28)
        material.metallic = .init(floatLiteral: 0.1)
        material.emissiveColor = .init(color: UIColor(red: 0.03, green: 0.05, blue: 0.12, alpha: 1))
        return material
    }

    static func spacecraft() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.86, alpha: 1))
        material.roughness = .init(floatLiteral: 0.5)
        material.metallic = .init(floatLiteral: 0.05)
        return material
    }

    static func capsule() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.6, alpha: 1))
        material.roughness = .init(floatLiteral: 0.46)
        material.metallic = .init(floatLiteral: 0.12)
        return material
    }

    /// 剖面内景：自发光。舱壁挡住太阳后舱内没有任何光源，
    /// 靠 PBR 会一律发黑；示意图本来就是"自亮"的，这里不自欺。
    static func interior(_ white: CGFloat) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        let tint = UIColor(white: white, alpha: 1)
        material.baseColor = .init(tint: tint)
        material.roughness = .init(floatLiteral: 0.8)
        material.metallic = .init(floatLiteral: 0)
        material.emissiveColor = .init(color: tint)
        material.emissiveIntensity = 0.3
        return material
    }

    /// 剖开的舱壁：内壁朝里，任何外部光都照不到，用无光照材质两面同色。
    static func cutawayShell() -> UnlitMaterial {
        UnlitMaterial(color: UIColor(white: 0.78, alpha: 1))
    }

    /// 阴影里的构件（基板背面、对接口内圈）：粗糙、非金属，避免被天空盒反射成亮片。
    static func inner() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: 0.30, alpha: 1))
        material.roughness = .init(floatLiteral: 0.85)
        material.metallic = .init(floatLiteral: 0)
        return material
    }

    static func hardware(_ white: CGFloat) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: UIColor(white: white, alpha: 1))
        material.roughness = .init(floatLiteral: 0.42)
        material.metallic = .init(floatLiteral: 0.65)
        return material
    }

    private static func base(_ tint: UIColor, _ surface: Surface) -> PhysicallyBasedMaterial.BaseColor {
        guard let resource = texture(surface) else {
            return .init(tint: tint)
        }
        return .init(tint: tint, texture: MaterialParameters.Texture(resource))
    }

    private static func makeImage(_ surface: Surface) -> CGImage? {
        let size = 512
        guard let context = CGContext(
            data: nil,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let extent = CGFloat(size)
        var random = SeededRandom(seed: 0x7A1_90C3)

        switch surface {
        case .mli:
            context.setFillColor(UIColor(white: 0.88, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: extent, height: extent))

            context.setStrokeColor(UIColor(white: 0.70, alpha: 1).cgColor)
            context.setLineWidth(2.5)
            for index in stride(from: 0, through: size, by: 64) {
                context.move(to: CGPoint(x: CGFloat(index), y: 0))
                context.addLine(to: CGPoint(x: CGFloat(index), y: extent))
            }
            context.strokePath()

            context.setStrokeColor(UIColor(white: 0.80, alpha: 1).cgColor)
            context.setLineWidth(1.2)
            for index in stride(from: 24, through: size, by: 128) {
                context.move(to: CGPoint(x: 0, y: CGFloat(index)))
                context.addLine(to: CGPoint(x: extent, y: CGFloat(index)))
            }
            context.strokePath()

            for _ in 0..<420 {
                let shade = 0.80 + CGFloat(random.nextUnit()) * 0.12
                context.setFillColor(UIColor(white: shade, alpha: 0.22).cgColor)
                context.fill(CGRect(
                    x: CGFloat(random.nextUnit()) * extent,
                    y: CGFloat(random.nextUnit()) * extent,
                    width: 3,
                    height: 3
                ))
            }

        case .gold:
            context.setFillColor(UIColor(red: 0.66, green: 0.50, blue: 0.19, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: extent, height: extent))

            for _ in 0..<70 {
                let bright = 0.45 + CGFloat(random.nextUnit()) * 0.5
                context.setStrokeColor(UIColor(red: bright, green: bright * 0.78, blue: bright * 0.34, alpha: 0.55).cgColor)
                context.setLineWidth(1 + CGFloat(random.nextUnit()) * 2.4)
                var point = CGPoint(
                    x: CGFloat(random.nextUnit()) * extent,
                    y: CGFloat(random.nextUnit()) * extent
                )
                context.move(to: point)
                for _ in 0..<4 {
                    point = CGPoint(
                        x: point.x + (CGFloat(random.nextUnit()) - 0.5) * 90,
                        y: point.y + (CGFloat(random.nextUnit()) - 0.5) * 90
                    )
                    context.addLine(to: point)
                }
                context.strokePath()
            }

            for _ in 0..<260 {
                let bright = 0.5 + CGFloat(random.nextUnit()) * 0.45
                context.setFillColor(UIColor(red: bright, green: bright * 0.8, blue: bright * 0.36, alpha: 0.16).cgColor)
                context.fill(CGRect(
                    x: CGFloat(random.nextUnit()) * extent,
                    y: CGFloat(random.nextUnit()) * extent,
                    width: 4,
                    height: 4
                ))
            }

        case .cells:
            context.setFillColor(UIColor(red: 0.07, green: 0.10, blue: 0.24, alpha: 1).cgColor)
            context.fill(CGRect(x: 0, y: 0, width: extent, height: extent))

            let columns = 8
            let rows = 8
            let cell = extent / CGFloat(columns)
            context.setStrokeColor(UIColor(red: 0.30, green: 0.38, blue: 0.55, alpha: 0.9).cgColor)
            context.setLineWidth(2)
            for index in 0...columns {
                let position = CGFloat(index) * cell
                context.move(to: CGPoint(x: position, y: 0))
                context.addLine(to: CGPoint(x: position, y: extent))
            }
            for index in 0...rows {
                let position = CGFloat(index) * cell
                context.move(to: CGPoint(x: 0, y: position))
                context.addLine(to: CGPoint(x: extent, y: position))
            }
            context.strokePath()

            context.setStrokeColor(UIColor(red: 0.55, green: 0.62, blue: 0.70, alpha: 0.8).cgColor)
            context.setLineWidth(6)
            context.stroke(CGRect(x: 3, y: 3, width: extent - 6, height: extent - 6))
        }

        return context.makeImage()
    }
}

private struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9 : seed
    }

    mutating func nextUnit() -> Float {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Float(state >> 40) / Float(1 << 24)
    }
}
