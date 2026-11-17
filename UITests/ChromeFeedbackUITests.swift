import UIKit
import XCTest

/// 081/083/084 反馈接线验收（无头可复现）：
/// `xcodebuild -scheme SkyCheck test -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`
final class ChromeFeedbackUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    /// 084 F1：锁定态点「再入」→ 状态条出现 PRD-UI:232 原文提示，3 秒后回落。
    func testReentryLockedTapShowsHintThenFallsBack() throws {
        let app = XCUIApplication()
        app.launchEnvironment = ["SPACEWALKER_MODE": "tiangong"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(5)

        XCTAssertFalse(app.staticTexts["完成三步任务并看过史实后解锁"].exists)
        app.buttons["再入"].tap()
        sleep(1)
        XCTAssertTrue(
            app.staticTexts["完成三步任务并看过史实后解锁"].exists,
            "锁定态点再入应给解锁提示（084 F1）"
        )
        save("084-reentry-hint", app)

        sleep(4)
        XCTAssertFalse(
            app.staticTexts["完成三步任务并看过史实后解锁"].exists,
            "提示应在 3 秒后回落默认状态条"
        )
        XCTAssertTrue(app.staticTexts["目标飞行器 · 1:20 展示"].exists)
    }

    /// 081：剖面态三处舱内标注常显，VoiceOver 可读；退出剖面即消失。
    func testCutawayInteriorLabelsVisibleAndAccessible() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "SPACEWALKER_MODE": "tiangong",
            "SPACEWALKER_TG_CUTAWAY": "1",
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(6)

        for name in ["睡眠区", "健身区", "设备机柜"] {
            XCTAssertTrue(app.staticTexts[name].exists, "剖面态缺舱内标注：\(name)")
        }
        save("081-cutaway-labels", app)

        app.buttons["退出剖面"].tap()
        sleep(2)
        XCTAssertFalse(app.staticTexts["睡眠区"].exists, "非剖面态不该有舱内标注")
    }

    /// 083：对齐开启时「今夜」选中态 + 状态条消费 statusText。
    func testTonightAlignmentShowsSelectionAndStatus() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "SPACEWALKER_MODE": "sky",
            "SPACEWALKER_ALIGN": "1",
            "SPACEWALKER_LAT": "39.9",
            "SPACEWALKER_LON": "116.4",
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(6)

        let tonight = app.buttons["今夜"]
        XCTAssertTrue(tonight.exists)
        XCTAssertTrue(
            tonight.isSelected,
            "对齐开启时「今夜」应呈选中态（083）"
        )
        let status = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH %@", "今夜此刻")
        ).firstMatch
        XCTAssertTrue(status.exists, "状态条应显示今夜对齐文案")
        save("083-tonight-on", app)
    }

    /// 084 F4：太阳系状态条带流速档位「x 天/秒」，点流速后档位变化。
    func testSolarRateVisibleInStatusLine() throws {
        let app = XCUIApplication()
        app.launchEnvironment = ["SPACEWALKER_MODE": "solarSystem"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(5)

        // 天数随 ticker 走，不能拿「第 0 天」做精确断言；只断相位与档位段。
        let initial = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH %@ AND label CONTAINS %@", "运行中 · 第", "· 1 天/秒")
        ).firstMatch
        XCTAssertTrue(initial.waitForExistence(timeout: 5), "初始档位 1 天/秒应上状态条")
        app.buttons["流速"].tap()
        let bumped = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "· 2 天/秒")
        ).firstMatch
        XCTAssertTrue(bumped.waitForExistence(timeout: 5), "点流速应升档并上状态条")
        save("084-solar-rate", app)
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