import XCTest
import Sodium
@testable import VoxlPocket

final class AccessLoginClientTests: XCTestCase {
    private final class Stub: URLProtocol {
        static var reply: (URLRequest) -> (Int, [String: String], Data) = { _ in (500, [:], Data()) }
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            let (status, headers, data) = Self.reply(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func client() -> AccessLoginClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Stub.self]
        return AccessLoginClient(configuration: configuration)
    }

    func testDiscoversAudienceWithoutFollowingLoginOrSendingCredentials() async throws {
        Stub.reply = { request in
            XCTAssertEqual(request.httpMethod, "HEAD")
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.url?.absoluteString, "https://desktop.example.com/remote/ws")
            return (302, ["Location": "https://team.cloudflareaccess.com/cdn-cgi/access/login/desktop.example.com?kid=app-aud"], Data())
        }
        let audience = try await client().audience(for: URL(string: "wss://desktop.example.com/remote/ws?secret=hidden")!)
        XCTAssertEqual(audience, "app-aud")
    }

    func testRejectsNonAccessAndInsecureLoginRedirects() async {
        for location in ["https://attacker.example.com/cdn-cgi/access/login/host?kid=bad", "http://team.cloudflareaccess.com/cdn-cgi/access/login/host?kid=bad"] {
            Stub.reply = { _ in (302, ["Location": location], Data()) }
            do {
                _ = try await client().audience(for: URL(string: "wss://desktop.example.com/ws")!)
                XCTFail("Accepted an invalid Access redirect")
            } catch { XCTAssertTrue(error is AccessLoginError) }
        }
    }

    func testReceivesEncryptedApplicationToken() async throws {
        let transfer = try AccessLoginTransfer()
        let sender = try XCTUnwrap(Sodium().box.keyPair())
        let recipient = try XCTUnwrap(Data(base64Encoded: transfer.publicKey.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")))
        let claims = Data("{\"aud\":[\"app-aud\"],\"exp\":\(Int(Date().timeIntervalSince1970) + 300)}".utf8).base64EncodedString().replacingOccurrences(of: "=", with: "")
        let token = "e30.\(claims).signature"
        let message = Array("{\"app_token\":\"\(token)\"}".utf8)
        let sealed: [UInt8]? = Sodium().box.seal(message: message, recipientPublicKey: Array(recipient), senderSecretKey: sender.secretKey)
        let encrypted = try XCTUnwrap(sealed)
        let senderKey = Data(sender.publicKey).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        Stub.reply = { request in
            XCTAssertEqual(request.url?.lastPathComponent, transfer.publicKey)
            return (200, ["service-public-key": senderKey], Data(Data(encrypted).base64EncodedString().utf8))
        }
        let host = URL(string: "wss://desktop.example.com/ws")!
        let credentials = try await client().credentials(for: host, audience: "app-aud", transfer: transfer)
        XCTAssertEqual(credentials.requestHeaders(for: host), ["CF-Access-Token": token])
        XCTAssertNil(credentials.cookieHeader(for: host))
    }

    func testChecksReturnedTokenAgainstHostAndReportsAccessRejection() async throws {
        let host = URL(string: "wss://desktop.example.com/ws")!
        let credentials = try XCTUnwrap(AccessCredentials(token: "header.payload.signature", expires: Date().addingTimeInterval(60), for: host))
        Stub.reply = { request in
            XCTAssertEqual(request.httpMethod, "HEAD")
            XCTAssertEqual(request.url?.absoluteString, "https://desktop.example.com/ws")
            XCTAssertEqual(request.value(forHTTPHeaderField: "CF-Access-Token"), "header.payload.signature")
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            return (401, ["WWW-Authenticate": "Basic realm=\"voxl\""], Data())
        }
        try await client().verify(credentials, for: host)
        let rejections: [(Int, [String: String])] = [
            (403, [:]),
            (302, ["Location": "https://team.cloudflareaccess.com/cdn-cgi/access/login/desktop.example.com"]),
            (500, [:]),
        ]
        for (expectedStatus, headers) in rejections {
            Stub.reply = { _ in (expectedStatus, headers, Data()) }
            do {
                try await client().verify(credentials, for: host)
                XCTFail("Rejected Access token was accepted")
            } catch AccessLoginError.accessRejected(let status) {
                XCTAssertEqual(status, expectedStatus)
            }
        }
    }

    func testCancellationStopsTokenPolling() async throws {
        let polled = expectation(description: "Transfer requested")
        Stub.reply = { request in
            XCTAssertEqual(request.url?.host, "login.cloudflareaccess.org")
            XCTAssertTrue(request.url!.path.hasPrefix("/transfer/"))
            XCTAssertNil(request.value(forHTTPHeaderField: "Cookie"))
            polled.fulfill()
            return (404, [:], Data())
        }
        let client = client()
        let transfer = try AccessLoginTransfer()
        let task = Task {
            try await client.credentials(for: URL(string: "wss://desktop.example.com/ws")!, audience: "app-aud", transfer: transfer)
        }
        await fulfillment(of: [polled], timeout: 2)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled sign-in returned credentials")
        } catch { XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled) }
    }
}
