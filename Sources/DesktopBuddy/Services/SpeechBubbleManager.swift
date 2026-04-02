import Foundation
import Combine

@MainActor
public final class SpeechBubbleManager: ObservableObject {
    @Published public private(set) var currentBubble: BubblePayload?
    @Published public private(set) var fadeProgress: Double = 0

    private let bubbleShowTicks = 20
    private let fadeWindowTicks = 6
    private var queue: [BubblePayload] = []
    private var fadeTimer: Timer?
    private var autoHideTimer: Timer?
    private var defaultDuration: TimeInterval = 10

    public init() {}

    public func setDefaultDisplayDuration(_ seconds: TimeInterval) {
        defaultDuration = max(3, seconds)
    }

    public func show(
        text: String,
        style: BubbleStyle = .speech,
        duration: TimeInterval? = nil
    ) {
        let payload = BubblePayload(
            text: text,
            style: style,
            duration: duration ?? defaultDuration
        )
        queue.append(payload)
        displayNextIfNeeded()
    }

    public func beginStreaming(style: BubbleStyle = .speech) {
        let payload = BubblePayload(
            text: "",
            style: style,
            duration: defaultDuration,
            isStreaming: true
        )
        queue.removeAll()
        currentBubble = payload
        fadeProgress = 0
        invalidateTimers()
    }

    public func appendStreamingText(_ text: String) {
        guard var currentBubble else { return }
        currentBubble.text.append(text)
        self.currentBubble = currentBubble
    }

    public func finishStreaming(minimumDuration: TimeInterval = 5) {
        guard var currentBubble else { return }
        currentBubble.isStreaming = false
        currentBubble.duration = max(minimumDuration, defaultDuration * 0.8)
        currentBubble.createdAt = .now
        self.currentBubble = currentBubble
        scheduleTimers(for: currentBubble)
    }

    public func hideImmediately() {
        queue.removeAll()
        currentBubble = nil
        fadeProgress = 0
        invalidateTimers()
    }

    private func displayNextIfNeeded() {
        guard currentBubble == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        currentBubble = next
        fadeProgress = 0
        scheduleTimers(for: next)
    }

    private func scheduleTimers(for payload: BubblePayload) {
        invalidateTimers()

        let totalDuration = max(payload.duration, TimeInterval(bubbleShowTicks) * 0.5)
        let fadeDuration = max(1.0, min(totalDuration * 0.35, TimeInterval(fadeWindowTicks) * 0.5))
        let fadeStart = max(0.25, totalDuration - fadeDuration)

        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }

                guard let bubble = self.currentBubble else {
                    timer.invalidate()
                    return
                }

                let elapsed = Date().timeIntervalSince(bubble.createdAt)
                if elapsed < fadeStart {
                    self.fadeProgress = 0
                    return
                }

                let progress = min(1.0, (elapsed - fadeStart) / fadeDuration)
                self.fadeProgress = progress
                if progress >= 1.0, bubble.isStreaming == false {
                    timer.invalidate()
                }
            }
        }

        autoHideTimer = Timer.scheduledTimer(withTimeInterval: totalDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentBubble = nil
                self.fadeProgress = 0
                self.displayNextIfNeeded()
            }
        }
    }

    private func invalidateTimers() {
        fadeTimer?.invalidate()
        autoHideTimer?.invalidate()
        fadeTimer = nil
        autoHideTimer = nil
    }
}
