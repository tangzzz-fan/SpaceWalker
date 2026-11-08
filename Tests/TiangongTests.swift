import XCTest
import RealityKit
import simd

@testable import SpaceWalker

final class TiangongScaleTests: XCTestCase {
    func testScaleDividesByTwenty() {
        XCTAssertEqual(TiangongScale.display(10.4), 0.52, accuracy: 0.0001)
        XCTAssertEqual(TiangongScale.display(3.35), 0.1675, accuracy: 0.0001)
    }

    func testRoundTripsBackToRealMeters() {
        XCTAssertEqual(TiangongScale.real(TiangongScale.display(10.4)), 10.4, accuracy: 0.001)
    }

    /// 1:20 的整机（含太阳翼）必须落在 1m×1m 桌面内。
    func testFootprintFitsOnDesk() {
        let footprint = TiangongLayout.footprint
        XCTAssertLessThanOrEqual(footprint.length, 1.0, "全长越界：\(footprint.length)")
        XCTAssertLessThanOrEqual(footprint.width, 1.0, "翼展越界：\(footprint.width)")
    }

    /// 两舱在 z = 0 处相接：实验舱底面贴着资源舱顶面。
    func testCabinsMeetAtOrigin() {
        let labBottom = TiangongLayout.labCenter.z - TiangongLayout.labLengthDisplay / 2
        let resourceTop = TiangongLayout.resourceCenter.z + TiangongLayout.resourceLengthDisplay / 2
        XCTAssertEqual(labBottom, 0, accuracy: 0.0001, "实验舱底面应落在原点")
        XCTAssertEqual(resourceTop, 0, accuracy: 0.0001, "资源舱顶面应落在原点")
    }

    func testWingsSitSymmetricallyOnResourceCabin() {
        let left = TiangongLayout.wingCenter(.leftWing)
        let right = TiangongLayout.wingCenter(.rightWing)
        XCTAssertEqual(left.x, -right.x, accuracy: 0.0001)
        XCTAssertEqual(left.z, right.z, accuracy: 0.0001)
        XCTAssertEqual(left.z, TiangongLayout.resourceCenter.z, accuracy: 0.0001)
    }

    func testDismantlableModules() {
        XCTAssertEqual(TiangongModuleID.dismantlable.count, 4)
        XCTAssertEqual(Set(TiangongModuleID.dismantlable).count, 4)
        XCTAssertEqual(TiangongModuleID.allCases.count, 5)
    }
}

/// 064：分段、端面连续与对接基准。这些断言守的是「改几何别把玩法改坏」。
final class TiangongGeometryTests: XCTestCase {
    /// 实验舱必须是 前锥 + 圆柱 + 后锥，三段之和等于一手数据 6.4 m。
    func testLabSegmentsSumToTotal() {
        let sum = TiangongModel.labConeLength
            + TiangongModel.labSealLength
            + TiangongModel.labRearConeLength
        XCTAssertEqual(sum, TiangongModel.labLength, accuracy: 0.0001)
    }

    /// 三段在局部坐标里首尾相接：没有缝，也不重叠。
    func testLabSegmentsAreContiguous() {
        let rear = TiangongScale.display(TiangongModel.labRearConeLength)
        let seal = TiangongScale.display(TiangongModel.labSealLength)
        let cone = TiangongScale.display(TiangongModel.labConeLength)

        let rearRange = (
            TiangongLayout.labRearConeOffset - rear / 2,
            TiangongLayout.labRearConeOffset + rear / 2
        )
        let sealRange = (
            TiangongLayout.labCylinderOffset - seal / 2,
            TiangongLayout.labCylinderOffset + seal / 2
        )
        let coneRange = (
            TiangongLayout.labConeOffset - cone / 2,
            TiangongLayout.labConeOffset + cone / 2
        )

        XCTAssertEqual(rearRange.1, sealRange.0, accuracy: 0.0001, "后锥与圆柱之间有缝")
        XCTAssertEqual(sealRange.1, coneRange.0, accuracy: 0.0001, "圆柱与前锥之间有缝")
        XCTAssertEqual(rearRange.0, -TiangongLayout.labLengthDisplay / 2, accuracy: 0.0001)
        XCTAssertEqual(coneRange.1, TiangongLayout.labLengthDisplay / 2, accuracy: 0.0001)
    }

