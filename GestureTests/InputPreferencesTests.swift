import XCTest
import CoreGraphics
@testable import PointerInput

final class InputPreferencesTests: XCTestCase {
    func testScrollDirectionAndSavedPreferences() throws {
        let normal = InputPreferences()
        XCTAssertEqual(normal.scrollDelta(CGPoint(x: 2, y: 3), scale: 4), CGPoint(x: -8, y: -12))
        let reversed = InputPreferences(mode: .touch, reverseScroll: true, showCircle: true)
        XCTAssertEqual(reversed.scrollDelta(CGPoint(x: 2, y: 3), scale: 4), CGPoint(x: 8, y: 12))
        XCTAssertEqual(try JSONDecoder().decode(InputPreferences.self, from: JSONEncoder().encode(reversed)), reversed)
        XCTAssertEqual(InputPreferences(mode: .viewOnly).scrollDelta(CGPoint(x: 2, y: 3), scale: 4), .zero)
    }

    func testViewOnlyAllowsViewingAndReleasesButNotRemoteChanges() {
        let preferences = InputPreferences(mode: .viewOnly)
        for message in ["v,1", "a,12", "au,0", "kf", "po,10", "r"] {
            XCTAssertTrue(preferences.allows(message), message)
        }
        for message in ["m,1,2", "b,1,1", "k,32,1", "sp,1,2", "c,private", "sz,100,200", "dp,1", "unknown"] {
            XCTAssertFalse(preferences.allows(message), message)
        }
        XCTAssertTrue(InputPreferences().allows("b,1,1"))
    }
}
