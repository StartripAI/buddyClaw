import AppKit
import Combine
import Foundation

@MainActor
public final class SpriteAnimator: ObservableObject {
    @Published public private(set) var currentFrameImage: NSImage
    @Published public private(set) var currentState: AnimationState = .idle
    @Published public private(set) var currentYOffset: CGFloat = 0
    @Published public private(set) var glowOpacity: Double = 0

    public let heartBurstEffect = HeartBurstEffect()

    public private(set) var companion: Companion
    public private(set) var scale: Double
    public private(set) var artStyle: ArtStyle

    private let idleSequencer = IdleSequencer()
    private let spriteCatalog = VerifiedSpriteCatalog()
    private let asciiFallbackEnabled = ProcessInfo.processInfo.environment["BUDDYCLAW_ENABLE_ASCII_FALLBACK"] == "1"
    private var timer: Timer?
    private var tickCount = 0
    private var stateStartedAt = Date()
    private var stateDuration: TimeInterval?
    private var fallbackState: AnimationState = .idle
    private var spriteSheetImage: NSImage?

    private let frameSide: CGFloat = 64
    private let spritesheetRows: [AnimationState: (row: Int, count: Int)] = [
        .idle: (0, 4),
        .walkRight: (1, 6),
        .walkLeft: (2, 6),
        .sit: (3, 2),
        .sleep: (4, 3),
        .jump: (5, 4),
        .talk: (6, 3),
        .pet: (7, 4),
        .evolve: (8, 8),
        .blink: (9, 2),
    ]

