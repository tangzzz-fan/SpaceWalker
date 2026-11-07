import SwiftUI

/// 星座插画：Stellarium 现代星空文化的 Meuris 线描图。
///
/// 骨架线能回答「哪几颗星」，但回答不了「像什么」——人马座 29 段线摆在眼前，
/// 大多数人仍然看不出半人马。真正让人「一眼认出」的是插画，这也是 Stellarium
/// 千万用户熟悉的那一版形象。
///
/// 85 座有图，船尾、船帆、巨蛇三座没有（Stellarium 用整幅南船座/蛇夫座处理）。
enum ConstellationArt {
    /// Free Art License 1.3 要求的署名，必须随图出现。
    static let credit = "星座图 Stellarium / Johan Meuris · Free Art License"

    static func imageName(for abbreviation: String) -> String? {
        let name = "art-\(abbreviation)"
        guard UIImage(named: name) != nil else { return nil }
        return name
    }

    /// 直接摆在 bundle 根目录的 PNG 不在 asset catalog 里，
    /// `Image("art-Sgr")` 找不到，必须经 UIImage 转一道。
    static func image(for abbreviation: String) -> Image? {
        guard let image = UIImage(named: "art-\(abbreviation)") else { return nil }
        return Image(uiImage: image)
    }

    static var count: Int {
        Constellations.all.filter { imageName(for: $0.abbreviation) != nil }.count
    }
}

/// 只有线条、没有底色的一层白色图形。
///
/// 原图是黑底灰线（深色天文软件用的位图），直接摆进卡片会带上一块灰方块——
/// 因为提亮把黑底也提了。把亮度转成 alpha 之后，黑底彻底透明，线条浮在卡片上，
/// 与任何背景都不打架。原文件不动，改的只是渲染。
struct ConstellationArtFigure: View {
    var abbreviation: String
    var tint: Color = .white

    var body: some View {
        if let image = ConstellationArt.image(for: abbreviation) {
            tint
                .mask {
                    image
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .luminanceToAlpha()
                }
        }
    }
}

/// 识别卡里的方图：带一层极淡的底，让图形占位稳定。
struct ConstellationArtView: View {
    var abbreviation: String
    var size: CGFloat

    var body: some View {
        if ConstellationArt.imageName(for: abbreviation) != nil {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.14)
                    .fill(.white.opacity(0.035))
                ConstellationArtFigure(abbreviation: abbreviation, tint: .white.opacity(0.88))
                    .padding(size * 0.06)
            }
            .frame(width: size, height: size)
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.14)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
            .accessibilityHidden(true)
        }
    }
}
