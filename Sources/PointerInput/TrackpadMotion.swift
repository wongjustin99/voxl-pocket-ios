import Foundation
import CoreGraphics

struct TrackpadMotion {
    private var lastTime: TimeInterval?

    mutating func reset(at time: TimeInterval? = nil) { lastTime = time }

    mutating func move(_ delta: CGPoint, at time: TimeInterval, precision: Bool = false) -> CGPoint {
        if precision { return delta }
        let elapsed = lastTime.map { time - $0 }
        lastTime = time
        guard let elapsed, elapsed > 0 else { return delta }
        // Speed is measured in screen points before desktop scaling or zoom.
        let speed = hypot(delta.x, delta.y) / elapsed
        let t = min(max((speed - 120) / 780, 0), 1)
        let gain = 1 + t * t * (3 - 2 * t)
        return CGPoint(x: delta.x * gain, y: delta.y * gain)
    }
}