    /// 后锥段要真的收细：资源舱直径必须小于实验舱最大直径。
    func testRearConeBridgesBothDiameters() {
        let ratio = TiangongModel.resourceDiameter / TiangongModel.maxDiameter
        XCTAssertLessThan(TiangongModel.resourceDiameter, TiangongModel.maxDiameter)
        XCTAssertEqual(ratio, 0.828, accuracy: 0.005, "2.775 / 3.35，收细幅度约 17%")
        XCTAssertGreaterThan(TiangongModel.labRearConeLength, 0, "没有后锥段就是硬切台阶")
    }

    /// 对接基准是玩法参数，不许随几何改造漂移：2cm 容差就量在这个 z 上。
    func testDockingPortZIsPinned() {
        XCTAssertEqual(TiangongLayout.dockingPortZ, 0.36, accuracy: 0.0001)
    }

    /// 返回舱钟形：半径单调不增，宽端满径，窄端与轨道舱衔接。
    func testCapsuleProfileShrinksMonotonically() {
        let radii = TiangongModel.capsuleProfile.map(\.x)
        XCTAssertEqual(radii[0], 1, accuracy: 0.0001, "宽端应满径")
        for index in 1..<radii.count {
            XCTAssertLessThanOrEqual(radii[index], radii[index - 1] + 0.0001, "半径不该回涨")
        }
        XCTAssertEqual(
            radii.last!,
            TiangongModel.shenzhouOrbitalRatio,
            accuracy: 0.03,
            "窄端应与轨道舱直径衔接"
        )
    }

    /// 母线轴向比例要覆盖 0…1，否则旋转体会短一截。
    func testCapsuleProfileSpansFullLength() {
        let ticks = TiangongModel.capsuleProfile.map(\.y)
        XCTAssertEqual(ticks[0], 0, accuracy: 0.0001)
        XCTAssertEqual(ticks[ticks.count - 1], 1, accuracy: 0.0001)
        for index in 1..<ticks.count {
            XCTAssertGreaterThan(ticks[index], ticks[index - 1], "轴向比例必须递增")
        }
    }
}

@MainActor
final class TiangongSceneSegmentationTests: XCTestCase {
    private func axialRange(of entity: Entity, in parent: Entity) -> (Float, Float)? {
        guard let mesh = entity.components[ModelComponent.self]?.mesh else { return nil }
        let bounds = mesh.bounds
        let matrix = entity.transform.matrix
        var low = Float.greatestFiniteMagnitude
        var high = -Float.greatestFiniteMagnitude
        for xi in [-1, 1] {
            for yi in [-1, 1] {
                for zi in [-1, 1] {
                    let corner = SIMD4<Float>(
                        xi > 0 ? bounds.max.x : bounds.min.x,
                        yi > 0 ? bounds.max.y : bounds.min.y,
                        zi > 0 ? bounds.max.z : bounds.min.z,
                        1
                    )
                    let world = matrix * corner
                    low = min(low, world.z)
                    high = max(high, world.z)
                }
            }
        }
        return (low, high)
    }

    /// 实验舱必须是四个子件：后锥、圆柱、前锥、对接环。少一个就说明分段没生效。
    func testLabIsBuiltFromFourSegments() {
        let scene = TiangongScene()
        scene.build()
        guard let lab = scene.root.children.first(where: { $0.name == TiangongModuleID.lab.rawValue }) else {
            return XCTFail("没找到实验舱实体")
        }
        XCTAssertEqual(lab.children.count, 4, "应为 后锥 + 圆柱 + 前锥 + 对接环")
    }

