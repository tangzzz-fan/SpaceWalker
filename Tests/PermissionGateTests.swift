import AVFoundation
import XCTest

@testable import SpaceWalker

final class PermissionGateTests: XCTestCase {
    func testAuthorizedShowsContent() {
        XCTAssertEqual(PermissionGate.screen(for: .authorized), .content)
    }

    func testNotDeterminedRequestsAccess() {
        XCTAssertEqual(PermissionGate.screen(for: .notDetermined), .requesting)
    }

    func testDeniedShowsExplanationWithSettings() {
        XCTAssertEqual(
            PermissionGate.screen(for: .denied),
            .explanation(showsSettings: true)
        )
    }

    func testRestrictedShowsExplanationWithoutSettings() {
        XCTAssertEqual(
            PermissionGate.screen(for: .restricted),
            .explanation(showsSettings: false)
        )
    }

    func testRequestOnlyOncePerLaunch() {
        XCTAssertTrue(
            PermissionGate.shouldRequestAccess(status: .notDetermined, alreadyRequested: false)
        )
        XCTAssertFalse(
            PermissionGate.shouldRequestAccess(status: .notDetermined, alreadyRequested: true)
        )
    }

    func testRequestIsSkippedForDecidedStates() {
        for status in [CameraPermissionState.authorized, .denied, .restricted] {
            XCTAssertFalse(
                PermissionGate.shouldRequestAccess(status: status, alreadyRequested: false),
                "status \(status)"
            )
        }
    }

    func testAVStatusMapping() {
        XCTAssertEqual(CameraPermissionState.from(.notDetermined), .notDetermined)
        XCTAssertEqual(CameraPermissionState.from(.authorized), .authorized)
        XCTAssertEqual(CameraPermissionState.from(.denied), .denied)
        XCTAssertEqual(CameraPermissionState.from(.restricted), .restricted)
    }

    func testPermissionReducerTracksRequestAndStatus() {
        var state = PermissionState()
        XCTAssertEqual(state.screen, .requesting)

        PermissionReducer.reduce(&state, .requested)
        XCTAssertTrue(state.requestedThisLaunch)

        PermissionReducer.reduce(&state, .status(.denied))
        XCTAssertEqual(state.screen, .explanation(showsSettings: true))
    }
}
