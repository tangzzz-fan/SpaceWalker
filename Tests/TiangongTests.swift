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
        let segments: Set<String> = ["lab-rear-cone", "lab-seal", "lab-cone", "port"]
        let present = lab.children.filter { segments.contains($0.name) }
        XCTAssertEqual(present.count, 4, "应为 后锥 + 圆柱 + 前锥 + 对接环")
    }

    /// 三个舱段沿轴首尾相接：不许有缝，也不许重叠。这比截图更硬——不依赖光照。
    func testLabSegmentsTileTheAxis() {
        let scene = TiangongScene()
        scene.build()
        guard let lab = scene.root.children.first(where: { $0.name == TiangongModuleID.lab.rawValue }) else {
            return XCTFail("没找到实验舱实体")
        }

        let segments: Set<String> = ["lab-rear-cone", "lab-seal", "lab-cone", "port"]
        let ranges = lab.children
            .filter { segments.contains($0.name) }
            .compactMap { axialRange(of: $0, in: lab) }
            .sorted { $0.0 < $1.0 }
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
    /// 每翼必须是四块电池板：一手文字「一对 4 块」，参考图的分格也在这个量级。
    func testEachWingHasFourPanels() {
        let scene = TiangongScene()
        scene.build()
        for id in [TiangongModuleID.leftWing, .rightWing] {
            guard let wing = scene.root.children.first(where: { $0.name == id.rawValue }) else {
                return XCTFail("没找到 \(id.rawValue)")
            }
            let panels = wing.children.filter { $0.name.hasPrefix("panel-") }
            XCTAssertEqual(panels.count, TiangongModel.wingPanelCount, id.rawValue)
            XCTAssertNotNil(wing.children.first { $0.name == "hinge" }, "缺根部铰链")
            XCTAssertNotNil(wing.children.first { $0.name == "spine" }, "缺纵梁")
        }
    }

    /// 分格不能吃掉翼展：最外端到轴线的距离必须还是一手数据的 18.405/2。
    func testWingStillReachesFullSpan() {
        let scene = TiangongScene()
        scene.build()
        let expected = TiangongScale.display(TiangongModel.wingSpan) / 2

        for id in [TiangongModuleID.leftWing, .rightWing] {
            guard let wing = scene.root.children.first(where: { $0.name == id.rawValue }) else {
                return XCTFail("没找到 \(id.rawValue)")
            }
            var outer: Float = 0
            for panel in wing.children where panel.name.hasPrefix("panel-") {
                guard let mesh = panel.components[ModelComponent.self]?.mesh else { continue }
                let half = mesh.bounds.max.x
                outer = max(outer, abs(wing.position.x + panel.position.x) + half)
            }
            XCTAssertEqual(outer, expected, accuracy: 0.001, "\(id.rawValue) 翼展被分格改变了")
        }
    }

    /// 对接机构要读得出「机构」：环之外还得有卡爪与通道。
    func testDockingPortHasLatchesAndTunnel() {
        let scene = TiangongScene()
        scene.build()
        guard let lab = scene.root.children.first(where: { $0.name == TiangongModuleID.lab.rawValue }),
              let port = lab.children.first(where: { $0.name == "port" }) else {
            return XCTFail("没找到对接机构")
        }
        let latches = port.children.filter { $0.name.hasPrefix("port-latch-") }
        XCTAssertEqual(latches.count, TiangongModel.dockingLatchCount)
        XCTAssertNotNil(port.children.first { $0.name == "port-tunnel" }, "缺中心通道")
        XCTAssertGreaterThanOrEqual(port.children.count + 1, 3, "环 + 卡爪 + 通道才够三件")
    }

    /// 卡爪均布：任两个相邻卡爪到轴线的距离相同，且角度间隔一致。
    func testDockingLatchesAreEvenlySpaced() {
        let scene = TiangongScene()
        scene.build()
        guard let lab = scene.root.children.first(where: { $0.name == TiangongModuleID.lab.rawValue }),
              let port = lab.children.first(where: { $0.name == "port" }) else {
            return XCTFail("没找到对接机构")
        }
        let latches = port.children.filter { $0.name.hasPrefix("port-latch-") }
        let radii = latches.map { simd_length(SIMD2($0.position.x, $0.position.z)) }
        for radius in radii {
            XCTAssertEqual(radius, radii[0], accuracy: 0.0001)
        }
        let expected = Float.pi * 2 / Float(latches.count)
        let angles = latches.map { atan2($0.position.z, $0.position.x) }.sorted()
        for index in 1..<angles.count {
            XCTAssertEqual(angles[index] - angles[index - 1], expected, accuracy: 0.001)
        }
    }
    /// 三角形预算（FR-C-07 的 L3 上限）。计数要递归——网格大多挂在子节点上。
    func testSceneStaysWithinTriangleBudget() {
        let scene = TiangongScene()
        scene.build()
        XCTAssertGreaterThan(scene.triangleEstimate, 1000, "计数没递归到子节点")
        XCTAssertLessThanOrEqual(scene.triangleEstimate, 20_000)
        XCTAssertLessThanOrEqual(scene.entityCount, 60, "实体超预算")
        XCTAssertLessThanOrEqual(scene.modelEntityCount, 40, "模型数超预算，同材质小件要合并")
    }

    /// 资源舱尾部必须读得出「动力系统 + 天线」：一手资料与新华社示意图都标了这两样。
    func testResourceCarriesEnginesAndAntenna() {
        let scene = TiangongScene()
        scene.build()
        guard let resource = scene.root.children.first(where: { $0.name == TiangongModuleID.resource.rawValue }) else {
            return XCTFail("没找到资源舱")
        }
        for name in ["resource-engines", "resource-verniers", "antenna-dish", "antenna-mast"] {
            XCTAssertNotNil(resource.children.first { $0.name == name }, "缺 \(name)")
        }
        XCTAssertEqual(
            resource.children.compactMap { $0.name }.filter { $0.hasPrefix("resource-engine-") }.count,
            0,
            "喷管必须合并成一个网格，不能每个一个实体"
        )
    }

    func testShenzhouHasEngines() {
        let scene = TiangongScene()
        scene.build()
        guard let ship = scene.root.children.first(where: { $0.name == TiangongModuleID.shenzhou.rawValue }) else {
            return XCTFail("没找到神舟")
        }
        XCTAssertNotNil(ship.children.first { $0.name == "shenzhou-engines" })
    }

    func testLabHasTwoWindows() {
        let scene = TiangongScene()
        scene.build()
        guard let lab = scene.root.children.first(where: { $0.name == TiangongModuleID.lab.rawValue }) else {
            return XCTFail("没找到实验舱")
        }
        let windows = lab.children.filter { $0.name.hasPrefix("lab-window-") }
        XCTAssertEqual(windows.count, 2)
    }
}