    public init(companion: Companion, scale: Double = 2.0, artStyle: ArtStyle = .pixel) {
        self.companion = companion
        self.scale = scale
        self.artStyle = artStyle
        self.currentFrameImage = NSImage(size: NSSize(width: frameSide * CGFloat(scale), height: frameSide * CGFloat(scale)))
        loadSpriteSheetIfAvailable()
        start()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    public var preferredCanvasSize: CGSize {
        CGSize(width: frameSide * scale, height: frameSide * scale)
    }

    public var isTransientBusy: Bool {
        stateDuration != nil && currentState != .walkLeft && currentState != .walkRight && currentState != .idle
    }


    public func start() {
        guard timer == nil else { return }
        renderCurrentFrame()

        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 12.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        heartBurstEffect.stop()
    }

    public func updateCompanion(_ companion: Companion, artStyle: ArtStyle) {
        self.companion = companion
        self.artStyle = artStyle
        loadSpriteSheetIfAvailable()
        renderCurrentFrame()
    }

    public func updateScale(_ scale: Double) {
        self.scale = scale
        renderCurrentFrame()
    }

    public func setState(
        _ state: AnimationState,
        duration: TimeInterval? = nil,
        fallBackTo fallbackState: AnimationState = .idle
    ) {
        guard currentState.canTransition(to: state) else { return }
        currentState = state
        self.stateDuration = duration
        self.fallbackState = fallbackState
        self.stateStartedAt = .now
        renderCurrentFrame()
    }

    public func pet() {
        heartBurstEffect.emitBurst()
        setState(.pet, duration: 1.4, fallBackTo: .idle)
    }

    public func talkPulse(duration: TimeInterval = 1.2) {
        setState(.talk, duration: duration, fallBackTo: .idle)
    }

    public func triggerEvolution() {
        setState(.evolve, duration: 3.2, fallBackTo: .idle)
    }

    private func tick() {
        tickCount += 1

        if let stateDuration,
           Date().timeIntervalSince(stateStartedAt) >= stateDuration {
            currentState = fallbackState
            self.stateDuration = nil
            self.stateStartedAt = .now
        }

        renderCurrentFrame()
    }

    private func renderCurrentFrame() {
        let asciiFrameCount = max(1, spriteFrameCount(species: companion.species))
        let (frameIndex, shouldBlink) = currentAnimationFrameIndex(asciiFrameCount: asciiFrameCount)
        let image: NSImage
        if let spriteImage = renderSpriteSheetFrameIfPossible(frameIndex: frameIndex) {
            image = spriteImage
        } else if asciiFallbackEnabled || artStyle == .ascii {
            image = renderASCIIFrame(frameIndex: frameIndex, blink: shouldBlink)
        } else {
            image = NSImage(size: preferredCanvasSize)
        }
        currentFrameImage = image
    }

    private func currentAnimationFrameIndex(asciiFrameCount: Int) -> (Int, Bool) {
        var blink = false
        var index = 0
        currentYOffset = 0
        glowOpacity = 0

        switch currentState {
        case .idle:
            let result = idleSequencer.frame(forTick: tickCount / 6, frameCount: asciiFrameCount)
            blink = result.shouldBlink
            index = result.frameIndex

        case .blink:
            blink = true
            index = 0

        case .walkLeft, .walkRight:
            index = (tickCount / 2) % max(1, asciiFrameCount)
            currentYOffset = tickCount.isMultiple(of: 2) ? 0 : 1.5

        case .sit:
            index = min(1, asciiFrameCount - 1)
            currentYOffset = 0

        case .sleep:
            index = (tickCount / 8) % max(1, asciiFrameCount)
            currentYOffset = 0

        case .jump:
            let phase = tickCount % 4
            let offsets: [CGFloat] = [0, 10, 16, 4]
            currentYOffset = offsets[phase]
            index = min(2, asciiFrameCount - 1)

        case .pet:
            index = (tickCount / 2) % max(1, asciiFrameCount)
            currentYOffset = tickCount.isMultiple(of: 3) ? 0 : 2

        case .talk:
            index = (tickCount / 2) % max(1, asciiFrameCount)
            currentYOffset = tickCount.isMultiple(of: 4) ? 0 : 1

        case .evolve:
            index = (tickCount / 1) % max(1, asciiFrameCount)
            glowOpacity = (sin(Double(tickCount) / 1.5) + 1) * 0.35 + 0.15
            currentYOffset = tickCount.isMultiple(of: 2) ? 0 : 2
        }

        return (index, blink)
    }

    private func renderSpriteSheetFrameIfPossible(frameIndex: Int) -> NSImage? {
        guard let spriteSheetImage,
              let cgImage = spriteSheetImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // --- V1 Production Format: 1024x256, 4x1 horizontal strip, 256px frames ---
        // This is the primary format for all BuddyClaw V1 spritesheets.
        if cgImage.width == 1024 && cgImage.height == 256 {
            let v1FrameSide = 256
            let actualFrameIndex = frameIndex % 4
            let originX = actualFrameIndex * v1FrameSide
            let originY = 0

            guard let cropped = cgImage.cropping(to: CGRect(x: originX, y: originY, width: v1FrameSide, height: v1FrameSide)) else {
                return nil
            }

            return drawSpriteFrame(
                cropped,
                sourceSize: NSSize(width: v1FrameSide, height: v1FrameSide),
                mirroredHorizontally: currentState == .walkLeft
            )
        }

        // --- Legacy Formats (backward compatibility) ---
        let pixelFrame = Int(frameSide)
        var originX = 0
        var originY = 0

        if cgImage.width == 256 && cgImage.height == 64 {
            // Legacy 4x1 horizontal strip (64px frames)
            let actualFrameIndex = frameIndex % 4
            originX = actualFrameIndex * pixelFrame
            originY = 0
        } else if cgImage.width == 128 && cgImage.height == 128 {
            // Legacy 2x2 grid (64px frames)
            let actualFrameIndex = frameIndex % 4
            let col = actualFrameIndex % 2
            let row = actualFrameIndex / 2
            originX = col * pixelFrame
            originY = cgImage.height - ((row + 1) * pixelFrame) 
        } else if let layout = spritesheetRows[currentState] {
            // Legacy multi-row spritesheet
            let actualFrameIndex = frameIndex % max(1, layout.count)
            originX = actualFrameIndex * pixelFrame
            originY = cgImage.height - ((layout.row + 1) * pixelFrame)
        } else {
            return nil
        }

        guard originX >= 0,
              originY >= 0,
              originX + pixelFrame <= cgImage.width,
              originY + pixelFrame <= cgImage.height,
              let cropped = cgImage.cropping(to: CGRect(x: originX, y: originY, width: pixelFrame, height: pixelFrame)) else {
            return nil
        }

        return drawSpriteFrame(
            cropped,
            sourceSize: NSSize(width: pixelFrame, height: pixelFrame),
            mirroredHorizontally: false
        )
    }

    private func drawSpriteFrame(
        _ cropped: CGImage,
        sourceSize: NSSize,
        mirroredHorizontally: Bool
    ) -> NSImage {
        let image = NSImage(size: preferredCanvasSize)
        image.lockFocus()
        guard let context = NSGraphicsContext.current else {
            image.unlockFocus()
            return image
        }

        context.imageInterpolation = .none

        let destination = CGRect(origin: .zero, size: preferredCanvasSize)
        let frameImage = NSImage(cgImage: cropped, size: sourceSize)

        if mirroredHorizontally {
            let transform = NSAffineTransform()
            transform.translateX(by: destination.width, yBy: 0)
            transform.scaleX(by: -1, yBy: 1)
            transform.concat()
            frameImage.draw(
                in: destination,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        } else {
            frameImage.draw(
                in: destination,
                from: .zero,
                operation: .sourceOver,
                fraction: 1.0
            )
        }

        image.unlockFocus()
        return image
    }

    private func renderASCIIFrame(frameIndex: Int, blink: Bool) -> NSImage {
        var lines = renderSprite(bones: companion.bones, frame: frameIndex)

        if blink {
            lines = lines.map { $0.replacingOccurrences(of: companion.eye.rawValue, with: "-") }
        }

        if currentState == .talk {
            lines = applyTalkOverlay(lines)
        }

        let imageSize = preferredCanvasSize
        let image = NSImage(size: imageSize)

        image.lockFocus()
        guard let context = NSGraphicsContext.current else {
            image.unlockFocus()
            return image
        }

        context.imageInterpolation = .none

        NSColor.clear.setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: imageSize)).fill()

        let fontSize = max(10, 9 * scale)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: companion.rarity.color,
        ]

