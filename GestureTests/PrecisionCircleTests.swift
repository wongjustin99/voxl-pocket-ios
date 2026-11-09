import XCTest
import CoreGraphics
@testable import PointerInput

final class PrecisionCircleTests: XCTestCase {
    private let safe = CGRect(x: 36, y: 36, width: 300, height: 600)

    func testCircleSitsBelowThePointer() {
        let center = PrecisionCircle.center(for: CGPoint(x: 100, y: 200), in: safe, bottom: safe.maxY)
        XCTAssertEqual(center, CGPoint(x: 100, y: 200 + PrecisionCircle.offset))
    }

    func testCircleFlipsAboveThePointerNearTheBottom() {
        let center = PrecisionCircle.center(for: CGPoint(x: 100, y: 600), in: safe, bottom: safe.maxY)
        XCTAssertEqual(center, CGPoint(x: 100, y: 600 - PrecisionCircle.offset))
    }

    func testCircleStaysInsideTheSafeArea() {
        let center = PrecisionCircle.center(for: CGPoint(x: 0, y: 0), in: safe, bottom: safe.maxY)
        XCTAssertEqual(center, CGPoint(x: safe.minX, y: PrecisionCircle.offset))
    }
}
