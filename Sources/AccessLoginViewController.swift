import UIKit
import SafariServices

final class AccessLoginViewController: UIViewController, SFSafariViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
    private let host: Host
    private let completion: () -> Void
    private var loginTask: Task<Void, Never>?
    private var browser: SFSafariViewController?
    private var finished = false

    init(host: Host, completion: @escaping () -> Void) {
        self.host = host
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { loginTask?.cancel() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Cloudflare Access"
        view.backgroundColor = .systemBackground
        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.cancel()
        })
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        spinner.startAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.presentationController?.delegate = self
        if loginTask == nil, !finished { startSignIn() }
    }

    private func startSignIn() {
        loginTask = Task { [weak self] in
            guard let self, let url = URL(string: self.host.url) else { return }
            let client = AccessLoginClient()
            do {
                let audience = try await client.audience(for: url)
                let transfer = try AccessLoginTransfer()
                try Task.checkCancellation()
                guard !self.finished,
                      let loginURL = AccessLoginTransfer.loginURL(for: url, audience: audience, publicKey: transfer.publicKey) else { return }
                let browser = SFSafariViewController(url: loginURL)
                browser.delegate = self
                browser.dismissButtonStyle = .cancel
                browser.modalPresentationStyle = .fullScreen
                self.browser = browser
                await self.open(browser)
                let credentials = try await client.credentials(for: url, audience: audience, transfer: transfer)
                try await client.verify(credentials, for: url)
                try Task.checkCancellation()
                guard !self.finished else { return }
                self.finished = true
                Hosts.setAccessCredentials(credentials, for: self.host.url)
                self.navigationController?.presentingViewController?.dismiss(animated: true, completion: self.completion)
            } catch {
                guard !Task.isCancelled, !self.finished else { return }
                self.show(error)
            }
        }
    }

    private func open(_ browser: SFSafariViewController) async {
        await withCheckedContinuation { continuation in
            present(browser, animated: true) { continuation.resume() }
        }
    }

    private func cancel() {
        finished = true
        loginTask?.cancel()
        navigationController?.presentingViewController?.dismiss(animated: true)
    }

    func safariViewControllerDidFinish(_ controller: SFSafariViewController) { cancel() }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finished = true
        loginTask?.cancel()
    }

    private func show(_ error: Error) {
        let alert = UIAlertController(title: "Sign-in failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Try Again", style: .default) { [weak self] _ in self?.startSignIn() })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in self?.cancel() })
        if let browser {
            self.browser = nil
            browser.dismiss(animated: true) { [weak self] in self?.present(alert, animated: true) }
        } else {
            present(alert, animated: true)
        }
    }
}
