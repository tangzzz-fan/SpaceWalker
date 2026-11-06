import XCTest

@testable import SpaceWalker

// 占位测试：只验证工程骨架可链接、测试 target 可运行。
// 待方向确认后按「方案 → 测试 → 实施 → 交付」替换为真实用例。
final class ProjectSmokeTests: XCTestCase {
    func testAppEntryPointIsLinkable() {
        XCTAssertNotNil(SpaceWalkerApp.self)
    }
}
