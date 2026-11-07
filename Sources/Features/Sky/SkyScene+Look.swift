import Foundation
import RealityKit
import simd
import SwiftUI

extension SkyScene {

    // MARK: - 外观

    func setConstellationsVisible(_ visible: Bool) {
        constellationsRequested = visible
        constellationNode?.isEnabled = visible
    }

    func setSilhouettesVisible(_ visible: Bool) {
        silhouettesRequested = visible
        silhouetteNode?.isEnabled = visible
    }

    /// 临时点亮一个星座：即使总开关关着，也让用户看见自己指着的那几条线。
    /// 亮的是骨架本身，不是外轮廓——用户问「为什么是它」，
    /// 答案应该落在「这几颗星连成这个形状」上，而不是一个把它们包起来的多边形。
    func highlightConstellation(_ abbreviation: String?) {
        guard abbreviation != constellationHighlightID else { return }
        constellationHighlightID = abbreviation
        constellationHighlightNode?.removeFromParent()
        constellationHighlightNode = nil
        guard let abbreviation,
              let constellation = Constellations.all.first(where: { $0.abbreviation == abbreviation })
        else { return }

        let positions = constellationPositions
        guard !positions.isEmpty else { return }
        let segments = constellation.lines.compactMap { line -> (SIMD3<Float>, SIMD3<Float>)? in
            guard let a = positions[line.first], let b = positions[line.second] else { return nil }
            let radius = Self.constellationHighlightRadius
            return (simd_normalize(a) * radius, simd_normalize(b) * radius)
        }
        SessionLog.append("sky.highlight id=\(abbreviation) lines=\(constellation.lines.count) pos=\(positions.count) segs=\(segments.count)")
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: 0.125),
                  name: "constellation.focus"
              )
        else { return }

        let node = Entity()
        node.name = "constellation.focus"
        node.components.set(ModelComponent(
            mesh: mesh,
            materials: [UnlitMaterial(color: uiColor(SIMD3(0.66, 0.78, 0.98), brightness: 1))]
        ))
        node.isEnabled = true
        field.addChild(node)
        constellationHighlightNode = node
    }



    func setAsterismsVisible(_ visible: Bool) {
        asterismsRequested = visible
        asterismNode?.isEnabled = visible
        asterismHighlightNode?.isEnabled = visible
    }

    func highlightAsterism(_ asterismID: String?) {
        guard let asterismID,
              let asterism = AsterismCatalog.all.first(where: { $0.id == asterismID })
        else {
            clearAsterismHighlight()
            return
        }
        guard asterismID != asterismHighlightID else { return }
        asterismHighlightID = asterismID
        asterismMaterial?.color.tint = uiColor(Self.asterismColor, brightness: Self.asterismDimBrightness)

        asterismHighlightNode?.removeFromParent()
        asterismHighlightNode = nil

        let segments = asterismSegments(for: asterism, radius: Self.asterismHighlightRadius3D)
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: Self.asterismHighlightRadius),
                  name: "asterism.highlight"
              )
        else { return }

        let node = Entity()
        node.name = "asterism.highlight"
        node.components.set(ModelComponent(
            mesh: mesh,
            materials: [UnlitMaterial(color: uiColor(Self.asterismColor, brightness: Self.asterismHighlightBrightness))]
        ))
        node.isEnabled = asterismsRequested
        field.addChild(node)
        asterismHighlightNode = node
    }

    func clearAsterismHighlight() {
        asterismHighlightID = nil
        asterismMaterial?.color.tint = uiColor(Self.asterismColor, brightness: Self.asterismBaseBrightness)
        asterismHighlightNode?.removeFromParent()
        asterismHighlightNode = nil
    }

    func setPatternsVisible(_ visible: Bool) {
        patternsRequested = visible
        patternNode?.isEnabled = visible
        patternHighlightNode?.isEnabled = visible
    }

    /// 临时点亮一条星群，其余星群压暗——和星官高亮同一套语言。
    func highlightPattern(_ id: String?) {
        guard id != patternHighlightID else { return }
        patternHighlightID = id
        patternHighlightNode?.removeFromParent()
        patternHighlightNode = nil
        patternMaterial?.color.tint = id == nil
            ? uiColor(Self.patternColor, brightness: Self.patternBaseBrightness)
            : uiColor(Self.patternColor, brightness: Self.patternDimBrightness)

        guard let id,
              let pattern = SkyPatternCatalog.pattern(id: id),
              !constellationPositions.isEmpty
        else { return }

        let segments = SkyPatternGeometry.segments(
            for: pattern,
            positions: constellationPositions,
            radius: Self.patternHighlightRadius3D
        )
        guard !segments.isEmpty,
              let mesh = try? StarFieldBuilder.mesh(
                  StarFieldBuilder.constellation(segments, radius: Self.patternHighlightTubeRadius),
                  name: "pattern.focus"
              )
        else { return }

        let node = Entity()
        node.name = "pattern.focus"
        node.components.set(ModelComponent(
            mesh: mesh,
            materials: [UnlitMaterial(
                color: uiColor(Self.patternColor, brightness: Self.patternHighlightBrightness)
            )]
        ))
        node.isEnabled = true
        field.addChild(node)
        patternHighlightNode = node
    }

    func attach(_ content: RealityViewCameraContent) {
        self.content = content
        installCamera()
    }

    /// 自建透视相机，为的是能改视场角。
    ///
    /// `content.camera = .virtual` 用的是系统默认 FOV，外部改不了；人马座跨 35°、
    /// 天鹅十字 30°，而竖屏默认视场只有三十几度，永远差一点装不下。
    /// 相机挂在 content 根上（不挂 field），因为星空转、相机不转。
    private func installCamera() {
        guard let content, cameraEntity == nil else { return }
        let entity = Entity()
        entity.name = "sky.camera"
        entity.components.set(PerspectiveCameraComponent(
            near: 0.05,
            far: 500,
            fieldOfViewInDegrees: fieldOfView
        ))
        content.add(entity)
        cameraEntity = entity
    }

    func setFieldOfView(_ degrees: Float) {
        let clamped = min(Self.maxFieldOfView, max(Self.minFieldOfView, degrees))
        guard abs(clamped - fieldOfView) > 0.05 else { return }
        fieldOfView = clamped
        guard let cameraEntity,
              var camera = cameraEntity.components[PerspectiveCameraComponent.self]
        else { return }
        camera.fieldOfViewInDegrees = clamped
        cameraEntity.components.set(camera)
    }

    var viewDirectionInField: SIMD3<Float> {
        (root.orientation * field.orientation).inverse.act(SIMD3<Float>(0, 0, -1))
    }

    func setField(orientation: simd_quatf) {
        field.orientation = orientation
    }

    /// 把视线转到某个方向。定位后要锁住，否则无陀螺仪时 `apply(rig:)`
    /// 会在下一次 RealityView 更新里把朝向拉回拖动状态。
    /// 把视线转到某个方向，并返回等价的拖动角度。
    ///
    /// 用 yaw/pitch 两轴构造，而不是 `simd_quatf(from:to:)`：后者取最短弧，
    /// 滚转角是任意的，定位到星座后整片天会歪着出现；而且它表达不出
    /// 拖动用的 yaw/pitch，一捏合 releaseAim 就会弹回旧角度。
    /// 调用方拿返回值同步 `rig`，交接就无缝了。
    @discardableResult
    func aim(at direction: SIMD3<Float>) -> SkyRig? {
        let length = simd_length(direction)
        guard length > 0.0001 else { return nil }
        let world = field.orientation.act(direction / length)
        let pitch = atan2(world.y, (world.x * world.x + world.z * world.z).squareRoot())
        let yaw = atan2(-world.x, -world.z)
        let rig = SkyRig(
            yaw: yaw,
            pitch: min(max(pitch, SkyRig.pitchRange.lowerBound), SkyRig.pitchRange.upperBound)
        )
        if source == .attitude, let base = attitudeBase {
            // 跟随中跳转：不动 base，把差量写成偏移，姿态继续驱动。
            aimDelta = base.inverse * (interfaceCompensation.inverse * rig.orientation)
            setAttitude(base)
        } else {
            root.orientation = rig.orientation
        }
        return rig
    }

    func setSource(_ source: InputSource) {
        self.source = source
    }

    /// 画布的「上」跟着界面方向转，设备坐标系的「上」不转。
    /// 不补偿的话，横屏后左右转头会变成画面上下动——用户看到的就是这个。
    var interfaceCompensation: simd_quatf {
        simd_quatf(angle: -interfaceRoll, axis: SIMD3<Float>(0, 0, 1))
    }

    func setAttitude(_ orientation: simd_quatf) {
        attitudeBase = orientation
        guard source == .attitude else { return }
        root.orientation = interfaceCompensation * orientation * aimDelta
    }

    func setInterfaceRoll(_ radians: Float) {
        guard abs(radians - interfaceRoll) > 0.001 else { return }
        interfaceRoll = radians
        if let base = attitudeBase, source == .attitude {
            setAttitude(base)
        }
    }

    /// 切到跟随时保持画面不跳：把当前朝向折成偏移量。
    func captureAimDelta(base: simd_quatf) {
        aimDelta = base.inverse * (interfaceCompensation.inverse * root.orientation)
    }

    func apply(rig: SkyRig) {
        guard source == .manual else { return }
        root.orientation = rig.orientation
    }
}
