import XCTest
import UIKit
@testable import VoxlPocket

final class SessionAccessTests: XCTestCase, SessionDelegate {
    private var signIn: XCTestExpectation?

    @MainActor
    func testLiveCloudflareRedirectRequestsSignInAndPreservesPassword() async {
        let url = "wss://voxl.mailwong.com/ws?access-test=\(UUID().uuidString)"
        let host = Host(name: "Access integration test", url: url)
        let previousHosts = Hosts.all
        Hosts.all = [host]
        Hosts.setPassword("integration-test-not-a-real-password", for: url)
        XCTAssertNotNil(Hosts.password(for: url), "The test host must be signed for Keychain access")
        let session = Session(host: host)
        defer {
            session.close()
            Hosts.setPassword(nil, for: url)
            Hosts.setAccessCredentials(nil, for: url)
            Hosts.all = previousHosts
        }
        let signIn = expectation(description: "Cloudflare redirect opens sign-in instead of reconnecting")
        self.signIn = signIn
        session.delegate = self
        session.start()
        await fulfillment(of: [signIn], timeout: 30)
        XCTAssertTrue(session.accessSignInRequired)
        XCTAssertEqual(Hosts.password(for: url), "integration-test-not-a-real-password")
        XCTAssertEqual(Hosts.all.first?.cloudflareAccess, true)
    }

    func sessionAccessRequired() { signIn?.fulfill() }
    func sessionHello(width: Int, height: Int, stripes: [Stripe], resizeScale: Double?, displays: Int, display: Int) {}
    func sessionCursor(_ image: CGImage?, hotspot: CGPoint) {}
    func sessionState(_ text: String?) {}
    func sessionAuthFailed() { XCTFail("An Access redirect must not invalidate the Voxl password") }
}
