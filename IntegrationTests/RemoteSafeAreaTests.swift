import XCTest
import UIKit
@testable import VoxlPocket

final class RemoteSafeAreaTests: XCTestCase {
    @MainActor
    func testRemoteControlsStayInsideTheSafeArea() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        let remote = RemoteViewController(host: Host(name: "Layout test", url: "wss://layout.invalid/\(UUID().uuidString)"))
        window.rootViewController = UINavigationController(rootViewController: remote)
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousWindow?.makeKeyAndVisible()
        }
        for insets in [UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0),
                       UIEdgeInsets(top: 0, left: 59, bottom: 21, right: 59)] {
            remote.additionalSafeAreaInsets = insets
            window.layoutIfNeeded()
            remote.view.layoutIfNeeded()
            let safeFrame = remote.view.safeAreaLayoutGuide.layoutFrame
            for label in ["Hosts", "Text size", "Trackpad mode"] {
                let button = try XCTUnwrap(descendants(of: remote.view).first { $0.accessibilityLabel == label })
                let frame = button.convert(button.bounds, to: remote.view)
                XCTAssertGreaterThanOrEqual(frame.minY, safeFrame.minY + 12, label)
                XCTAssertGreaterThanOrEqual(frame.minX, safeFrame.minX + 12, label)
                XCTAssertLessThanOrEqual(frame.maxX, safeFrame.maxX - 12, label)
            }
        }
    }

    private func descendants(of view: UIView) -> [UIView] {
        view.subviews.flatMap { [$0] + descendants(of: $0) }
    }
}
