import Foundation
import simd

struct ConstellationLine: Equatable, Sendable {
    var first: String
    var second: String
}

struct Constellation: Equatable, Sendable {
    var abbreviation: String
    var name: String
    var outline: [String] = []
    var lines: [ConstellationLine] = []
    /// 多环轮廓，用于本身分成几块的结构（如双子的两个人、金牛的脸与昴星团）。
    /// 非空时优先于 `outline`。
    var outlines: [[String]] = []

    var starCount: Int {
        Set(lines.flatMap { [$0.first, $0.second] }).count
    }
}

enum Constellations {
    static let primary: [Constellation] = [
        Constellation(abbreviation: "UMa", name: "大熊座", outline: ["Alkaid", "Mizar", "Alioth", "Megrez", "Dubhe", "Muscida", "Tania Borealis", "Tania Australis", "Phecda"], lines: line("Dubhe-Merak, Merak-Phecda, Phecda-Megrez, Megrez-Dubhe, Megrez-Alioth, Alioth-Mizar, Mizar-Alkaid, Dubhe-Muscida")),
        Constellation(abbreviation: "UMi", name: "小熊座", outline: ["Polaris", "Yildun", "Kochab", "Pherkad"], lines: line("Polaris-Kochab, Kochab-Pherkad, Pherkad-Polaris")),
        Constellation(abbreviation: "Ori", name: "猎户座", outline: ["Betelgeuse", "Bellatrix", "Mintaka", "Rigel", "Saiph", "Alnitak"], lines: line("Betelgeuse-Bellatrix, Bellatrix-Mintaka, Mintaka-Alnilam, Alnilam-Alnitak, Alnitak-Betelgeuse, Mintaka-Rigel, Alnitak-Saiph, Rigel-Saiph, Meissa-Betelgeuse, Meissa-Bellatrix")),
        Constellation(abbreviation: "Cas", name: "仙后座", outline: ["Caph", "Schedar", "Cih", "Ruchbah", "Segin"], lines: line("Caph-Schedar, Schedar-Cih, Cih-Ruchbah, Ruchbah-Segin")),
        Constellation(abbreviation: "Cyg", name: "天鹅座", outline: ["Deneb", "Aljanah", "Sadr", "Fawaris", "Albireo"], lines: line("Deneb-Sadr, Sadr-Albireo, Aljanah-Sadr, Sadr-Fawaris")),
        Constellation(abbreviation: "Lyr", name: "天琴座", outline: ["Vega", "Sheliak", "Sulafat"], lines: line("Vega-Sheliak, Sheliak-Sulafat, Sulafat-Vega")),
        Constellation(abbreviation: "Aql", name: "天鹰座", lines: line("Tarazed-Altair, Altair-Alshain, Altair-Okab")),
        Constellation(abbreviation: "Sco", name: "天蝎座", lines: line("Fang-Dschubba, Dschubba-Acrab, Dschubba-Antares, Antares-Alniyat, Alniyat-Larawag, Larawag-Sargas, Sargas-Shaula, Shaula-Lesath")),
        Constellation(abbreviation: "Leo", name: "狮子座", lines: line("Regulus-Algieba, Algieba-Adhafera, Adhafera-Rasalas, Regulus-Chertan, Chertan-Denebola, Denebola-Zosma, Zosma-Algieba")),
        Constellation(abbreviation: "Gem", name: "双子座", lines: line("Castor-Pollux, Castor-Mebsuta, Mebsuta-Tejat, Pollux-Wasat, Wasat-Alhena, Alhena-Alzirr"), outlines: [["Castor", "Mebsuta", "Tejat", "Propus"], ["Pollux", "Wasat", "Alhena", "Alzirr"]]),
        Constellation(abbreviation: "Tau", name: "金牛座", lines: line("Elnath-Aldebaran, Aldebaran-Tianguan, Aldebaran-Prima Hyadum, Prima Hyadum-Secunda Hyadum"), outlines: [["Ain", "Secunda Hyadum", "Prima Hyadum", "Aldebaran"], ["Alcyone", "Atlas", "Electra", "Maia", "Merope", "Taygeta"]]),
        Constellation(abbreviation: "Boo", name: "牧夫座", outline: ["Arcturus", "Izar", "Nekkar", "Seginus", "Muphrid"], lines: line("Arcturus-Izar, Izar-Seginus, Seginus-Nekkar, Nekkar-Arcturus, Arcturus-Muphrid")),
        Constellation(abbreviation: "Aur", name: "御夫座", lines: line("Capella-Menkalinan, Menkalinan-Mahasim, Mahasim-Hassaleh, Hassaleh-Capella, Capella-Almaaz, Hassaleh-Haedus")),
        Constellation(abbreviation: "CMa", name: "大犬座", outline: ["Furud", "Mirzam", "Sirius", "Adhara", "Wezen", "Aludra"], lines: line("Mirzam-Sirius, Sirius-Adhara, Adhara-Wezen, Wezen-Aludra, Wezen-Furud")),
        Constellation(abbreviation: "CMi", name: "小犬座", lines: line("Procyon-Gomeisa")),
        Constellation(abbreviation: "Cru", name: "南十字座", outline: ["Gacrux", "Mimosa", "Acrux", "Imai"], lines: line("Acrux-Gacrux, Mimosa-Imai")),
        Constellation(abbreviation: "Peg", name: "飞马座", lines: line("Markab-Scheat, Scheat-Alpheratz, Alpheratz-Algenib, Algenib-Markab, Markab-Homam, Homam-Enif"), outlines: [["Alpheratz", "Algenib", "Markab", "Scheat"], ["Markab", "Homam", "Enif", "Matar"]]),
        Constellation(abbreviation: "And", name: "仙女座", lines: line("Alpheratz-Mirach, Mirach-Almach, Almach-Nembus")),
        Constellation(abbreviation: "Per", name: "英仙座", lines: line("Mirfak-Algol, Mirfak-Miram, Mirfak-Atik, Atik-Misam")),
        Constellation(abbreviation: "Sgr", name: "人马座", outline: ["Alnasl", "Kaus Media", "Kaus Borealis", "Nunki", "Ascella", "Kaus Australis"], lines: line("Alnasl-Kaus Media, Kaus Media-Kaus Australis, Kaus Australis-Ascella, Ascella-Kaus Borealis, Kaus Borealis-Kaus Media, Ascella-Nunki")),
        Constellation(abbreviation: "Vir", name: "室女座", lines: line("Spica-Porrima, Porrima-Heze, Heze-Minelauva, Minelauva-Spica, Minelauva-Vindemiatrix")),
        Constellation(abbreviation: "Dra", name: "天龙座", lines: line("Eltanin-Rastaban, Rastaban-Grumium, Grumium-Edasich, Edasich-Altais, Altais-Thuban, Thuban-Aldhibah")),
        Constellation(abbreviation: "Her", name: "武仙座", lines: line("Rasalgethi-Kornephoros, Kornephoros-Sarin, Sarin-Rasalgethi")),
        Constellation(abbreviation: "Oph", name: "蛇夫座", lines: line("Rasalhague-Cebalrai, Cebalrai-Sabik, Sabik-Yed Prior, Yed Prior-Yed Posterior, Yed Prior-Marfik")),
        Constellation(abbreviation: "Ari", name: "白羊座", lines: line("Hamal-Sheratan, Sheratan-Mesarthim, Sheratan-Bharani")),
        Constellation(abbreviation: "Crv", name: "乌鸦座", lines: line("Gienah-Algorab, Algorab-Kraz, Kraz-Alchiba, Alchiba-Gienah")),
        Constellation(abbreviation: "Cet", name: "鲸鱼座", lines: line("Menkar-Kaffaljidhma, Kaffaljidhma-Baten Kaitos, Baten Kaitos-Diphda")),
        Constellation(abbreviation: "Lib", name: "天秤座", lines: line("Zubeneschamali-Zubenelgenubi, Zubenelgenubi-Brachium, Brachium-Zubenelhakrabi")),
        Constellation(abbreviation: "Cap", name: "摩羯座", lines: line("Algedi-Dabih, Dabih-Deneb Algedi, Deneb Algedi-Nashira")),
        Constellation(abbreviation: "Del", name: "海豚座", lines: line("Sualocin-Rotanev, Rotanev-Aldulfin")),
        Constellation(abbreviation: "Cep", name: "仙王座", lines: line("Alderamin-Alfirk, Alfirk-Errai, Errai-Alderamin")),
    ]

