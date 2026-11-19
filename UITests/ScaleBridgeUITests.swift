import UIKit
import XCTest

/// 票 092 取证：真比例叙事的「播放中 / 复位后」两帧 + 全览按钮重入不重播。
/// 走 SkyCheck scheme（UITest target 不进单测 scheme）：
/// `xcodebuild test -scheme SkyCheck -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -only-testing:SpaceWalkerUITests/ScaleNarrativeUITests`
final class ScaleNarrativeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    func testNarrativePlaysOnceThenRestores() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "SPACEWALKER_MODE": "solar",
            "SPACEWALKER_NARRATIVE": "1",
            // 取证拉长到 4s：0.6s 窗口小于 UI 查询轮询间隔，断言会漏帧。
            // 生产时长仍是 0.6s（ScaleNarrativeTests 守住）。
            "SPACEWALKER_NARRATIVE_SECONDS": "4",
            "SPACEWALKER_FPS": "1",
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))

        // 叙事在首帧后开始、持续 0.6s。轮询状态行文案，命中即截「播放中」。
        let ruler = app.staticTexts["此刻行星直径 < 1 像素"]
        let deadline = Date().addingTimeInterval(15)
        var caughtPlaying = false
        while Date() < deadline {
            if ruler.exists {
                caughtPlaying = true
                save("narrative-playing", app)
                break
            }
            usleep(50_000)
        }
        XCTAssertTrue(caughtPlaying, "15s 内没等到叙事状态行")

        // 播放窗口结束后应自动复位：叙事文案消失、状态行回到运行态（天数随时间走，用前缀匹配）。
        let restoreDeadline = Date().addingTimeInterval(8)
        while ruler.exists && Date() < restoreDeadline {
            usleep(50_000)
        }
        XCTAssertFalse(ruler.exists, "叙事应在 0.6s 后自动结束")
        let running = app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH %@", "运行中")
        ).firstMatch
        XCTAssertTrue(running.waitForExistence(timeout: 5), "叙事结束应回到运行态状态行")
        save("narrative-restored", app)

        // 再点「全览」：播过之后不再重播，状态行不被改写。
        app.buttons["全览"].tap()
        usleep(800_000)
        XCTAssertFalse(ruler.exists, "播过之后全览不重播叙事")
        save("narrative-overview-again", app)
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
        print("SHOT \(name) \(Int(upright.size.width))x\(Int(upright.size.height))")
        for url in [
            URL(fileURLWithPath: "/tmp/\(name).png"),
            URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(name).png"),
        ] {
            do {
                try data.write(to: url)
                return
            } catch {
                print("SHOT-FAIL \(url.path): \(error)")
            }
        }
    }
}