    /// 三个舱段沿轴首尾相接：不许有缝，也不许重叠。这比截图更硬——不依赖光照。
    func testLabSegmentsTileTheAxis() {
        let scene = TiangongScene()
        scene.build()
        guard let lab = scene.root.children.first(where: { $0.name == TiangongModuleID.lab.rawValue }) else {
            return XCTFail("没找到实验舱实体")
        }

        let ranges = lab.children.compactMap { axialRange(of: $0, in: lab) }.sorted { $0.0 < $1.0 }
        XCTAssertEqual(ranges.count, 4)

        for index in 1..<3 {
            XCTAssertEqual(ranges[index].0, ranges[index - 1].1, accuracy: 0.0002, "第 \(index) 段与上一段之间有缝")
        }

        let half = TiangongLayout.labLengthDisplay / 2
        XCTAssertEqual(ranges[0].0, -half, accuracy: 0.0002, "后锥端面应在舱底")
        XCTAssertEqual(ranges[2].1, half, accuracy: 0.0002, "前锥端面应在舱顶")

        let port = ranges[3]
        XCTAssertEqual((port.0 + port.1) / 2, half, accuracy: 0.002, "对接环应落在舱顶平面上")
    }
}

final class TiangongHistoryTests: XCTestCase {    /// 逐字对照 `docs/research/realitykit-ios26-primary-sources.md` 第 15 条。
    func testFactsMatchPrimarySource() {
        XCTAssertEqual(TiangongHistory.name, "天宫一号")
        XCTAssertEqual(
            TiangongHistory.facts.map(\.value),
            [
                "2011-09-29",
                "中国首个目标飞行器 / 空间实验室",
                "与神舟八号、九号、十号共 6 次",
                "2016-03-16",
                "2018-04-02 · 南太平洋中部",
            ]
        )
    }

    /// PRD FR-C-01：界面不称其为「空间站」。
    func testNoForbiddenTermInUserFacingCopy() {
        var copy = [TiangongHistory.name, TiangongHistory.kind, TiangongHistory.summary]
        copy += TiangongHistory.facts.flatMap { [$0.label, $0.value] }
        copy += TiangongModuleID.allCases.flatMap { [$0.title, $0.detail] }

        for term in TiangongHistory.forbiddenTerms {
            for text in copy {
                XCTAssertFalse(text.contains(term), "「\(term)」出现在：\(text)")
            }
        }
    }
}

final class TiangongRigTests: XCTestCase {
    func testDistanceClampedBothWays() {
        var rig = TiangongRig()
        rig.dolly(scale: 0.001)
        XCTAssertEqual(rig.distance, TiangongRig.distanceRange.upperBound)

        rig.dolly(scale: 1000)
        XCTAssertEqual(rig.distance, TiangongRig.distanceRange.lowerBound)
    }

    func testPitchClampedBothWays() {
        var rig = TiangongRig()
        rig.rotate(deltaX: 0, deltaY: 10_000)
        XCTAssertEqual(rig.pitch, TiangongRig.pitchRange.upperBound)

        rig.rotate(deltaX: 0, deltaY: -20_000)
        XCTAssertEqual(rig.pitch, TiangongRig.pitchRange.lowerBound)
    }

    func testDefaultCameraLooksAtOriginFromAbove() {
        let position = TiangongRig().cameraPosition()
        XCTAssertGreaterThan(position.y, 0, "默认相机应在模型上方")
        XCTAssertEqual(simd_length(position), TiangongRig().distance, accuracy: 0.001)
    }
}

final class TiangongDisassemblyTests: XCTestCase {
    /// 四个模块各沿自己的装配轴外移固定距离。
    func testSeparatedPositionsMoveAlongOwnAxis() {
        for id in TiangongModuleID.dismantlable {
            let rest = TiangongLayout.restPosition(id)
            let apart = TiangongDisassembly.separatedPosition(id)
            let delta = apart - rest
            XCTAssertEqual(simd_length(delta), TiangongDisassembly.offset, accuracy: 0.0001, id.rawValue)
            XCTAssertEqual(simd_normalize(delta), TiangongDisassembly.axis(id), id.rawValue)
        }
    }

    /// 轴两两不同：四个模块不能朝同一个方向飞出去。
    func testAxesAreDistinct() {
        let axes = TiangongModuleID.dismantlable.map { TiangongDisassembly.axis($0) }
        for i in axes.indices {
            for j in axes.indices where j > i {
                XCTAssertNotEqual(axes[i], axes[j], "轴重复：\(i) 与 \(j)")
            }
        }
    }