@MainActor
final class TiangongMaterialTests: XCTestCase {
    /// 三种表面都必须能在无外部资源的情况下生成出来。
    func testEverySurfaceYieldsATexture() {
        for surface in TiangongMaterials.Surface.allCases {
            XCTAssertNotNil(TiangongMaterials.texture(surface), surface.rawValue)
        }
    }

    /// 贴图只生成一次：重复取用不该再解码一遍。
    func testTexturesAreGeneratedOnce() {
        for surface in TiangongMaterials.Surface.allCases {
            _ = TiangongMaterials.texture(surface)
        }
        let baseline = TiangongMaterials.generationCount

        for _ in 0..<5 {
            for surface in TiangongMaterials.Surface.allCases {
                _ = TiangongMaterials.texture(surface)
            }
        }
        XCTAssertEqual(TiangongMaterials.generationCount, baseline, "重复取贴图必须命中缓存")
    }

    /// 这是 066 的核心风险：路由往返会重建整棵树，贴图跟着重建就白烧三次。
    func testRouteRebuildDoesNotRegenerateTextures() {
        let scene = TiangongScene()
        scene.build()
        let baseline = TiangongMaterials.generationCount

        for _ in 0..<3 {
            scene.rebuild()
        }
        XCTAssertEqual(TiangongMaterials.generationCount, baseline, "rebuild 不该重新生成贴图")
    }

    /// 三档材质必须真的不同，否则「分层」只是名字分层。
    func testThreeTiersDifferInRoughnessAndMetallic() {
        let tiers = [
            TiangongMaterials.labBody(),
            TiangongMaterials.resource(),
            TiangongMaterials.wing(),
        ]
        let roughness = Set(tiers.map { Int($0.roughness.scale * 100) })
        let metallic = Set(tiers.map { Int($0.metallic.scale * 100) })
        XCTAssertEqual(roughness.count, 3, "三档粗糙度重复")
        XCTAssertEqual(metallic.count, 3, "三档金属度重复")
    }