        let lineHeight = fontSize + 1
        let totalHeight = CGFloat(lines.count) * lineHeight
        let startY = (imageSize.height - totalHeight) / 2 + currentYOffset

        for (index, line) in lines.enumerated() {
            let attributedLine = NSAttributedString(string: line, attributes: attributes)
            let lineSize = attributedLine.size()
            let lineRect = CGRect(
                x: max(0, (imageSize.width - lineSize.width) / 2),
                y: imageSize.height - startY - CGFloat(index + 1) * lineHeight,
                width: max(lineSize.width, imageSize.width),
                height: lineHeight
            )
            attributedLine.draw(in: lineRect)
        }

        if currentState == .sleep {
            drawOverlayText("zZz", at: CGPoint(x: imageSize.width - 20, y: imageSize.height - 16), color: NSColor.systemBlue)
        }

        if currentState == .evolve || companion.shiny {
            let sparkleColor = companion.shiny ? NSColor.systemYellow : companion.rarity.color
            drawOverlayText("✦", at: CGPoint(x: 10, y: imageSize.height - 18), color: sparkleColor.withAlphaComponent(max(0.4, glowOpacity)))
            drawOverlayText("✦", at: CGPoint(x: imageSize.width - 22, y: imageSize.height - 34), color: sparkleColor.withAlphaComponent(max(0.4, glowOpacity)))
        }

        image.unlockFocus()
        return image
    }

    private func drawOverlayText(_ text: String, at point: CGPoint, color: NSColor) {
        let font = NSFont.systemFont(ofSize: max(11, 10 * scale), weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color,
        ]
        NSAttributedString(string: text, attributes: attributes).draw(at: point)
    }

    private func applyTalkOverlay(_ lines: [String]) -> [String] {
        let phase = tickCount % 3
        guard phase != 0 else { return lines }

        return lines.map { line in
            line
                .replacingOccurrences(of: "ω", with: phase == 1 ? "o" : "O")
                .replacingOccurrences(of: "..", with: phase == 1 ? "oo" : "OO")
                .replacingOccurrences(of: "~~", with: phase == 1 ? "__" : "oo")
        }
    }

    private func loadSpriteSheetIfAvailable() {
        guard artStyle != .ascii else {
            spriteSheetImage = nil
            return
        }

        let resolvedStyle = spriteCatalog.resolvedStyle(preferred: artStyle, species: companion.species)
        if let url = spriteCatalog.spriteURL(for: companion.species, style: resolvedStyle)
            ?? spriteCatalog.spriteURL(for: spriteCatalog.defaultSpecies, style: resolvedStyle),
           let image = NSImage(contentsOf: url) {
            spriteSheetImage = image
            return
        }

        spriteSheetImage = nil
    }
}
