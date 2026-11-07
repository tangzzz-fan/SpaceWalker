import UIKit
import XCTest

/// 方向验收：模拟器没有窗口、也点不动，只能靠 XCUIDevice 旋转设备。
/// 这个 target 不进单测 scheme（跑一次约半分钟）：
/// `xcodebuild -scheme SkyCheck test`
final class LandscapeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    func testSkyLandscapeLayout() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "SPACEWALKER_MODE": "sky",
            "SPACEWALKER_AIM": "Sgr",
            "SPACEWALKER_CONSTELLATION": "Sgr",
            "SPACEWALKER_SKYMOTION": "0",
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))

        // 场景要建 0.7 秒左右，等卡片与天空都出来再截。
        sleep(7)
        save("sky-portrait", app)

        XCUIDevice.shared.orientation = .landscapeRight
        sleep(4)
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeRight)
        save("sky-landscape-right", app)

        XCUIDevice.shared.orientation = .landscapeLeft
        sleep(4)
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeLeft)
        save("sky-landscape-left", app)

        // 横屏下顶栏与识别卡都还在，才说明排版没塌。
        XCTAssertTrue(app.staticTexts["星图"].exists, "横屏丢了标题")
        XCTAssertTrue(app.staticTexts["人马座"].exists, "横屏丢了星座识别卡")

        // 捏合放大：模拟器支持多指，这一段真能跑到（日志 sky.fov 29.5 → 16）。
        // 缩到 0.55 的那一侧在模拟器上识别不出来，别拿它当断言。
        app.pinch(withScale: 2.0, velocity: 1)
        sleep(2)
        save("sky-landscape-zoom", app)
    }

    /// 人马座 38° 见方，转屏保尺度后竖直只有 31°，装不全。
    /// 「看全」靠捏合，模拟器没有多点触控（`app.pinch` 不触发 MagnifyGesture），
    /// 只能用等价的启动参数把视场拉到 55° 验一张。
    func testLandscapeFitsWholeConstellation() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchEnvironment = [
            "SPACEWALKER_MODE": "sky",
            "SPACEWALKER_AIM": "Sgr",
            "SPACEWALKER_CONSTELLATION": "Sgr",
            "SPACEWALKER_FOV": "55",
            "SPACEWALKER_SKYMOTION": "0",
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(7)
        save("sky-landscape-fit", app)
        XCTAssertTrue(app.staticTexts["人马座"].exists)
    }

    /// 切走再回来：会话由路由层持有，页面销毁不该带走选中与图层。
    /// 生命周期由 `sky.session boot` 在 session.log 里的条数裁定（应为 1 条）。
    func testSkyStateSurvivesRouteRoundTrip() throws {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "SPACEWALKER_MODE": "sky",
            "SPACEWALKER_LAYERS": "1",
            "SPACEWALKER_AIM": "Ori",
            "SPACEWALKER_CONSTELLATION": "Ori",
            "SPACEWALKER_MOTIONLOG": "1",
        ]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(7)

        let away = UInt32(ProcessInfo.processInfo.environment["SKYCHECK_AWAY_SECONDS"] ?? "") ?? 12
        print("SKYCHECK away=\(away)")
        app.buttons["太阳系"].tap()
        sleep(away)
        app.buttons["星图"].tap()
        sleep(5)
        save("sky-after-roundtrip", app)

        XCTAssertTrue(app.staticTexts["星图"].exists)
    }

    func testSolarSystemLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeRight
        let app = XCUIApplication()
        app.launchEnvironment = ["SPACEWALKER_MODE": "space"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        sleep(5)
        save("solar-landscape", app)

        let rate = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "天/秒")).firstMatch
        XCTAssertTrue(rate.exists, "太阳系横屏丢了速率行")
    }

    /// XCUIScreenshot 是设备原生的竖版像素，直接用会把横屏存成歪的；
    /// 走一遍 UIGraphicsImageRenderer 把 imageOrientation 烘进像素。
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
        print("SHOT \(name) \(Int(upright.size.width))x\(Int(upright.size.height)) orientation=\(image.imageOrientation.rawValue)")
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
        XCTFail("截图无处可写：\(name)")
    }
}
