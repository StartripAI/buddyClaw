import AppKit
import Foundation
import SwiftUI

@MainActor
public final class WindowManager {
    private let window: OverlayWindow
    private let dockTracker = DockPositionTracker()
    private let animator: SpriteAnimator
    private let bubbleManager: SpeechBubbleManager
    private let companionProvider: () -> Companion
    private let growthProvider: () -> GrowthState
    private let settingsProvider: () -> DesktopBuddySettings
    private let onPet: () -> Void
    private let onTalk: () -> Void

    private var hostingController: NSHostingController<PetOverlayView>?
    private var movementTimer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var currentX: CGFloat = 80
    private var direction: CGFloat = 1

    public init(
        animator: SpriteAnimator,
        bubbleManager: SpeechBubbleManager,
        companionProvider: @escaping () -> Companion,
        growthProvider: @escaping () -> GrowthState,
        settingsProvider: @escaping () -> DesktopBuddySettings,
        onPet: @escaping () -> Void,
        onTalk: @escaping () -> Void
    ) {
        self.animator = animator
        self.bubbleManager = bubbleManager
        self.companionProvider = companionProvider
        self.growthProvider = growthProvider
        self.settingsProvider = settingsProvider
        self.onPet = onPet
        self.onTalk = onTalk

        self.window = OverlayWindow(contentRect: NSRect(x: 100, y: 100, width: 260, height: 260))
        buildContent()
    }

    deinit {
        movementTimer?.invalidate()
        movementTimer = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    public func start() {
        window.orderFrontRegardless()
        reposition(resetTrack: true)

        movementTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tickMovement()
            }
        }

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.reposition(resetTrack: false)
            }
        }
    }

    public func stop() {
        movementTimer?.invalidate()
        movementTimer = nil

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
            self.screenObserver = nil
        }
    }

    public func reposition(resetTrack: Bool) {
        guard let targetScreen = targetScreen() else { return }
        let anchor = dockTracker.anchor(for: targetScreen, petWindowSize: window.frame.size)

        if resetTrack {
            currentX = anchor.trackMinimumX
        } else {
            currentX = min(max(currentX, anchor.trackMinimumX), anchor.trackMaximumX)
        }

        let newOrigin = CGPoint(x: currentX, y: anchor.baseOrigin.y)
        window.setFrameOrigin(newOrigin)
    }

    public func refreshContent() {
        buildContent()
        reposition(resetTrack: false)
    }

    private func buildContent() {
        let rootView = PetOverlayView(
            animator: animator,
            bubbleManager: bubbleManager,
            onPet: onPet,
            onTalk: onTalk
        )

        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let hostingController = NSHostingController(rootView: rootView)
            hostingController.view.wantsLayer = true
            hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
            window.contentViewController = hostingController
            self.hostingController = hostingController
        }
    }

    private func tickMovement() {
        guard settingsProvider().movementEnabled else {
            animator.setState(.idle)
            return
        }

        guard let screen = targetScreen() else { return }
        let anchor = dockTracker.anchor(for: screen, petWindowSize: window.frame.size)
        let stage = growthProvider().stage

        switch anchor.side {
        case .bottom, .unknown:
            if animator.isTransientBusy {
                window.setFrameOrigin(CGPoint(x: currentX, y: anchor.baseOrigin.y))
                return
            }

            currentX += direction * 3
            if currentX <= anchor.trackMinimumX {
                currentX = anchor.trackMinimumX
                direction = 1
            } else if currentX >= anchor.trackMaximumX {
                currentX = anchor.trackMaximumX
                direction = -1
            }

            let walkState: AnimationState = direction < 0 ? .walkLeft : .walkRight
            if stage.unlockedAnimations.contains(walkState) {
                animator.setState(walkState)
            } else {
                animator.setState(.idle)
            }

            let ambientRoll = Int.random(in: 0 ..< 100)
            if ambientRoll < 3, stage.unlockedAnimations.contains(.jump) {
                animator.setState(.jump, duration: 0.8, fallBackTo: walkState)
            } else if ambientRoll >= 3, ambientRoll < 6, stage.unlockedAnimations.contains(.sit) {
                animator.setState(.sit, duration: 2.0, fallBackTo: walkState)
            } else if ambientRoll == 99, stage.unlockedAnimations.contains(.sleep) {
                animator.setState(.sleep, duration: 4.0, fallBackTo: walkState)
            }

            window.setFrameOrigin(CGPoint(x: currentX, y: anchor.baseOrigin.y))

        case .left, .right:
            animator.setState(.idle)
            currentX = anchor.baseOrigin.x
            window.setFrameOrigin(anchor.baseOrigin)
        }
    }

    private func targetScreen() -> NSScreen? {
        NSScreen.main ?? NSScreen.screens.first
    }
}