    func testShenzhouIsNotDismantlable() {
        XCTAssertFalse(TiangongDisassembly.isDismantlable(.shenzhou))
        XCTAssertEqual(TiangongDisassembly.separatedPosition(.shenzhou), TiangongLayout.shenzhouCenter)
    }

    /// 复位必须回到绝对初值：连续拆装不能累积漂移。
    func testRestPositionIsAbsolute() {
        let first = TiangongLayout.restPosition(.lab)
        for _ in 0..<10 {
            _ = TiangongDisassembly.separatedPosition(.lab)
        }
        XCTAssertEqual(TiangongLayout.restPosition(.lab), first)
    }
}

final class TiangongAssemblyTests: XCTestCase {
    private let target = TiangongLayout.restPosition(.lab)

    func testSnapsAtExactPosition() {
        XCTAssertEqual(
            TiangongAssembly.verdict(module: .lab, at: target, port: .lab),
            .snap(target)
        )
    }

    /// 三种单条件缺失各一条，缺一不通过。
    func testRejectsWrongPort() {
        guard case .reject(.wrongPort, _) = TiangongAssembly.verdict(module: .lab, at: target, port: .resource) else {
            return XCTFail("错误接口必须被拒绝")
        }
    }

    func testRejectsTooFar() {
        let far = target + SIMD3<Float>(0, 0, TiangongAssembly.distanceTolerance * 1.5)
        guard case .reject(.tooFar, let push) = TiangongAssembly.verdict(module: .lab, at: far, port: .lab) else {
            return XCTFail("超距必须被拒绝")
        }
        XCTAssertEqual(simd_length(push), 1, accuracy: 0.001, "排斥方向必须是单位向量")
    }

    func testRejectsBadAngle() {
        guard case .reject(.badAngle, _) = TiangongAssembly.verdict(
            module: .lab,
            at: target,
            angleDegrees: TiangongAssembly.angleTolerance + 1,
            port: .lab
        ) else {
            return XCTFail("超角必须被拒绝")
        }
    }

    /// 容差边界：刚好在内通过，刚好在外拒绝。
    func testToleranceBoundary() {
        let inside = target + SIMD3<Float>(0, 0, TiangongAssembly.distanceTolerance * 0.99)
        if case .reject = TiangongAssembly.verdict(module: .lab, at: inside, port: .lab) {
            XCTFail("容差内应当吸附")
        }

        let outside = target + SIMD3<Float>(0, 0, TiangongAssembly.distanceTolerance * 1.01)
        if case .snap = TiangongAssembly.verdict(module: .lab, at: outside, port: .lab) {
            XCTFail("容差外不该吸附")
        }
    }

    /// 同一输入两次结果一致：判定里不许有随机或物理。
    func testVerdictIsDeterministic() {
        let position = target + SIMD3<Float>(0.01, 0, 0)
        let first = TiangongAssembly.verdict(module: .lab, at: position, port: .lab)
        for _ in 0..<20 {
            XCTAssertEqual(TiangongAssembly.verdict(module: .lab, at: position, port: .lab), first)
        }
    }

    /// 1pt 对应的世界长度随距离线性变化，与视场成正比。
    func testMetersPerPointScalesWithDistance() {
        let near = TiangongAssembly.metersPerPoint(distance: 1, fieldOfViewDegrees: 50, screenHeight: 852)
        let far = TiangongAssembly.metersPerPoint(distance: 3, fieldOfViewDegrees: 50, screenHeight: 852)
        XCTAssertEqual(far / near, 3, accuracy: 0.001)
        XCTAssertEqual(TiangongAssembly.metersPerPoint(distance: 1, fieldOfViewDegrees: 50, screenHeight: 0), 0)
    }
}

final class TiangongDockingTests: XCTestCase {
    private func input(
        z: Float = 0,
        x: Float = 0,
        y: Float = 0,
        angle: Float = 0,
        speed: Float = 0,
        elapsed: TimeInterval = 0,
        holding: TimeInterval = 0
    ) -> TiangongDocking.Input {
        TiangongDocking.Input(
            offset: SIMD3(x, y, z),
            angleDegrees: angle,
            speed: speed,
            angularSpeed: 0,
            elapsed: elapsed,
            holding: holding
        )
    }

