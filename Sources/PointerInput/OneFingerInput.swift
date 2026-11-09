import Foundation
import CoreGraphics

enum PointerAction: Equatable {
    case point(CGPoint)
    case relative(CGPoint)
    case button(Int, Bool)
    case click(Int)
    case feedback(CGPoint)
}

struct OneFingerInput {
    static let holdDelay = 0.4
    var mode: InputMode = .trackpad
    private(set) var isActive = false
    private(set) var recognized = false
    private var start = CGPoint.zero
    private var lastPoint = CGPoint.zero
    private var beganAt: TimeInterval = 0
    private var heldButton: Int?
    private var consumedHold = false
    private var previousTaps = 0
    private var lastTapAt: TimeInterval?
    private var lastTapPoint = CGPoint.zero

    mutating func began(at point: CGPoint, time: TimeInterval) -> [PointerAction] {
        guard mode != .viewOnly else { return cancel() }
        isActive = true
        recognized = false
        consumedHold = false
        heldButton = nil
        start = point
        lastPoint = point
        beganAt = time
        if lastTapAt.map({ time - $0 > 0.35 }) ?? true || distance(point, lastTapPoint) > 32 {
            previousTaps = 0
        }
        return []
    }

    mutating func moved(to point: CGPoint, time: TimeInterval) -> [PointerAction] {
        guard isActive else { return [] }
        var actions = held(time: time)
        if consumedHold { return actions }
        if !recognized && distance(start, point) < 8 { return actions }
        if !recognized {
            recognized = true
            if mode == .touch || previousTaps > 0 {
                heldButton = 1
                if mode == .touch { actions.append(.point(start)) }
                actions.append(.button(1, true))
            }
        }
        actions.append(mode == .trackpad ? .relative(CGPoint(x: point.x - lastPoint.x, y: point.y - lastPoint.y)) : .point(point))
        lastPoint = point
        return actions
    }

    mutating func held(time: TimeInterval) -> [PointerAction] {
        guard isActive, !recognized, time - beganAt >= Self.holdDelay else { return [] }
        recognized = true
        if mode == .touch && previousTaps == 0 {
            consumedHold = true
            return [.point(start), .click(3), .feedback(start)]
        }
        let button = previousTaps >= 2 ? 2 : previousTaps == 1 ? 3 : 1
        heldButton = button
        let press: [PointerAction] = [.button(button, true), .feedback(start)]
        return mode == .touch ? [.point(start)] + press : press
    }

    mutating func ended(at point: CGPoint, time: TimeInterval) -> [PointerAction] {
        guard isActive else { return [] }
        var actions = held(time: time)
        if !consumedHold, point != lastPoint, recognized || distance(start, point) >= 8 {
            actions += moved(to: point, time: time)
        }
        if let button = heldButton {
            actions.append(.button(button, false))
            previousTaps = 0
        } else if !recognized {
            if mode == .touch { actions.append(.point(point)) }
            actions.append(.click(1))
            previousTaps = (previousTaps + 1) % 3
            lastTapAt = time
            lastTapPoint = point
        } else {
            previousTaps = 0
        }
        isActive = false
        heldButton = nil
        return actions
    }

    mutating func cancel() -> [PointerAction] {
        let actions: [PointerAction] = heldButton.map { [.button($0, false)] } ?? []
        isActive = false
        recognized = false
        heldButton = nil
        previousTaps = 0
        lastTapAt = nil
        return actions
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
