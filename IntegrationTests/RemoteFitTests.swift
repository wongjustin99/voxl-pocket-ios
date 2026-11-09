import XCTest
import UIKit
@testable import VoxlPocket

final class RemoteFitTests: XCTestCase {
    /// A desktop somewhat smaller than the screen's pixels (1920x1080 on an iPad mini) is
    /// stretched to the screen's edge; only a nearly exact match is kept 1:1.
    @MainActor
    func testDesktopFillsTheScreenUnlessItNearlyMatchesItsPixels() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let remote = RemoteViewController(host: Host(name: "Fit test", url: "wss://fit.invalid/\(UUID().uuidString)"))
        window.rootViewController = UINavigationController(rootViewController: remote)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }
        window.layoutIfNeeded()
        let view = try XCTUnwrap(remote.view)
        let desk = try XCTUnwrap(view.subviews.first)
        let pixels = CGSize(width: view.bounds.width * scene.screen.nativeScale,
                            height: view.bounds.height * scene.screen.nativeScale)

        // 85% of the screen's pixels each way, as the iPad mini shows a 1920x1080 stream.
        remote.sessionHello(width: Int(pixels.width / 1.18), height: Int(pixels.height / 1.18),
                            stripes: [], resizeScale: nil, displays: 1, display: 0)
        XCTAssertEqual(desk.frame.width, view.bounds.width, accuracy: 2)

        remote.sessionHello(width: Int(pixels.width / 1.02), height: Int(pixels.height / 1.02),
                            stripes: [], resizeScale: nil, displays: 1, display: 0)
        XCTAssertEqual(desk.frame.width, view.bounds.width / 1.02, accuracy: 2)
    }
}