    /// 88 座全集。连线优先取 `detailedLines`（生成文件，d3-celestial 的 IAU 骨架），
    /// 缺的退回手工连线——英仙座有个顶点落在星表外 1.38°，只有它走手工。
    /// 手工那 31 座原来各自写 3–10 段，人马座只画出茶壶的壶身，换上官方骨架才立得住。
    static let all: [Constellation] = (primary + extended).map { constellation in
        var copy = constellation
        if let detailed = detailedLines[constellation.abbreviation] {
            copy.lines = detailed
        }
        return copy
    }

    static func line(_ raw: String) -> [ConstellationLine] {
        raw.split(separator: ",").compactMap { piece in
            let parts = piece.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { return nil }
            return ConstellationLine(first: parts[0], second: parts[1])
        }
    }

    static var segmentCount: Int {
        all.reduce(0) { $0 + $1.lines.count }
    }

    static var referencedKeys: Set<String> {
        Set(all.flatMap { $0.lines.flatMap { [$0.first, $0.second] } })
    }

    static func segments(
        positions: [String: SIMD3<Float>],
        in constellations: [Constellation] = all
    ) -> [(SIMD3<Float>, SIMD3<Float>)] {
        constellations.flatMap { constellation in
            constellation.lines.compactMap { line in
                guard let a = positions[line.first], let b = positions[line.second] else { return nil }
                return (a, b)
            }
        }
    }

    static func constellation(containing star: Star) -> Constellation? {
        all.first { $0.abbreviation == star.constellation }
    }
}
