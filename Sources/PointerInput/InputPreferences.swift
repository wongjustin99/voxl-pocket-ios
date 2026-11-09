import Foundation
import CoreGraphics

enum InputMode: String, Codable, CaseIterable {
    case trackpad, touch, viewOnly

    var title: String {
        switch self {
        case .trackpad: return "Trackpad mode"
        case .touch: return "Touch mode"
        case .viewOnly: return "View only"
        }
    }

    var symbol: String {
        switch self {
        case .trackpad: return "rectangle.and.hand.point.up.left"
        case .touch: return "hand.point.up.left"
        case .viewOnly: return "eye"
        }
    }
}

struct InputPreferences: Codable, Equatable {
    var mode: InputMode = .trackpad
    var reverseScroll = false
    var showCircle = false

    func scrollDelta(_ delta: CGPoint, scale: CGFloat) -> CGPoint {
        guard mode != .viewOnly else { return .zero }
        let direction: CGFloat = reverseScroll ? 1 : -1
        return CGPoint(x: delta.x * scale * direction, y: delta.y * scale * direction)
    }

    func allows(_ message: String) -> Bool {
        guard mode == .viewOnly else { return true }
        let command = message.split(separator: ",", maxSplits: 1).first.map(String.init) ?? ""
        return ["v", "a", "au", "kf", "po", "r"].contains(command)
    }
}
