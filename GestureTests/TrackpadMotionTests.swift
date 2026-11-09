import XCTest
import CoreGraphics
@testable import PointerInput

final class TrackpadMotionTests: XCTestCase {
    func testConstantSpeedIsIndependentOfEventFrequency() {
        func travel(hz: Int) -> CGFloat {
            var motion = TrackpadMotion()
            motion.reset(at: 0)
            return (1...hz).reduce(0) { total, sample in
                total + motion.move(CGPoint(x: 400.0 / Double(hz), y: 0), at: Double(sample) / Double(hz)).x
            }
        }
        XCTAssertEqual(travel(hz: 60), travel(hz: 120), accuracy: 0.0001)
    }

    func testNewGestureAndIdleTimeDoNotCarryFastSwipeSpeed() {
        var motion = TrackpadMotion()
        motion.reset(at: 0)
        XCTAssertEqual(motion.move(CGPoint(x: 20, y: 0), at: 0.01).x, 40)
        motion.reset(at: 1)
        XCTAssertEqual(motion.move(CGPoint(x: 1, y: 0), at: 1.1).x, 1)
        XCTAssertEqual(motion.move(CGPoint(x: 1, y: 0), at: 3).x, 1)
        motion.reset()
        XCTAssertEqual(motion.move(CGPoint(x: 10, y: 0), at: 3.001).x, 10)
    }

    func testMissingOrDuplicateTimestampsDoNotAmplifyMotion() {
        var motion = TrackpadMotion()
        let delta = CGPoint(x: -10, y: 5)
        XCTAssertEqual(motion.move(delta, at: 1), delta)
        XCTAssertEqual(motion.move(delta, at: 1), delta)
        XCTAssertEqual(motion.move(delta, at: 0.5), delta)
    }

    func testPrecisionCircleKeepsItsFixedGainAtAnySpeed() {
        let delta = CGPoint(x: 10, y: -20)
        var motion = TrackpadMotion()
        motion.reset(at: 0)
        XCTAssertEqual(motion.move(delta, at: 0.01, precision: true), CGPoint(x: 5.25, y: -10.5))
        XCTAssertEqual(motion.move(delta, at: 1, precision: true), CGPoint(x: 5.25, y: -10.5))
    }

    func testModerateMovementsUseAGentleGain() {
        var motion = TrackpadMotion()
        motion.reset(at: 0)
        let result = motion.move(CGPoint(x: 40, y: 0), at: 0.1)
        XCTAssertGreaterThan(result.x, 40)
        XCTAssertLessThan(result.x, 56)
    }

    func testFastSwipesTravelFartherThanSlowMovements() {
        let delta = CGPoint(x: 10, y: -5)
        var slow = TrackpadMotion()
        var fast = TrackpadMotion()
        slow.reset(at: 0)
        fast.reset(at: 0)
        let fine = slow.move(delta, at: 0.2)
        let swipe = fast.move(delta, at: 0.01)
        XCTAssertEqual(fine, delta)
        XCTAssertGreaterThan(swipe.x, fine.x)
        XCTAssertEqual(swipe.y / swipe.x, delta.y / delta.x)
        XCTAssertLessThanOrEqual(swipe.x, delta.x * 2)
    }
}
