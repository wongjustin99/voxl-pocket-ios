import XCTest
import UIKit
@testable import VoxlPocket

final class RemoteGestureTests: XCTestCase {
    @MainActor
    func testThreeFingerDragIsAvailableOnlyInTrackpadMode() throws {
        let remote = RemoteViewController(host: Host(name: "Gesture test", url: "wss://gesture.invalid/\(UUID().uuidString)"))
        remote.loadViewIfNeeded()
        let pans = (remote.view.gestureRecognizers ?? []).compactMap { $0 as? UIPanGestureRecognizer }
        let drag = try XCTUnwrap(pans.first { $0.minimumNumberOfTouches == 3 })
        XCTAssertEqual(drag.maximumNumberOfTouches, 3)
        XCTAssertEqual(drag.allowedTouchTypes, [NSNumber(value: UITouch.TouchType.direct.rawValue)])
        XCTAssertEqual((remote as UIGestureRecognizerDelegate).gestureRecognizerShouldBegin?(drag), true)
        let scroll = try XCTUnwrap(pans.first { $0.minimumNumberOfTouches == 2 })
        XCTAssertEqual(scroll.maximumNumberOfTouches, 2)
        let mode = try XCTUnwrap(descendants(of: remote.view).first { $0.accessibilityLabel == "Trackpad mode" } as? UIButton)
        mode.sendActions(for: .touchUpInside)
        XCTAssertEqual(mode.accessibilityLabel, "Touch mode")
        XCTAssertEqual((remote as UIGestureRecognizerDelegate).gestureRecognizerShouldBegin?(drag), false)
    }

    @MainActor
    func testRemoteRespondersDoNotReserveThreeFingersForLocalEditing() {
        let remote = RemoteViewController(host: Host(name: "Gesture test", url: "wss://gesture.invalid/ws"))
        XCTAssertEqual(remote.editingInteractionConfiguration, .none)
        XCTAssertEqual(KeyInput().editingInteractionConfiguration, .none)
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
