import Foundation
import RealityKit
import simd
import SwiftUI

extension SkyScene {

    // MARK: - 查询

    /// 画填充用的闭合环：只认手工轮廓与美术图形。
    /// 没有显式轮廓的星座不画填充——凸包会把凹处填平，人马座的茶壶会变成一块饼，
    /// 形状一丢，人就认不出像什么了。骨架线本身已经够读。
    static func fillRings(
        for constellation: Constellation,
        positions: [String: SIMD3<Float>]
    ) -> [[SIMD3<Float>]] {
        if let figure = ConstellationFigures.all[constellation.abbreviation] {
            return ConstellationFigureBuilder.rings(figure, positions: positions)
        }
        if !constellation.outlines.isEmpty,
           constellation.outlines.allSatisfy({ ring in ring.allSatisfy { positions[$0] != nil } }) {
            return constellation.outlines.map { $0.compactMap { positions[$0] } }
        }
        if constellation.outline.count >= 3,
           constellation.outline.allSatisfy({ positions[$0] != nil }) {
            return [constellation.outline.compactMap { positions[$0] }]
        }
        return []
    }

    /// 判定用的闭合环：手工轮廓优先，缺了就退回成员星凸包。
    /// 凸包粗糙但一定闭合，用来回答「你正对着哪个星座」，不参与绘制。
    static func hitRings(
        for constellation: Constellation,
        positions: [String: SIMD3<Float>]
    ) -> [[SIMD3<Float>]] {
        let drawn = fillRings(for: constellation, positions: positions)
        if !drawn.isEmpty { return drawn }
        let names = Array(Set(constellation.lines.flatMap { [$0.first, $0.second] }))
        let points = names.compactMap { positions[$0] }
        guard points.count >= 3 else { return [] }
        return [StarFieldBuilder.hullRing(points)]
    }


    /// 点环方向落在哪个星座轮廓内。命中多个时取距离中心最近的一个。
    func constellation(at direction: SIMD3<Float>) -> Constellation? {
        var best: (key: String, dot: Float)?
        for shape in constellationShapes where shape.contains(direction) {
            let dot = simd_dot(simd_normalize(direction), shape.center)
            if best == nil || dot > best!.dot {
                best = (shape.key, dot)
            }
        }
        guard let best else { return nil }
        return Constellations.all.first { $0.abbreviation == best.key }
    }

    /// 点环方向落在哪个闭合星群内部。命中多个时取距离中心最近的一个。
    func pattern(at direction: SIMD3<Float>) -> SkyPattern? {
        var best: (key: String, dot: Float)?
        for shape in patternShapes where shape.contains(direction) {
            let dot = simd_dot(simd_normalize(direction), shape.center)
            if best == nil || dot > best!.dot {
                best = (shape.key, dot)
            }
        }
        guard let best else { return nil }
        return SkyPatternCatalog.pattern(id: best.key)
    }

    /// 星群几何中心方向，用于对准与调试。
    func direction(forPattern id: String) -> SIMD3<Float>? {
        guard let pattern = SkyPatternCatalog.pattern(id: id) else { return nil }
        let points = pattern.anchors.compactMap { constellationPositions[$0] }
        guard !points.isEmpty else { return nil }
        var sum = SIMD3<Float>(0, 0, 0)
        for point in points {
            sum += simd_normalize(point)
        }
        guard simd_length(sum) > 0.001 else { return nil }
        return simd_normalize(sum)
    }

    func pick(at point: CGPoint) -> Star? {
        guard let content else { return nil }
        var best: (star: Star, distance: CGFloat)?

        for star in nodes where star.isSelectable {
            guard let projected = project(star, in: content) else { continue }
            let distance = hypot(projected.x - point.x, projected.y - point.y)
            guard distance <= SkyPicker.crosshairRadius else { continue }
            if best == nil || distance < best!.distance {
                best = (star, distance)
            }
        }
        return best?.star
    }

    struct Candidates: Equatable {
        var star: Star?
        var constellation: Constellation?
        var pattern: SkyPattern?
    }

    /// 沿视线取候选。点环传中心方向；B 阶段的视锥选中传视锥内的若干方向，
    /// 共用这一个入口——视锥没有屏幕点，接口只能以方向为单位。
    func candidates(along direction: SIMD3<Float>) -> Candidates {
        Candidates(
            star: selectableStar(along: direction),
            constellation: constellation(at: direction),
            pattern: pattern(at: direction)
        )
    }

    func pickAtCenter() -> Star? {
        candidates(along: viewDirectionInField).star
    }

    private func selectableStar(along direction: SIMD3<Float>) -> Star? {
        guard viewSize.height > 1 else { return nil }
        guard let star = SkyPicker.nearest(to: direction, in: nodes, limit: 1).first else { return nil }
        // 准星半径是屏幕点，换算成角度才能与视场无关。换算要用投影焦距而不是线性近似：
        // 线性近似在 60° 视场下把 1.708° 算成 1.549°，圈边上的星会被准星拒绝、点选却接受。
        let focal = Double(viewSize.height) / 2 / tan(Double(fieldOfView) * .pi / 360)
        let tolerance = atan(Double(SkyPicker.crosshairRadius) / focal) * 180 / .pi
        guard SkyPicker.offsetDegrees(SkyPicker.direction(for: star), direction) <= tolerance else {
            return nil
        }
        return star
    }

    func renderedDirection(of star: Star) -> SIMD3<Float>? {
        let world = field.convert(position: StarField.position(for: star), to: nil)
        let length = simd_length(world)
        guard length > 0.0001 else { return nil }
        return world / length
    }

    /// 顶栏「当前天区」的答案。优先级与点环识别一致：星座轮廓 > 星群 > 最近成员星，
    /// 三档共用同一份轮廓数据，顶栏与标识卡才不会各说各话。
    ///
    /// 兜底不加角距门槛：6 等星表把全天盖满，实测任意方向到最近成员星最远 6.9°
    /// （p50 1.8°、p99 4.9°），加了也永远不会触发。
    func currentRegion() -> SkyRegion? {
        let direction = viewDirectionInField
        if let constellation = constellation(at: direction) {
            return ConstellationInfo
                .region(for: constellation.abbreviation, in: nodes)
                .map(SkyRegion.constellation)
        }
        if let pattern = pattern(at: direction) {
            return .pattern(pattern)
        }
        return ConstellationInfo
            .nearest(to: direction, in: nodes)
            .map(SkyRegion.constellation)
    }

    func guideVector(to star: Star) -> GuideVector? {
        guard let direction = renderedDirection(of: star) else { return nil }
        return SkyGuide.vector(to: direction)
    }

    func aimOffsetDegrees(of star: Star) -> Double {
        guard let direction = renderedDirection(of: star) else { return 180 }
        return SkyPicker.offsetDegrees(direction, Self.screenCenterDirection)
    }

    static let screenCenterDirection = SIMD3<Float>(0, 0, -1)

    func project(_ star: Star, in content: RealityViewCameraContent) -> CGPoint? {
        let world = field.convert(position: StarField.position(for: star), to: nil)
        return content.project(point: world, to: Self.space)
    }
}
