import Foundation
import simd

enum SkyGroupKind: String, Equatable, Sendable {
    case mansion
    case asterism
    case constellation
    case curated

    var label: String {
        switch self {
        case .mansion: "二十八宿"
        case .asterism: "星官"
        case .constellation: "星座"
        case .curated: "组合"
        }
    }

    var order: Int {
        switch self {
        case .mansion: 0
        case .asterism: 1
        case .constellation: 2
        case .curated: 3
        }
    }
}

struct SkyGroup: Identifiable, Equatable, Sendable {
    var id: String
    var kind: SkyGroupKind
    var title: String
    var starNames: [String]
    var fengshenLord: String?
    var fengshenPerson: String?
    var lineCount: Int = 0

    var memberCount: Int {
        starNames.count
    }

    var isDrawable: Bool {
        lineCount > 0
    }

    var subtitle: String {
        isDrawable ? "\(memberCount) 颗可选 · \(lineCount) 段连线" : "\(memberCount) 颗可选"
    }

    var fengshenLine: String? {
        guard let lord = fengshenLord, let person = fengshenPerson else { return nil }
        return "封神 \(lord) · \(person)"
    }
}

enum SkyGroupIndex {
    static func groups(stars: [Star]) -> [SkyGroup] {
        let selectable = stars.filter(\.isSelectable)
        let byName = Dictionary(grouping: selectable, by: \.name).compactMapValues { $0.first }
        var result: [SkyGroup] = []

        let byHIP: [Int: Star] = Dictionary(
            stars.compactMap { star in star.hipparcos.map { ($0, star) } },
            uniquingKeysWith: { first, second in
                first.magnitude <= second.magnitude ? first : second
            }
        )
        for asterism in AsterismCatalog.all {
            let members = asterism.members.compactMap { byHIP[$0] }
            let chosen = members
                .filter(\.isSelectable)
                .sorted { $0.magnitude < $1.magnitude }
            guard !chosen.isEmpty else { continue }
            let entry = FengshenInfo.entry(forMansion: asterism.name)
            let lineCount = asterism.lines.reduce(0) { total, line in
                let resolved = line.filter { byHIP[$0] != nil }.count
                return total + max(resolved - 1, 0)
            }
            result.append(
                SkyGroup(
                    id: "asterism:\(asterism.id)",
                    kind: asterism.isMansion || entry != nil ? .mansion : .asterism,
                    title: asterism.name,
                    starNames: chosen.map(\.name),
                    fengshenLord: entry?.lord,
                    fengshenPerson: entry?.person,
                    lineCount: lineCount
                )
            )
        }

        for constellation in Constellations.all {
            let members = selectable
                .filter { $0.constellation == constellation.abbreviation }
                .sorted { $0.magnitude < $1.magnitude }
            guard members.count >= 3 else { continue }
            result.append(
                SkyGroup(
                    id: "constellation:\(constellation.abbreviation)",
                    kind: .constellation,
                    title: constellation.name,
                    starNames: members.map(\.name),
                    fengshenLord: nil,
                    fengshenPerson: nil
                )
            )
        }

        for (title, names) in StarFinder.curatedGroups {
            let members = names.compactMap { byName[$0] }
            guard members.count >= 2 else { continue }
            let covered = result.contains { group in
                title.hasPrefix(group.title) && Set(members.map(\.name)).isSubset(of: Set(group.starNames))
            }
            guard !covered else { continue }
            result.append(
                SkyGroup(
                    id: "curated:\(title)",
                    kind: .curated,
                    title: title,
                    starNames: members.map(\.name),
                    fengshenLord: nil,
                    fengshenPerson: nil
                )
            )
        }

        return result.sorted { first, second in
            if first.kind.order != second.kind.order {
                return first.kind.order < second.kind.order
            }
            if first.memberCount != second.memberCount {
                return first.memberCount > second.memberCount
            }
            return first.title < second.title
        }
    }

    static let queryAliases: [String: String] = [
        "北斗七星": "北斗",
        "北斗七": "北斗",
        "七姐妹": "昴宿",
        "七姊妹": "昴宿",
    ]

    static func search(_ groups: [SkyGroup], query raw: String, limit: Int = 12) -> [SkyGroup] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let query = queryAliases[trimmed] ?? trimmed

        var scored: [(group: SkyGroup, score: Int)] = []
        for group in groups {
            var best: Int?
            if group.title == query {
                best = 0
            } else if group.fengshenLord == query {
                best = 0
            } else if group.title.hasPrefix(query) {
                best = 1
            } else if group.fengshenPerson == query {
                best = 1
            } else if group.title.contains(query) {
                best = 2
            } else if let lord = group.fengshenLord, lord.contains(query) {
                best = 3
            } else if group.starNames.contains(where: {
                ChineseStarNames.chinese(for: $0)?.contains(query) == true
            }) {
                best = 4
            }
            if let best {
                scored.append((group, best))
            }
        }

        return scored
            .sorted { first, second in
                first.score == second.score
                    ? first.group.memberCount > second.group.memberCount
                    : first.score < second.score
            }
            .prefix(limit)
            .map(\.group)
    }

    static func anchor(_ group: SkyGroup, stars: [Star]) -> SIMD3<Float>? {
        let index = Dictionary(grouping: stars, by: \.name).compactMapValues { $0.first }
        var sum = SIMD3<Float>(0, 0, 0)
        var count = 0
        for name in group.starNames {
            guard let star = index[name] else { continue }
            sum += SkyPicker.direction(for: star)
            count += 1
        }
        guard count > 0, simd_length(sum) > 0.0001 else { return nil }
        return simd_normalize(sum)
    }

    static func brightest(_ group: SkyGroup, stars: [Star]) -> Star? {
        stars
            .filter { group.starNames.contains($0.name) }
            .min { $0.magnitude < $1.magnitude }
    }

    static func members(_ group: SkyGroup, stars: [Star], limit: Int = 5) -> [Star] {
        stars
            .filter { group.starNames.contains($0.name) }
            .sorted { $0.magnitude < $1.magnitude }
            .prefix(limit)
            .map { $0 }
    }
}
