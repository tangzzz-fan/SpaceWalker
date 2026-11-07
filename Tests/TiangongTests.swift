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
        let expected = TiangongLayout.labLengthDisplay / 2 + TiangongLayout.resourceLengthDisplay / 2
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
