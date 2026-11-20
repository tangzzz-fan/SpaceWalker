import UIKit
import XCTest

/// 096 阶梯导航验收（无头可复现）：
/// `xcodebuild -scheme SkyCheck test -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
final class ScaleLadderUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(_ mode: String, extra: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        var env = ["SPACEWALKER_MODE": mode, "SPACEWALKER_SKYMOTION": "0"]
        for (k, v) in extra { env[k] = v }
        app.launchEnvironment = env
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        return app
    }

    /// 四节点常显、触达 ≥44pt、当前层高亮、隔层下钻禁用。
    func testLadderNodesAlwaysVisibleWithReachability() throws {
        let app = launch("sky")
        sleep(6)

        for title in ["星图", "太阳系", "地月系", "天宫一号"] {
            let node = app.buttons[title]
            XCTAssertTrue(node.waitForExistence(timeout: 5), "阶梯缺节点：\(title)")
            XCTAssertGreaterThanOrEqual(node.frame.height, 44, "\(title) 触达不足 44pt")
            XCTAssertGreaterThanOrEqual(node.frame.width, 44, "\(title) 触达不足 44pt")
        }
        XCTAssertTrue(app.buttons["星图"].isSelected, "当前层应高亮")
        XCTAssertTrue(app.buttons["太阳系"].isEnabled, "相邻下钻应可达")
        XCTAssertFalse(app.buttons["地月系"].isEnabled, "隔层下钻应禁用")
        XCTAssertFalse(app.buttons["天宫一号"].isEnabled, "隔层下钻应禁用")
        save("096-ladder-sky", app)

        app.buttons["地月系"].tap()
        sleep(1)
        XCTAssertTrue(app.staticTexts["星图"].exists, "点禁用节点不该切层")
    }

    /// 尺子常显：四层固定区间文案取自 088 常量表，读数用 10^x m。
    func testRulerShowsFixedRangeAndScientificReading() throws {
        let app = launch("sky")
        sleep(6)
        XCTAssertTrue(app.staticTexts["4–3000 光年"].exists)
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "10^")).firstMatch.exists,
            "尺子应有 10^x m 读数"
        )

        app.buttons["太阳系"].tap()
        sleep(3)
        XCTAssertTrue(app.staticTexts["0.4–30 AU"].waitForExistence(timeout: 5))
        save("096-ruler-solar", app)

        app.buttons["地月系"].tap()
        sleep(3)
        XCTAssertTrue(app.staticTexts["350 km–38 万 km"].waitForExistence(timeout: 5))

        app.buttons["天宫一号"].tap()
        sleep(4)
        XCTAssertTrue(app.staticTexts["约 10 米"].waitForExistence(timeout: 5))
        save("096-ruler-tiangong", app)
    }

    /// 四层往返：下钻只走相邻层，上行可任意跳；回星图提示一次。
    /// 提示停留用 DEBUG 参数拉长到 8s：XCUI 查询本身阻塞主线程，
    /// 生产 2s 窗口会被查询吃掉，无法稳定断言「出现→消失」。
    func testFourLevelRoundTripWithAttitudeNotice() throws {
        let app = launch("sky", extra: ["SPACEWALKER_TOAST_SECONDS": "8"])
        sleep(6)

        app.buttons["太阳系"].tap()
        sleep(3)
        XCTAssertTrue(app.buttons["太阳系"].isSelected)
        XCTAssertTrue(app.buttons["星图"].isEnabled, "上行任意层可达")
        XCTAssertTrue(app.buttons["地月系"].isEnabled)
        XCTAssertFalse(app.buttons["天宫一号"].isEnabled)

        app.buttons["地月系"].tap()
        sleep(3)
        app.buttons["天宫一号"].tap()
        sleep(4)
        XCTAssertTrue(app.buttons["天宫一号"].isSelected)
        save("096-ladder-tiangong", app)

        app.buttons["星图"].tap()
        sleep(3)
        XCTAssertTrue(app.buttons["星图"].isSelected)
        XCTAssertTrue(
            app.staticTexts["已恢复姿态跟随"].waitForExistence(timeout: 3),
            "上行回星图应提示一次"
        )
        save("096-attitude-toast", app)

        sleep(9)
        XCTAssertFalse(app.staticTexts["已恢复姿态跟随"].exists, "提示停留结束后应消失")

        app.buttons["太阳系"].tap()
        sleep(3)
        app.buttons["星图"].tap()
        sleep(2)
        XCTAssertFalse(
            app.staticTexts["已恢复姿态跟随"].exists,
            "一次性提示不许第二次出现"
        )
    }

    /// 双击当前节点回本层全览（太阳系：清选中、机位复位）。
    func testDoubleTapCurrentNodeReturnsToOverview() throws {
        let app = launch("solarSystem")
        sleep(6)

        let node = app.buttons["太阳系"]
        XCTAssertTrue(node.isSelected)
        node.doubleTap()
        sleep(2)
        XCTAssertTrue(app.buttons["太阳系"].isSelected, "双击当前节点不切层")
        XCTAssertTrue(app.buttons["全览"].exists)
        save("096-doubletap-overview", app)
    }

    /// 横屏：阶梯横排，四节点仍一次可达。
    func testLandscapeLadderKeepsFourReachableNodes() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = launch("sky")
        sleep(6)
        for title in ["星图", "太阳系", "地月系", "天宫一号"] {
            let node = app.buttons[title]
            XCTAssertTrue(node.waitForExistence(timeout: 5), "横屏缺节点：\(title)")
            XCTAssertGreaterThanOrEqual(node.frame.height, 44)
        }
        save("096-ladder-landscape", app)
        XCUIDevice.shared.orientation = .portrait
    }

    /// 录屏取证专用（tools/record-scale-ladder.sh 驱动）：六段切层。
    /// 每段之间留 6s 稳态：录屏 + XCUI 查询会抢主线程，实测 solar↔earthOrbit
    /// 转场窗口里 ticker 只跑到 2 个采样（min 0.9fps），间隔太短会让逐帧
    /// 取证拿不到插值过程。转场时长由 SPACEWALKER_TRANSITION_SECONDS 控制。
    /// 默认跳过，只在 SPACEWALKER_RECORD=1 时跑。
    func testRecordedSixSegmentRoundTrip() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["SPACEWALKER_RECORD"] == "1",
            "录屏取证模式：SPACEWALKER_RECORD=1"
        )
        let seconds = ProcessInfo.processInfo.environment["SPACEWALKER_TRANSITION_SECONDS"] ?? "0.45"
        // launchEnvironment 会整体覆盖 xctestrun 注入的目标 app 环境，
        // 取证开关必须在这里显式带上。
        let app = launch("sky", extra: [
            "SPACEWALKER_TRANSITION_SECONDS": seconds,
            "SPACEWALKER_TICK_DIAG": "1",
        ])
        sleep(8)
        let legs = ["太阳系", "地月系", "天宫一号", "地月系", "太阳系", "星图"]
        for title in legs {
            let node = app.buttons[title]
            XCTAssertTrue(node.waitForExistence(timeout: 5), "缺节点：\(title)")
            XCTAssertTrue(node.isEnabled, "取证腿不可达：\(title)")
            node.tap()
            sleep(6)
        }
        sleep(2)
    }

    private func save(_ name: String, _ app: XCUIApplication) {
        let shot = XCUIScreen.main.screenshot()
        let image = shot.image
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let upright = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let data = upright.pngData() else {
            XCTFail("截图编码失败：\(name)")
            return
        }
        try? data.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
        print("SHOT \(name)")
    }
}