    /// 白 MLI 是隔热毯，不是金属：金属度必须为 0，否则在暗环境下等于照黑墙。
    func testLabBodyIsDielectric() {
        XCTAssertEqual(TiangongMaterials.labBody().metallic.scale, 0, accuracy: 0.001)
        XCTAssertGreaterThan(TiangongMaterials.labBody().roughness.scale, 0.6)
    }
}

final class TiangongOrbitClockTests: XCTestCase {
    /// 一圈 90 分钟，慢档 60 秒走完。
    func testOneOrbitAtSlowPace() {
        var clock = TiangongOrbitClock(phase: 0)
        clock.step(realSeconds: TiangongOrbitClock.paceSlow, pace: TiangongOrbitClock.paceSlow, paused: false)
        XCTAssertEqual(clock.completedOrbits, 1)
        XCTAssertEqual(clock.phase, 0, accuracy: 0.0001)
    }

    /// 模型时间不能跟着展示倍率走：1 真实秒 = 90 模型秒。
    func testModelSecondsFollowPhysics() {
        var clock = TiangongOrbitClock(phase: 0)
        clock.step(realSeconds: 1, pace: TiangongOrbitClock.paceSlow, paused: false)
        XCTAssertEqual(clock.modelSeconds, 90, accuracy: 0.001)
    }

    /// 对接时暂停是 FR-C-08 的硬约束。
    func testPausedDoesNotAdvance() {
        var clock = TiangongOrbitClock(phase: 0.4)
        clock.step(realSeconds: 10, pace: TiangongOrbitClock.paceFast, paused: true)
        XCTAssertEqual(clock.phase, 0.4, accuracy: 0.0001)
        XCTAssertEqual(clock.completedOrbits, 0)
        XCTAssertEqual(clock.modelSeconds, 0)
    }

    func testFastPaceIsSixTimesFaster() {
        var slow = TiangongOrbitClock(phase: 0)
        var fast = TiangongOrbitClock(phase: 0)
        slow.step(realSeconds: 5, pace: TiangongOrbitClock.paceSlow, paused: false)
        fast.step(realSeconds: 5, pace: TiangongOrbitClock.paceFast, paused: false)
        XCTAssertEqual(fast.phase / slow.phase, 6, accuracy: 0.001)
    }

    /// 圈数只增不减，相位回到 0…1。
    func testOrbitWrapsPastOne() {
        var clock = TiangongOrbitClock(phase: 0.9)
        clock.step(realSeconds: 24, pace: TiangongOrbitClock.paceSlow, paused: false)
        XCTAssertEqual(clock.completedOrbits, 1)
        XCTAssertEqual(clock.phase, 0.3, accuracy: 0.0001)
    }

    /// 太阳翼的翼面法线全程对准太阳（≤5° 的等价断言：点乘 ≥ 0.996）。
    func testWingNormalTracksTheSun() {
        for index in 0..<40 {
            let clock = TiangongOrbitClock(phase: Double(index) / 40)
            let normal = simd_quatf(angle: clock.wingAngle, axis: SIMD3(1, 0, 0))
                .act(SIMD3<Float>(0, 1, 0))
            XCTAssertGreaterThan(
                simd_dot(normal, clock.sunDirection),
                0.996,
                "phase \(Double(index) / 40)"
            )
        }
    }
}

@MainActor
final class TiangongOrbitSessionTests: XCTestCase {
    func testDockingPausesTheClock() {
        let session = TiangongSession()
        session.beginDocking()
        session.stepClock(delta: 5)
        XCTAssertEqual(session.orbit.modelSeconds, 0)
        XCTAssertEqual(session.completedOrbits, 0)
    }

    func testOrbitCountIsPublishedOnlyOnBoundary() {
        let session = TiangongSession()
        session.stepClock(delta: TiangongOrbitClock.paceSlow)
        XCTAssertEqual(session.completedOrbits, 1)
        session.stepClock(delta: 1)
        XCTAssertEqual(session.completedOrbits, 1, "没过圈不该刷新读数")
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