    /// 远离对接口时只报「还在接近」，不做任何失败判定。
    func testFarAwayIsApproaching() {
        XCTAssertEqual(TiangongDocking.judge(input(z: 0.4), delta: 0.1), .approaching)
    }

    /// 进入 2cm 后要稳住 1 秒才算成功。
    func testHoldThenDock() {
        XCTAssertEqual(TiangongDocking.judge(input(holding: 0), delta: 0.4), .holding(0.4))
        XCTAssertEqual(TiangongDocking.judge(input(holding: 0.9), delta: 0.2), .docked)
    }

    func testFourFailures() {
        XCTAssertEqual(TiangongDocking.judge(input(speed: 0.03), delta: 0.1), .failed(.tooFast))
        XCTAssertEqual(TiangongDocking.judge(input(x: 0.05), delta: 0.1), .failed(.offAxis))
        XCTAssertEqual(TiangongDocking.judge(input(angle: 6), delta: 0.1), .failed(.tooSteep))
        XCTAssertEqual(TiangongDocking.judge(input(elapsed: 90), delta: 0.1), .failed(.timeout))
    }

    /// 每类失败有专属文案，互不混淆。
    func testFailureMessagesAreDistinct() {
        let messages = [TiangongDocking.Failure.tooFast, .offAxis, .tooSteep, .timeout].map(\.message)
        XCTAssertEqual(Set(messages).count, 4)
    }

    /// 容差边界：刚好在内通过，刚好在外失败。
    func testToleranceBoundary() {
        let insideZ = TiangongDocking.axialTolerance * 0.99
        let outsideZ = TiangongDocking.axialTolerance * 1.01
        XCTAssertEqual(TiangongDocking.judge(input(z: insideZ), delta: 0.1), .holding(0.1))
        XCTAssertEqual(TiangongDocking.judge(input(z: outsideZ), delta: 0.1), .approaching)

        let insideX = TiangongDocking.axialTolerance * 0.99
        let outsideX = TiangongDocking.axialTolerance * 1.01
        if case .failed = TiangongDocking.judge(input(x: insideX, holding: 0), delta: 0.1) {
            XCTFail("横向在容差内不该失败")
        }
        XCTAssertEqual(TiangongDocking.judge(input(x: outsideX, holding: 0), delta: 0.1), .failed(.offAxis))
    }

    func testDeterministic() {
        let sample = input(z: 0.01, x: 0.01, angle: 2, speed: 0.01, holding: 0.5)
        let first = TiangongDocking.judge(sample, delta: 0.1)
        for _ in 0..<20 {
            XCTAssertEqual(TiangongDocking.judge(sample, delta: 0.1), first)
        }
    }

    /// 精调档的位移是粗调的 1/4。
    func testFineModeIsQuarterSensitivity() {
        let drag = CGSize(width: 100, height: 0)
        let coarse = TiangongDocking.offsetDelta(drag: drag, magnification: 1, mode: .coarse, metersPerPoint: 0.001)
        let fine = TiangongDocking.offsetDelta(drag: drag, magnification: 1, mode: .fine, metersPerPoint: 0.001)
        XCTAssertEqual(fine.x / coarse.x, 0.25, accuracy: 0.0001)
    }
}

final class TiangongMissionTests: XCTestCase {
    func testStartsAtDisassembly() {
        let state = TiangongMission.start()
        XCTAssertEqual(state.phase, .disassembly)
        XCTAssertEqual(state.separatedCount, 0)
    }

    /// 四个模块全拆完才进装配。
    func testNeedsAllFourBeforeAssembly() {
        var state = TiangongMission.start()
        state = TiangongMission.separated(state, count: 3)
        XCTAssertEqual(state.phase, .disassembly)
        state = TiangongMission.separated(state, count: 4)
        XCTAssertEqual(state.phase, .assembly)
    }

    /// 全部装回才进对接。
    func testNeedsZeroSeparatedBeforeDocking() {
        var state = TiangongMission.start()
        state = TiangongMission.separated(state, count: 4)
        state = TiangongMission.separated(state, count: 1)
        XCTAssertEqual(state.phase, .assembly)
        state = TiangongMission.separated(state, count: 0)
        XCTAssertEqual(state.phase, .docking)
    }

