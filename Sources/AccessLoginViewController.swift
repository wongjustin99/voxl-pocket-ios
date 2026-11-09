import UIKit
import WebKit

final class AccessLoginViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIAdaptivePresentationControllerDelegate {
    private let host: Host
    private let completion: () -> Void
    private let webView: WKWebView
    private var finished = false

    init(host: Host, completion: @escaping () -> Void) {
        self.host = host
        self.completion = completion
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cloudflare Access"
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.finished = true
            self?.webView.stopLoading()
            self?.dismiss(animated: true)
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .refresh, primaryAction: UIAction { [weak self] _ in
            self?.webView.reload()
        })
        view = webView
        webView.navigationDelegate = self
        webView.uiDelegate = self
        guard let url = URL(string: host.url).flatMap(AccessCredentials.loginURL) else { return }
        webView.load(URLRequest(url: url))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.presentationController?.delegate = self
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finished = true
        webView.stopLoading()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if isApplicationURL(webView.url) { captureCookies() }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.isForMainFrame, isApplicationURL(navigationResponse.response.url) {
            captureCookies()
        }
        decisionHandler(.allow)
    }

    private func isApplicationURL(_ url: URL?) -> Bool {
        guard let target = URL(string: host.url).flatMap(AccessCredentials.loginURL), let url else { return false }
        return url.scheme == target.scheme && url.host == target.host &&
            (url.port ?? 443) == (target.port ?? 443) && url.path == target.path
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        navigationItem.prompt = webView.url?.host
    }

    private func captureCookies() {
        guard !finished, let url = URL(string: host.url) else { return }
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.finished, self.navigationController?.isBeingDismissed == false,
                  let credentials = AccessCredentials(cookies: cookies, for: url) else { return }
            self.finished = true
            Hosts.setAccessCredentials(credentials, for: self.host.url)
            self.webView.stopLoading()
            self.dismiss(animated: true, completion: self.completion)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Login pages may change domains, but must never downgrade credentials to HTTP.
        decisionHandler(navigationAction.request.url?.scheme == "https" ? .allow : .cancel)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, navigationAction.request.url?.scheme == "https" {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPBasic,
           challenge.protectionSpace.host == URL(string: host.url)?.host {
            // Access may be complete even though Voxl now asks the browser for its own password.
            captureCookies()
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        show(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { show(error) }

    private func show(_ error: Error) {
        guard !finished, ![NSURLErrorCancelled, NSURLErrorUserCancelledAuthentication].contains((error as NSError).code),
              presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Sign-in failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
