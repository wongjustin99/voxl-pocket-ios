import XCTest
import Sodium
@testable import AccessCredentials

final class AccessLoginTransferTests: XCTestCase {
    func testEncryptedTransferBecomesHostScopedExpiringCredentials() throws {
        let transfer = try AccessLoginTransfer()
        let sender = try XCTUnwrap(Sodium().box.keyPair())
        let recipient = try XCTUnwrap(Data(base64Encoded: transfer.publicKey.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")))
        let now = Date()
        let expiry = Int(now.timeIntervalSince1970) + 3600
        let payload = Data("{\"aud\":[\"app-aud\"],\"exp\":\(expiry)}".utf8).base64EncodedString()
            .replacingOccurrences(of: "=", with: "")
        let token = "e30.\(payload).signature"
        let message = Data("{\"app_token\":\"\(token)\",\"org_token\":\"not-for-storage\"}".utf8)
        let sealed: [UInt8]? = Sodium().box.seal(message: Array(message), recipientPublicKey: Array(recipient), senderSecretKey: sender.secretKey)
        let encrypted = try XCTUnwrap(sealed)
        let data = Data(Data(encrypted).base64EncodedString().utf8)
        let senderKey = Data(sender.publicKey).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
        let host = URL(string: "wss://desktop.example.com/ws")!
        let credentials = try transfer.credentials(from: data, senderPublicKey: senderKey, for: host, audience: "app-aud", now: now)
        XCTAssertEqual(credentials.cookieHeader(for: host, now: now), "CF_Authorization=\(token)")
        XCTAssertNil(credentials.cookieHeader(for: host, now: Date(timeIntervalSince1970: TimeInterval(expiry + 1))))
        XCTAssertNil(credentials.cookieHeader(for: URL(string: "wss://other.example.com/ws")!))
        XCTAssertThrowsError(try transfer.credentials(from: data, senderPublicKey: senderKey, for: host, audience: "wrong-aud"))
        XCTAssertThrowsError(try transfer.credentials(from: data, senderPublicKey: senderKey, for: host, audience: "app-aud", now: Date(timeIntervalSince1970: TimeInterval(expiry + 1))))
        var tampered = encrypted
        tampered[tampered.count - 1] ^= 1
        XCTAssertThrowsError(try transfer.credentials(from: Data(Data(tampered).base64EncodedString().utf8), senderPublicKey: senderKey, for: host, audience: "app-aud"))
    }

    func testLoginURLPreservesApplicationPathButDropsSecrets() throws {
        let host = URL(string: "wss://desktop.example.com:8443/remote/ws?password=secret#fragment")!
        let url = try XCTUnwrap(AccessLoginTransfer.loginURL(for: host, audience: "app-aud", publicKey: "key+/="))
        let parts = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: parts.queryItems!.map { ($0.name, $0.value!) })
        XCTAssertEqual(parts.scheme, "https")
        XCTAssertEqual(parts.host, "desktop.example.com")
        XCTAssertEqual(parts.port, 8443)
        XCTAssertEqual(parts.path, "/cdn-cgi/access/cli")
        XCTAssertEqual(query["aud"], "app-aud")
        XCTAssertEqual(query["token"], "key+/=")
        XCTAssertEqual(query["edge_token_transfer"], "true")
        let redirect = try XCTUnwrap(query["redirect_url"].flatMap(URL.init(string:)))
        XCTAssertEqual(redirect.path, "/remote/ws")
        XCTAssertFalse(url.absoluteString.contains("secret"))
        XCTAssertNil(AccessLoginTransfer.loginURL(for: URL(string: "ws://desktop.example.com/ws")!, audience: "app-aud", publicKey: "key"))
    }
}
