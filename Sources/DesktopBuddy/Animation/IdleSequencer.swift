import Foundation

public struct IdleFrameResult: Sendable {
    public var frameIndex: Int
    public var shouldBlink: Bool

    public init(frameIndex: Int, shouldBlink: Bool) {
        self.frameIndex = frameIndex
        self.shouldBlink = shouldBlink
    }
}

/// Mirrors the legacy buddy heartbeat-style idle sequence.
/// 中英双语：复刻早期 buddy 原型的 idle 心跳序列。
public final class IdleSequencer: Sendable {
    public static let tickMilliseconds: Int = 500
    public static let sequence: [Int] = [0, 0, 0, 0, 1, 0, 0, 0, -1, 0, 0, 2, 0, 0, 0]

    public init() {}

    public func frame(forTick tick: Int, frameCount: Int) -> IdleFrameResult {
        guard frameCount > 0 else { return IdleFrameResult(frameIndex: 0, shouldBlink: false) }
        let value = Self.sequence[tick % Self.sequence.count]
        if value == -1 {
            return IdleFrameResult(frameIndex: 0, shouldBlink: true)
        }
        return IdleFrameResult(frameIndex: value % frameCount, shouldBlink: false)
    }
}
