import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

enum HandshakeFailure: Equatable {
    case password, access, forbidden

    static func classify(status: Int, challenge: String?, accessEnabled: Bool, location: String? = nil) -> Self? {
        if [301, 302, 303, 307, 308].contains(status),
           let url = location.flatMap(URL.init(string:)), url.scheme == "https",
           url.host?.hasSuffix(".cloudflareaccess.com") == true,
           url.path.hasPrefix("/cdn-cgi/access/login/") { return .access }
        if status == 401 && (!accessEnabled || challenge?.lowercased().hasPrefix("basic ") == true) { return .password }
        if accessEnabled && ([301, 302, 303, 307, 308, 401, 403].contains(status)) { return .access }
        if status == 403 { return .forbidden }
        return nil
    }
}

struct AccessCredentials: Codable {
    private struct Cookie: Codable {
        let name: String
        let value: String
        let path: String
        let expires: Date?

        func matchesPath(_ url: URL) -> Bool {
            let target = url.path.isEmpty ? "/" : url.path
            return target == path || (target.hasPrefix(path) && (path.hasSuffix("/") || target.dropFirst(path.count).hasPrefix("/")))
        }

        func isValid(at now: Date) -> Bool { expires.map { $0 > now } ?? true }
    }

    private struct Token: Codable {
        let value: String
        let expires: Date
    }

    private let host: String
    private let port: Int
    private let cookies: [Cookie]
    private let token: Token?

    init?(token: String, expires: Date, for url: URL, now: Date = Date()) {
        let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.")
        guard url.scheme == "wss", let host = url.host?.lowercased(), expires > now,
              !token.isEmpty, token.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        self.host = host
        port = url.port ?? 443
        cookies = []
        self.token = Token(value: token, expires: expires)
    }

    func requestHeaders(for url: URL, now: Date = Date()) -> [String: String]? {
        if let token {
            guard url.scheme == "wss", url.host?.lowercased() == host,
                  (url.port ?? 443) == port, token.expires > now else { return nil }
            return ["CF-Access-Token": token.value]
        }
        return cookieHeader(for: url, now: now).map { ["Cookie": $0] }
    }

    init?(cookies: [HTTPCookie], for url: URL, now: Date = Date()) {
        guard url.scheme == "wss", let host = url.host?.lowercased() else { return nil }
        self.host = host
        port = url.port ?? 443
        token = nil
        self.cookies = cookies.filter {
            ["CF_Authorization", "CF_Binding"].contains($0.name) &&
            $0.domain.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) == host && $0.isSecure
        }.map { Cookie(name: $0.name, value: $0.value, path: $0.path, expires: $0.expiresDate) }
        guard cookieHeader(for: url, now: now) != nil else { return nil }
    }

    func cookieHeader(for url: URL, now: Date = Date()) -> String? {
        guard url.scheme == "wss", url.host?.lowercased() == host, (url.port ?? 443) == port else { return nil }
        let scoped = cookies.filter { $0.matchesPath(url) }
        let matching = scoped.filter { $0.isValid(at: now) }
        guard matching.contains(where: { $0.name == "CF_Authorization" }),
              !scoped.contains(where: { $0.name == "CF_Binding" && !$0.isValid(at: now) }) else { return nil }
        return matching.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    static func loginURL(for url: URL) -> URL? {
        guard url.scheme == "wss", var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.scheme = "https"
        parts.query = nil
        parts.fragment = nil
        return parts.url
    }
}
