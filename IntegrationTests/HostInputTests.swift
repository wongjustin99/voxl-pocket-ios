import XCTest
@testable import VoxlPocket

final class HostInputTests: XCTestCase {
    func testOldHostsLoadAndInputPreferencesStayPerHost() throws {
        let old = try JSONDecoder().decode(Host.self, from: Data(#"{"name":"Old host","url":"wss://old.invalid/ws"}"#.utf8))
        XCTAssertNil(old.input)
        let previous = Hosts.all
        defer { Hosts.all = previous }
        let first = Host(name: "First", url: "wss://first.invalid/ws", cloudflareAccess: true)
        let second = Host(name: "Second", url: "wss://second.invalid/ws")
        Hosts.all = [first, second]
        let input = InputPreferences(mode: .touch, reverseScroll: true, showCircle: true)
        Hosts.setInput(input, for: first.url)
        XCTAssertEqual(Hosts.all[0].input, input)
        XCTAssertEqual(Hosts.all[0].cloudflareAccess, true)
        XCTAssertEqual(Hosts.all[1], second)
    }
}
