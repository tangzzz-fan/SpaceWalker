import Foundation
import simd

struct Asterism: Equatable, Sendable, Identifiable {
    var id: String
    var name: String
    var members: [Int]
    var lines: [[Int]]

    var isMansion: Bool {
        name.hasSuffix("宿")
    }

    var isDrawable: Bool {
        !lines.isEmpty
    }

    var segmentCount: Int {
        lines.reduce(0) { $0 + max($1.count - 1, 0) }
    }
}

enum AsterismCatalog {
    static let resourceName = "asterisms"
    static let all: [Asterism] = loadFromBundle()

    static func decode(_ data: Data) throws -> [Asterism] {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        return payload.asterisms.map {
            Asterism(id: $0.id, name: $0.name, members: $0.members, lines: $0.lines)
        }
    }

    static func loadFromBundle(_ bundle: Bundle = .main) -> [Asterism] {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? decode(data)
        else {
            return []
        }
        return catalog
    }

    private struct Payload: Decodable {
        var source: String
        var license: String
        var asterisms: [Entry]
    }

    private struct Entry: Decodable {
        var name: String
        var id: String
        var members: [Int]
        var lines: [[Int]]
    }
}
