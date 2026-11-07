import XCTest

@testable import SpaceWalker

@MainActor
final class SkySessionTests: XCTestCase {
    func testStartsFollowingAttitude() {
        let session = SkySession()
        XCTAssertTrue(session.followsAttitude)
    }

    func testAimHandsControlBackToManual() {
        let session = SkySession()
        session.aim(at: SIMD3<Float>(0, 0, -1))
        XCTAssertFalse(session.followsAttitude, "定位之后必须交还控制权，否则姿态与拖动互相堵死")
        XCTAssertTrue(session.isManual)
    }

    func testToggleReturnsToFollowing() {
        let session = SkySession()
        session.aim(at: SIMD3<Float>(0, 0, -1))
        session.setFollowsAttitude(true)
        XCTAssertTrue(session.followsAttitude)
    }

    func testWithoutGyroEverythingIsManual() {
        let session = SkySession()
        session.setFollowsAttitude(true)
        XCTAssertFalse(session.canFollowAttitude)
        XCTAssertTrue(session.isManual, "没有陀螺仪就不能指望姿态，拖必须是可用的")
    }
}
