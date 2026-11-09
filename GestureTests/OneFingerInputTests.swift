import XCTest
import CoreGraphics
@testable import PointerInput

final class OneFingerInputTests: XCTestCase {
    func testTapThenHoldStartsRightDragAndCancelReleasesIt() {
        var input = OneFingerInput()
        let point = CGPoint(x: 100, y: 100)
        _ = input.began(at: point, time: 0)
        XCTAssertEqual(input.ended(at: point, time: 0.05), [.click(1)])
        _ = input.began(at: point, time: 0.2)
        XCTAssertEqual(input.held(time: 0.7), [.button(3, true), .feedback(point)])
        XCTAssertEqual(input.moved(to: CGPoint(x: 110, y: 100), time: 0.75), [.relative(CGPoint(x: 10, y: 0))])
        XCTAssertEqual(input.cancel(), [.button(3, false)])
        XCTAssertEqual(input.ended(at: point, time: 0.8), [])
    }

    func testTwoTapsThenHoldUsesMiddleButtonAndReleaseMakesAClick() {
        var input = OneFingerInput()
        let point = CGPoint(x: 100, y: 100)
        for time in [0.0, 0.15] {
            _ = input.began(at: point, time: time)
            XCTAssertEqual(input.ended(at: point, time: time + 0.05), [.click(1)])
        }
        _ = input.began(at: point, time: 0.3)
        XCTAssertEqual(input.held(time: 0.8), [.button(2, true), .feedback(point)])
        XCTAssertEqual(input.ended(at: point, time: 0.9), [.button(2, false)])
    }

    func testTouchModeClicksAtFingerAndSupportsMiddleHold() {
        var input = OneFingerInput(mode: .touch)
        let point = CGPoint(x: 30, y: 50)
        for time in [0.0, 0.15] {
            _ = input.began(at: point, time: time)
            XCTAssertEqual(input.ended(at: point, time: time + 0.05), [.point(point), .click(1)])
        }
        _ = input.began(at: point, time: 0.3)
        XCTAssertEqual(input.held(time: 0.8), [.point(point), .button(2, true), .feedback(point)])
        XCTAssertEqual(input.cancel(), [.button(2, false)])
    }

    func testTrackpadPanDoesNotClickAndViewOnlyEmitsNothing() {
        var input = OneFingerInput()
        _ = input.began(at: .zero, time: 0)
        XCTAssertEqual(input.moved(to: CGPoint(x: 20, y: 0), time: 0.1), [.relative(CGPoint(x: 20, y: 0))])
        XCTAssertEqual(input.held(time: 1), [])
        XCTAssertEqual(input.ended(at: CGPoint(x: 20, y: 0), time: 1.1), [])
        input.mode = .viewOnly
        XCTAssertEqual(input.began(at: .zero, time: 2), [])
        XCTAssertEqual(input.moved(to: CGPoint(x: 20, y: 0), time: 2.1), [])
        XCTAssertEqual(input.held(time: 3), [])
        XCTAssertEqual(input.ended(at: .zero, time: 3.1), [])
    }

    func testHoldWithoutPrecedingTapStillDragsLeftAndCancellationDoesNotClick() {
        var input = OneFingerInput()
        _ = input.began(at: .zero, time: 0)
        XCTAssertEqual(input.held(time: 0.5), [.button(1, true), .feedback(.zero)])
        XCTAssertEqual(input.cancel(), [.button(1, false)])
        _ = input.began(at: .zero, time: 1)
        XCTAssertEqual(input.cancel(), [])
        XCTAssertEqual(input.ended(at: .zero, time: 1.1), [])
    }

    func testDragReleaseAppliesTheFinalPositionBeforeReleasing() {
        var input = OneFingerInput()
        _ = input.began(at: .zero, time: 0)
        _ = input.held(time: 0.5)
        _ = input.moved(to: CGPoint(x: 20, y: 0), time: 0.6)
        XCTAssertEqual(input.ended(at: CGPoint(x: 30, y: 0), time: 0.7), [.relative(CGPoint(x: 10, y: 0)), .button(1, false)])
    }

    func testLateOrDistantSecondTouchMovesWithoutStartingADrag() {
        let first = CGPoint(x: 100, y: 100)
        for (point, time) in [(first, 0.5), (CGPoint(x: 200, y: 100), 0.15)] {
            var input = OneFingerInput()
            _ = input.began(at: first, time: 0)
            _ = input.ended(at: first, time: 0.05)
            _ = input.began(at: point, time: time)
            XCTAssertEqual(input.moved(to: CGPoint(x: point.x + 20, y: point.y), time: time + 0.05), [.relative(CGPoint(x: 20, y: 0))])
            XCTAssertEqual(input.cancel(), [])
        }
    }

    func testTapThenDragHoldsLeftButtonWithoutWaiting() {
        var input = OneFingerInput()
        let start = CGPoint(x: 100, y: 100)
        XCTAssertEqual(input.began(at: start, time: 0), [])
        XCTAssertEqual(input.ended(at: start, time: 0.05), [.click(1)])
        XCTAssertEqual(input.began(at: start, time: 0.15), [])
        XCTAssertEqual(input.moved(to: CGPoint(x: 120, y: 110), time: 0.2), [.button(1, true), .relative(CGPoint(x: 20, y: 10))])
        XCTAssertEqual(input.ended(at: CGPoint(x: 120, y: 110), time: 0.25), [.button(1, false)])
    }
}
