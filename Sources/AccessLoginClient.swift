import Foundation

final class AccessLoginClient {
    private final class StopRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                        newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }

    private let session: URLSession

    init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 60
        session = URLSession(configuration: configuration, delegate: StopRedirects(), delegateQueue: nil)
    }

    deinit { session.invalidateAndCancel() }

    func audience(for host: URL) async throws -> String {
        guard let url = AccessCredentials.loginURL(for: host) else { throw AccessLoginError.applicationNotFound }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15
        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AccessLoginError.applicationNotFound }
        if let location = response.value(forHTTPHeaderField: "Location"),
           HandshakeFailure.classify(status: response.statusCode, challenge: nil, accessEnabled: false, location: location) == .access,
           let components = URLComponents(string: location),
           let audience = components.queryItems?.first(where: { $0.name == "kid" })?.value, !audience.isEmpty {
            return audience
        }
        if [401, 403].contains(response.statusCode),
           let audience = response.value(forHTTPHeaderField: "cf-access-aud"), !audience.isEmpty {
            return audience
        }
        throw AccessLoginError.applicationNotFound
    }

    func verify(_ credentials: AccessCredentials, for host: URL) async throws {
        guard let url = AccessCredentials.loginURL(for: host),
              let headers = credentials.requestHeaders(for: host) else { throw AccessLoginError.invalidTransfer }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 15
        request.allHTTPHeaderFields = headers
        let (_, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw AccessLoginError.invalidTransfer }
        let accessRedirect = HandshakeFailure.classify(status: response.statusCode, challenge: nil, accessEnabled: false,
                                                      location: response.value(forHTTPHeaderField: "Location")) == .access
        if accessRedirect || response.statusCode == 403 || response.statusCode >= 500 {
            throw AccessLoginError.accessRejected(response.statusCode)
        }
    }

    func credentials(for host: URL, audience: String, transfer: AccessLoginTransfer) async throws -> AccessCredentials {
        let url = URL(string: "https://login.cloudflareaccess.org/transfer/")!.appendingPathComponent(transfer.publicKey)
        for _ in 0..<10 {
            try Task.checkCancellation()
            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(from: url)
            } catch let error as URLError where error.code == .timedOut {
                continue
            }
            guard let http = response as? HTTPURLResponse else { throw AccessLoginError.invalidTransfer }
            if http.statusCode == 200, !data.isEmpty {
                guard let sender = http.value(forHTTPHeaderField: "service-public-key") else { throw AccessLoginError.invalidTransfer }
                return try transfer.credentials(from: data, senderPublicKey: sender, for: host, audience: audience)
            }
            if http.statusCode >= 500 { throw AccessLoginError.invalidTransfer }
            try await Task.sleep(for: .seconds(1))
        }
        throw AccessLoginError.timedOut
    }
}
