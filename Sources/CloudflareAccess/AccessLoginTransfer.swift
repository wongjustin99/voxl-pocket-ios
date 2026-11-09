import Foundation
import Sodium

enum AccessLoginError: LocalizedError {
    case applicationNotFound, invalidTransfer, timedOut
    case accessRejected(Int)

    var errorDescription: String? {
        switch self {
        case .applicationNotFound: return "Could not find a Cloudflare Access application at this host."
        case .invalidTransfer: return "Cloudflare returned an invalid sign-in token. Please try again."
        case .timedOut: return "Sign-in timed out. Please try again."
        case .accessRejected(let status): return "The host rejected the returned Access token (HTTP \(status)). Check the Cloudflare Access policy, including whether it requires browser-bound cookies."
        }
    }
}

struct AccessLoginTransfer {
    private let keyPair: Box.KeyPair

    init() throws {
        guard let keyPair = Sodium().box.keyPair() else { throw AccessLoginError.invalidTransfer }
        self.keyPair = keyPair
    }

    var publicKey: String {
        Data(keyPair.publicKey).base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_")
    }

    // Cloudflared's transfer protocol: base64(nonce || NaCl box), with the sender key in a response header.
    func credentials(from data: Data, senderPublicKey: String, for url: URL, audience: String, now: Date = Date()) throws -> AccessCredentials {
        guard let encoded = String(data: data, encoding: .utf8),
              let encrypted = Data(base64Encoded: encoded),
              let sender = Self.decodeBase64URL(senderPublicKey), sender.count == 32,
              let decrypted = Sodium().box.open(nonceAndAuthenticatedCipherText: Array(encrypted),
                                                senderPublicKey: Array(sender), recipientSecretKey: keyPair.secretKey) else {
            throw AccessLoginError.invalidTransfer
        }
        struct Response: Decodable { let app_token: String }
        struct Claims: Decodable {
            let aud: [String]
            let exp: TimeInterval
        }
        let token = try JSONDecoder().decode(Response.self, from: Data(decrypted)).app_token
        let parts = token.split(separator: ".", omittingEmptySubsequences: false)
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.")
        guard parts.count == 3, !parts.contains(where: { $0.isEmpty }),
              token.unicodeScalars.allSatisfy(allowed.contains),
              let payload = Self.decodeBase64URL(String(parts[1])),
              let claims = try? JSONDecoder().decode(Claims.self, from: payload),
              claims.aud.contains(audience), claims.exp > now.timeIntervalSince1970,
              let credentials = AccessCredentials(token: token, expires: Date(timeIntervalSince1970: claims.exp), for: url, now: now) else {
            throw AccessLoginError.invalidTransfer
        }
        return credentials
    }

    private static func decodeBase64URL(_ value: String) -> Data? {
        let base64 = value.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        return Data(base64Encoded: base64 + String(repeating: "=", count: (4 - base64.count % 4) % 4))
    }

    static func loginURL(for url: URL, audience: String, publicKey: String) -> URL? {
        guard let application = AccessCredentials.loginURL(for: url),
              var parts = URLComponents(url: application, resolvingAgainstBaseURL: false) else { return nil }
        parts.queryItems = [URLQueryItem(name: "aud", value: audience), URLQueryItem(name: "token", value: publicKey)]
        let redirect = parts.url!.absoluteString
        parts.path = "/cdn-cgi/access/cli"
        parts.queryItems! += [
            URLQueryItem(name: "redirect_url", value: redirect),
            URLQueryItem(name: "send_org_token", value: "true"),
            URLQueryItem(name: "edge_token_transfer", value: "true"),
        ]
        return parts.url
    }
}
