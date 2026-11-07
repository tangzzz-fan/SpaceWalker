import Foundation
import simd

struct Star: Equatable, Sendable {
    var rightAscensionHours: Double
    var declinationDegrees: Double
    var magnitude: Double
    var colorIndex: Double
    var name: String
    var constellation: String

    var isNamed: Bool {
        !name.isEmpty
    }

    var isSelectable: Bool {
        isNamed && magnitude <= StarField.selectableMagnitudeLimit
    }
}

struct StarCatalog: Equatable, Sendable {
    var source: String
    var license: String
    var stars: [Star]

    static let resourceName = "stars"

    static func decode(_ data: Data) throws -> StarCatalog {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return StarCatalog(
            source: payload.source,
            license: payload.license,
            stars: payload.stars.map {
                Star(
                    rightAscensionHours: $0.ra,
                    declinationDegrees: $0.dec,
                    magnitude: $0.mag,
                    colorIndex: $0.ci,
                    name: $0.name,
                    constellation: $0.con
                )
            }
        )
    }

    static func loadFromBundle(_ bundle: Bundle = .main) -> StarCatalog? {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? decode(data)
        else {
            return nil
        }
        return catalog
    }

    private struct Payload: Decodable {
        var source: String
        var license: String
        var stars: [Entry]
    }

    private struct Entry: Decodable {
        var ra: Double
        var dec: Double
        var mag: Double
        var ci: Double
        var name: String
        var con: String
    }
}

enum StarField {
    static let sphereRadius: Float = 50
    static let magnitudeLimit: Double = 5.5
    static let selectableMagnitudeLimit: Double = 4.5
    static let bucketEdges: [Double] = [-1.5, 0, 1, 2, 3, 4, 4.5]

    static func direction(
        rightAscensionHours: Double,
        declinationDegrees: Double
    ) -> SIMD3<Float> {
        let ra = rightAscensionHours / 24 * 2 * Double.pi
        let dec = declinationDegrees * Double.pi / 180
        return SIMD3(
            Float(cos(dec) * cos(ra)),
            Float(sin(dec)),
            Float(-cos(dec) * sin(ra))
        )
    }

    static func position(for star: Star, radius: Float = sphereRadius) -> SIMD3<Float> {
        direction(
            rightAscensionHours: star.rightAscensionHours,
            declinationDegrees: star.declinationDegrees
        ) * radius
    }

    static func bucketIndex(for magnitude: Double) -> Int {
        for (index, edge) in bucketEdges.enumerated().reversed() where magnitude >= edge {
            return min(index, bucketEdges.count - 2)
        }
        return 0
    }

    static func cubeSize(for magnitude: Double) -> Float {
        let size = 0.62 - Float(magnitude + 1.5) * 0.07
        return min(max(size, 0.12), 0.62)
    }

    static func color(forColorIndex index: Double) -> SIMD3<Float> {
        let clamped = min(max(index, -0.3), 2.0)
        let t = Float((clamped + 0.3) / 2.3)
        let warm = SIMD3<Float>(1.0, 0.82, 0.62)
        let cool = SIMD3<Float>(0.72, 0.82, 1.0)
        return cool + (warm - cool) * t
    }

    static func brightness(for magnitude: Double) -> Float {
        let normalized = Float((6.0 - magnitude) / 6.0)
        return min(max(normalized, 0.50), 1.0)
    }
}
