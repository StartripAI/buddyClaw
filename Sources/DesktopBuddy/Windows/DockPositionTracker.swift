import AppKit
import Foundation

public enum DockSide: String, Codable, Sendable {
    case bottom
    case left
    case right
    case unknown
}

public struct DockAnchor: Sendable {
    public var side: DockSide
    public var trackMinimumX: CGFloat
    public var trackMaximumX: CGFloat
    public var baseOrigin: CGPoint

    public init(side: DockSide, trackMinimumX: CGFloat, trackMaximumX: CGFloat, baseOrigin: CGPoint) {
        self.side = side
        self.trackMinimumX = trackMinimumX
        self.trackMaximumX = trackMaximumX
        self.baseOrigin = baseOrigin
    }
}

@MainActor
public final class DockPositionTracker {
    public init() {}

    public func anchor(for screen: NSScreen, petWindowSize: CGSize) -> DockAnchor {
        let frame = screen.frame
        let visibleFrame = screen.visibleFrame

        let leftInset = visibleFrame.minX - frame.minX
        let rightInset = frame.maxX - visibleFrame.maxX
        let bottomInset = visibleFrame.minY - frame.minY

        let maximumInset = max(leftInset, rightInset, bottomInset)
        let side: DockSide

        if maximumInset <= 1 {
            side = .unknown
        } else if maximumInset == leftInset {
            side = .left
        } else if maximumInset == rightInset {
            side = .right
        } else {
            side = .bottom
        }

        let margin: CGFloat = 12

        switch side {
        case .bottom, .unknown:
            let minX = visibleFrame.minX + margin
            let maxX = max(minX, visibleFrame.maxX - petWindowSize.width - margin)
            let origin = CGPoint(x: minX, y: visibleFrame.minY + margin)
            return DockAnchor(side: side, trackMinimumX: minX, trackMaximumX: maxX, baseOrigin: origin)

        case .left:
            let x = visibleFrame.minX + margin
            let origin = CGPoint(x: x, y: frame.minY + margin)
            return DockAnchor(side: .left, trackMinimumX: x, trackMaximumX: x, baseOrigin: origin)

        case .right:
            let x = visibleFrame.maxX - petWindowSize.width - margin
            let origin = CGPoint(x: x, y: frame.minY + margin)
            return DockAnchor(side: .right, trackMinimumX: x, trackMaximumX: x, baseOrigin: origin)
        }
    }
}
