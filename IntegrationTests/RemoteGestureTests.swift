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
        XCTAssertTrue(mode.allControlEvents.contains(.touchUpInside))
        let touch = RemoteViewController(host: Host(name: "Touch", url: "wss://gesture.invalid/touch", input: InputPreferences(mode: .touch)))
        touch.loadViewIfNeeded()
        let touchDrag = try XCTUnwrap((touch.view.gestureRecognizers ?? []).compactMap { $0 as? UIPanGestureRecognizer }.first { $0.minimumNumberOfTouches == 3 })
        XCTAssertEqual((touch as UIGestureRecognizerDelegate).gestureRecognizerShouldBegin?(touchDrag), false)
    }

    @MainActor
    func testSavedCircleAndViewOnlyProfilesAreApplied() throws {
        let host = Host(name: "Circle", url: "wss://gesture.invalid/circle", input: InputPreferences(showCircle: true))
        let remote = RemoteViewController(host: host)
        remote.loadViewIfNeeded()
        let circle = try XCTUnwrap(descendants(of: remote.view).first { $0.accessibilityLabel == "Precision mouse circle" })
        XCTAssertFalse(circle.isHidden)
        let circleGesture = try XCTUnwrap(circle.gestureRecognizers?.first as? OneFingerGestureRecognizer)
        XCTAssertEqual(circleGesture.mode, .trackpad)
        XCTAssertTrue(circleGesture.coordinateView === remote.view)
        XCTAssertTrue((remote.view.gestureRecognizers ?? []).contains { ($0 as? UITapGestureRecognizer)?.numberOfTouchesRequired == 3 })
        let viewer = RemoteViewController(host: Host(name: "Viewer", url: "wss://gesture.invalid/viewer", input: InputPreferences(mode: .viewOnly, showCircle: true)))
        viewer.loadViewIfNeeded()
        XCTAssertNotNil(descendants(of: viewer.view).first { $0.accessibilityLabel == "View only" })
        XCTAssertTrue(try XCTUnwrap(descendants(of: viewer.view).first { $0.accessibilityLabel == "Precision mouse circle" }).isHidden)
        let finger = try XCTUnwrap(viewer.view.gestureRecognizers?.first { $0 is OneFingerGestureRecognizer })
        XCTAssertEqual((viewer as UIGestureRecognizerDelegate).gestureRecognizerShouldBegin?(finger), false)
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
