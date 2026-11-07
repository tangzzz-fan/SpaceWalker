import XCTest

@testable import SpaceWalker

@MainActor
final class SkySessionTests: XCTestCase {
    func testStartsFollowingAttitude() {
        let session = SkySession()
        XCTAssertTrue(session.followsAttitude)
    }

    /// 定位不该偷偷改用户意图：跟随时跳转后仍然跟随，只是多了一个朝向偏移。
    func testAimKeepsTheFollowIntent() {
        let session = SkySession()
        session.aim(at: SIMD3<Float>(0, 0, -1))
        XCTAssertTrue(session.followsAttitude)
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