    /// 失败原因直接引用判定文案，不另造。
    func testFailureUsesJudgeCopy() {
        var state = TiangongMission.start()
        state = TiangongMission.separated(state, count: 4)
        state = TiangongMission.separated(state, count: 0)
        state = TiangongMission.docking(state, outcome: .failed(.tooFast))
        XCTAssertEqual(state.phase, .docking)
        XCTAssertEqual(state.failure, TiangongDocking.Failure.tooFast.message)
    }

    func testDockedCompletes() {
        var state = TiangongMission.start()
        state = TiangongMission.separated(state, count: 4)
        state = TiangongMission.separated(state, count: 0)
        state = TiangongMission.docking(state, outcome: .docked)
        XCTAssertEqual(state.phase, .complete)
        XCTAssertNil(state.failure)
    }

    /// 重玩清空进度，但不改拆解目标数。
    func testReplayClearsProgress() {
        var state = TiangongMission.start()
        state = TiangongMission.separated(state, count: 4)
        state = TiangongMission.docking(state, outcome: .failed(.timeout))
        let replay = TiangongMission.replay(state)
        XCTAssertEqual(replay.phase, .disassembly)
        XCTAssertEqual(replay.separatedCount, 0)
        XCTAssertNil(replay.failure)
        XCTAssertEqual(replay.disassemblyTarget, state.disassemblyTarget)
    }

    /// 只有对接阶段才接受对接结果，别的阶段送进来不该改动状态。
    func testDockingOutcomeIgnoredBeforeDockingPhase() {
        let state = TiangongMission.start()
        XCTAssertEqual(TiangongMission.docking(state, outcome: .docked), state)
    }
}

@MainActor
final class TiangongShipAttitudeTests: XCTestCase {
    /// 双指旋转的角度一半给偏航、一半给俯仰。
    func testRotationSplitsBetweenYawAndPitch() {
        let session = TiangongSession()
        session.beginDocking()
        session.rotateShip(degrees: 10)
        XCTAssertEqual(session.shipYaw, 5, accuracy: 0.001)
        XCTAssertEqual(session.shipPitch, 5, accuracy: 0.001)
    }

    func testRotationClampedBothWays() {
        let session = TiangongSession()
        session.beginDocking()
        session.rotateShip(degrees: 1000)
        XCTAssertEqual(session.shipYaw, 30, accuracy: 0.001)
        session.rotateShip(degrees: -2000)
        XCTAssertEqual(session.shipYaw, -30, accuracy: 0.001)
    }

    func testRotationIgnoredOutsideDocking() {
        let session = TiangongSession()
        session.rotateShip(degrees: 20)
        XCTAssertEqual(session.shipYaw, 0)
    }

    /// 姿态偏差进入判定：超过 5° 时接触必失败。
    func testSteepAngleFailsDocking() {
        XCTAssertEqual(
            TiangongDocking.judge(
                TiangongDocking.Input(offset: .zero, angleDegrees: 6, speed: 0),
                delta: 0.1
            ),
            .failed(.tooSteep)
        )
    }
}

@MainActor
final class TiangongClosureTests: XCTestCase {
    /// 拆完四个进装配，再逐个装回，最后一个触发合拢并进入对接阶段。
    func testClosureOnLastModuleReturned() {
        let session = TiangongSession()
        for id in TiangongModuleID.dismantlable {
            session.toggleDisassembly(id)
        }
        XCTAssertEqual(session.mission.phase, .assembly)

        for id in TiangongModuleID.dismantlable.dropLast() {
            session.toggleDisassembly(id)
        }
        XCTAssertEqual(session.mission.phase, .assembly, "还没装完不该进对接")

        session.toggleDisassembly(TiangongModuleID.dismantlable.last!)
        XCTAssertEqual(session.mission.phase, .docking)
        XCTAssertTrue(session.separated.isEmpty)
    }

    /// 中途又拆一个，不该误触发。
    func testNoClosureWhenReopening() {
        let session = TiangongSession()
        for id in TiangongModuleID.dismantlable {
            session.toggleDisassembly(id)
        }
        session.toggleDisassembly(.lab)
        XCTAssertEqual(session.mission.phase, .assembly)
    }
}
