import CoreGraphics

enum PrecisionCircle {
    static let size: CGFloat = 64
    /// Distance from the pointer tip to the circle's center.
    static let offset: CGFloat = 84

    /// Places the circle below the pointer, or above it when there is no room below.
    static func center(for pointer: CGPoint, in safe: CGRect, bottom: CGFloat) -> CGPoint {
        let below = pointer.y + offset
        let y = below <= bottom ? below : max(pointer.y - offset, safe.minY)
        return CGPoint(x: min(max(pointer.x, safe.minX), safe.maxX), y: min(y, bottom))
    }
}
