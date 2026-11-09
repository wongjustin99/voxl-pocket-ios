import XCTest
@testable import AccessCredentials
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class AccessCredentialsTests: XCTestCase {
    func testCLITokenUsesAccessHeaderNotBrowserCookie() throws {
        let url = URL(string: "wss://desktop.example.com:8443/ws")!
        let now = Date()
        let credentials = try XCTUnwrap(AccessCredentials(token: "header.payload.signature", expires: now.addingTimeInterval(60), for: url, now: now))
        let restored = try JSONDecoder().decode(AccessCredentials.self, from: JSONEncoder().encode(credentials))
        XCTAssertEqual(restored.requestHeaders(for: url, now: now), ["CF-Access-Token": "header.payload.signature"])
        XCTAssertNil(restored.cookieHeader(for: url, now: now))
        XCTAssertNil(restored.requestHeaders(for: url, now: now.addingTimeInterval(61)))
        XCTAssertNil(restored.requestHeaders(for: URL(string: "wss://other.example.com:8443/ws")!, now: now))
        XCTAssertNil(restored.requestHeaders(for: URL(string: "wss://desktop.example.com/ws")!, now: now))
        XCTAssertNil(restored.requestHeaders(for: URL(string: "ws://desktop.example.com:8443/ws")!, now: now))
    }

    func testOnlyApplicationCookiesReachTheWebSocket() throws {
        let url = URL(string: "wss://desktop.example.com/ws")!
        let cookies = [
            cookie("CF_Authorization", "app", "desktop.example.com"),
            cookie("CF_Binding", "binding", "desktop.example.com"),
            cookie("CF_Authorization", "team", "team.cloudflareaccess.com"),
            cookie("github_session", "private", "desktop.example.com"),
        ]
        let credentials = try XCTUnwrap(AccessCredentials(cookies: cookies, for: url))
        let header = try XCTUnwrap(credentials.cookieHeader(for: url))
        XCTAssertEqual(credentials.requestHeaders(for: url), ["Cookie": header])
        XCTAssertTrue(header.contains("CF_Authorization=app"))
        XCTAssertTrue(header.contains("CF_Binding=binding"))
        XCTAssertFalse(header.contains("team"))
        XCTAssertFalse(header.contains("private"))
        XCTAssertNil(credentials.cookieHeader(for: URL(string: "wss://other.example.com/ws")!))
        XCTAssertNil(credentials.cookieHeader(for: URL(string: "ws://desktop.example.com/ws")!))
    }

    func testAccessFailuresDoNotBecomeWrongVoxlPasswords() {
        XCTAssertEqual(HandshakeFailure.classify(status: 302, challenge: nil, accessEnabled: true), .access)
        XCTAssertEqual(HandshakeFailure.classify(status: 403, challenge: nil, accessEnabled: true), .access)
        XCTAssertEqual(HandshakeFailure.classify(status: 401, challenge: nil, accessEnabled: true), .access)
        XCTAssertEqual(HandshakeFailure.classify(status: 401, challenge: "Basic realm=\"voxl\"", accessEnabled: true), .password)
        XCTAssertEqual(HandshakeFailure.classify(status: 401, challenge: nil, accessEnabled: false), .password)
        XCTAssertEqual(HandshakeFailure.classify(status: 403, challenge: nil, accessEnabled: false), .forbidden)
        XCTAssertNil(HandshakeFailure.classify(status: 101, challenge: nil, accessEnabled: true))
    }

    func testCloudflareLoginRedirectIsDetectedWithoutPriorConfiguration() {
        let location = "https://die-shoe-lease-form-pages.cloudflareaccess.com/cdn-cgi/access/login/voxl.mailwong.com"
        XCTAssertEqual(HandshakeFailure.classify(status: 302, challenge: nil, accessEnabled: false, location: location), .access)
        XCTAssertNil(HandshakeFailure.classify(status: 302, challenge: nil, accessEnabled: false, location: "https://example.com/login"))
        XCTAssertNil(HandshakeFailure.classify(status: 302, challenge: nil, accessEnabled: false, location: "https://fake-cloudflareaccess.com/cdn-cgi/access/login/host"))
        XCTAssertNil(HandshakeFailure.classify(status: 302, challenge: nil, accessEnabled: false, location: "http://team.cloudflareaccess.com/cdn-cgi/access/login/host"))
    }

    func testExpiryAndCookiePaths() throws {
        let url = URL(string: "wss://desktop.example.com/remote/ws")!
        let now = Date()
        let auth = cookie("CF_Authorization", "app", "desktop.example.com", path: "/remote", expires: now.addingTimeInterval(60))
        let credentials = try XCTUnwrap(AccessCredentials(cookies: [auth], for: url, now: now))
        XCTAssertNotNil(credentials.cookieHeader(for: url, now: now))
        XCTAssertNil(credentials.cookieHeader(for: url, now: now.addingTimeInterval(61)))
        XCTAssertNil(credentials.cookieHeader(for: URL(string: "wss://desktop.example.com/remotely/ws")!, now: now))
        XCTAssertNil(credentials.cookieHeader(for: URL(string: "wss://desktop.example.com:8443/remote/ws")!, now: now))
        let expiredBinding = cookie("CF_Binding", "binding", "desktop.example.com", expires: now.addingTimeInterval(-1))
        XCTAssertNil(AccessCredentials(cookies: [auth, expiredBinding], for: url, now: now))
        XCTAssertNil(AccessCredentials(cookies: [cookie("CF_Authorization", "parent", ".example.com")], for: url))
        XCTAssertNil(AccessCredentials(cookies: [cookie("CF_Authorization", "wrong-path", "desktop.example.com", path: "/other")], for: url))
    }

    func testStoredCredentialsRoundTripAndLoginURL() throws {
        let url = URL(string: "wss://desktop.example.com:8443/remote/ws?token=secret#fragment")!
        let credentials = try XCTUnwrap(AccessCredentials(cookies: [cookie("CF_Authorization", "app", "desktop.example.com")], for: url))
        let restored = try JSONDecoder().decode(AccessCredentials.self, from: JSONEncoder().encode(credentials))
        XCTAssertEqual(restored.cookieHeader(for: url), credentials.cookieHeader(for: url))
        XCTAssertEqual(AccessCredentials.loginURL(for: url)?.absoluteString, "https://desktop.example.com:8443/remote/ws")
        XCTAssertNil(AccessCredentials.loginURL(for: URL(string: "ws://desktop.example.com/ws")!))
    }

    func testUnrelatedBindingCookiesDoNotBlockTheApplication() throws {
        let url = URL(string: "wss://desktop.example.com/remote/ws")!
        let credentials = try XCTUnwrap(AccessCredentials(cookies: [
            cookie("CF_Authorization", "app", "desktop.example.com", path: "/remote"),
            cookie("CF_Binding", "other-app", "desktop.example.com", path: "/other"),
        ], for: url))
        XCTAssertEqual(credentials.cookieHeader(for: url), "CF_Authorization=app")
    }

    private func cookie(_ name: String, _ value: String, _ domain: String, path: String = "/", expires: Date = Date().addingTimeInterval(3600)) -> HTTPCookie {
        HTTPCookie(properties: [.name: name, .value: value, .domain: domain, .path: path, .secure: "TRUE", .expires: expires])!
    }
}
