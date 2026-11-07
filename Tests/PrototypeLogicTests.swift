import XCTest
import simd

@testable import SpaceWalker

final class PrototypeLogicTests: XCTestCase {
    func testClampScaleKeepsWithinBounds() {
        XCTAssertEqual(PrototypeLogic.clampScale(0.1), PrototypeLogic.minScale)
        XCTAssertEqual(PrototypeLogic.clampScale(9), PrototypeLogic.maxScale)
        XCTAssertEqual(PrototypeLogic.clampScale(1.2), 1.2)
    }

    func testClampPositionDropsHeightAndProjectsBackToRadius() {
        let clamped = PrototypeLogic.clampPosition(SIMD3(3, 1, 4))
        XCTAssertEqual(clamped.y, 0)
        XCTAssertEqual(
            simd_length(SIMD2(clamped.x, clamped.z)),
            PrototypeLogic.maxRadius,
            accuracy: 0.0001
        )
    }

    func testClampPositionKeepsPointInsideRadius() {
        let position = SIMD3<Float>(0.1, 0.5, -0.2)
        XCTAssertEqual(PrototypeLogic.clampPosition(position), SIMD3(0.1, 0, -0.2))
    }

    func testDragOffsetMapsScreenUpToNegativeZ() {
        let offset = PrototypeLogic.dragOffset(translation: CGSize(width: 100, height: -50))
        XCTAssertEqual(offset.x, 0.15, accuracy: 0.0001)
        XCTAssertEqual(offset.z, -0.075, accuracy: 0.0001)
        XCTAssertEqual(offset.y, 0)
    }
}
