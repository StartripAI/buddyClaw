import AppKit
import Foundation

public final class OverlayWindow: NSWindow {
    public override var canBecomeKey: Bool { false }
    public override var canBecomeMain: Bool { false }

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        level = .floating
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle,
            .auxiliary,
        ]
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        isReleasedWhenClosed = false
    }
}
