import XCTest
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

    func testCabinsAreAdjacentAtOrigin() {
        let gap = TiangongLayout.labCenter.z - TiangongLayout.resourceCenter.z
        // 实验舱中心现在落在密封舱的一半处（锥段在它前面），不再是整段的一半。
        let expected = TiangongLayout.labSealDisplay / 2 + TiangongLayout.resourceLengthDisplay / 2
        XCTAssertEqual(gap, expected, accuracy: 0.0001, "两舱应首尾相接")
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

final class TiangongHistoryTests: XCTestCase {
    /// 逐字对照 `docs/research/realitykit-ios26-primary-sources.md` 第 15 条。
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
