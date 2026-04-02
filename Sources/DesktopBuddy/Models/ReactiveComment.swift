import Foundation

public struct ReactiveCommentDecision: Sendable {
    public var key: String
    public var text: String
    public var style: BubbleStyle
    public var suggestedState: AnimationState?

    public init(
        key: String,
        text: String,
        style: BubbleStyle = .system,
        suggestedState: AnimationState? = nil
    ) {
        self.key = key
        self.text = text
        self.style = style
        self.suggestedState = suggestedState
    }
}

@MainActor
public final class ReactiveCommentEngine {
    private var lastFireDates: [String: Date] = [:]
    private let calendar = Calendar.current

    public init() {}

    public func evaluate(
        snapshot: WorkSnapshot,
        companion: Companion,
        growthState: GrowthState,
        proactiveCommentsEnabled: Bool
    ) -> ReactiveCommentDecision? {
        guard proactiveCommentsEnabled else { return nil }

        if snapshot.recentBuildFailure, canFire("buildFailure", cooldown: 20 * 60) {
            return ReactiveCommentDecision(
                key: "buildFailure",
                text: buildFailureLine(for: companion),
                style: .system,
                suggestedState: .talk
            )
        }

        if snapshot.isCodingApp,
           snapshot.continuousCodingSeconds >= 2 * 60 * 60,
           snapshot.idleSeconds < 120,
           canFire("longCoding", cooldown: 45 * 60) {
            return ReactiveCommentDecision(
                key: "longCoding",
                text: longCodingLine(for: companion),
                style: .system,
                suggestedState: .talk
            )
        }

        if snapshot.appSwitchesLastTenMinutes >= 18,
           snapshot.idleSeconds < 180,
           canFire("focus", cooldown: 35 * 60) {
            return ReactiveCommentDecision(
                key: "focus",
                text: focusLine(for: companion),
                style: .thought,
                suggestedState: .talk
            )
        }

        if snapshot.idleSeconds >= 15 * 60,
           canFire("idle", cooldown: 60 * 60) {
            return ReactiveCommentDecision(
                key: "idle",
                text: idleLine(for: companion),
                style: .thought,
                suggestedState: .sit
            )
        }

        if shouldSendMorningGreeting(growthState: growthState, snapshot: snapshot),
           canFire("morningGreeting", cooldown: 8 * 60 * 60) {
            return ReactiveCommentDecision(
                key: "morningGreeting",
                text: L10n.text(
                    "早呀，我已经在桌边待命了。今天我们先拿下一件最重要的小事。",
                    "Morning. I'm already at your desk. Let's win one important small task first."
                ),
                style: .speech,
                suggestedState: .talk
            )
        }

        return nil
    }

    public func markFired(key: String, at date: Date = .now) {
        lastFireDates[key] = date
    }

    private func canFire(_ key: String, cooldown: TimeInterval) -> Bool {
        guard let lastDate = lastFireDates[key] else { return true }
        return Date().timeIntervalSince(lastDate) >= cooldown
    }

    private func shouldSendMorningGreeting(growthState: GrowthState, snapshot: WorkSnapshot) -> Bool {
        let components = calendar.dateComponents([.hour], from: snapshot.capturedAt)
        let hour = components.hour ?? 0
        return hour >= 6 && hour <= 11 && snapshot.activeSessionSeconds < 180 && growthState.lastDailyGreetingKey != dayKey(for: snapshot.capturedAt)
    }

    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private func buildFailureLine(for companion: Companion) -> String {
        switch companion.bones.strongestStat {
        case .debugging:
            return L10n.text(
                "刚刚那次报错记在我这里了。我们先修第一个红点，别跟整片日志硬碰硬。",
                "I logged that error. Let's fix the first real red flag instead of fighting the whole log."
            )
        case .patience:
            return L10n.text(
                "没关系，这种红字值得慢一点。先回到第一个真正的报错。",
                "It's okay. This kind of red text deserves patience. Go back to the first real error."
            )
        case .chaos:
            return L10n.text(
                "它炸了一下，但还没赢。喝口水，我们把现场一块块收回来。",
                "It exploded a bit, but it still hasn't won. Take a sip of water and let's recover it piece by piece."
            )
        case .wisdom:
            return L10n.text(
                "先别全盘怀疑自己，编译失败通常只是在提醒依赖链哪里松了。",
                "Don't doubt everything yet. A build failure usually just points at a loose dependency in the chain."
            )
        case .snark:
            return L10n.text(
                "嗯，编译器今天又开始演了。先抓第一条有效错误，它就没那么神气了。",
                "Yep, the compiler is being dramatic again. Catch the first useful error and it gets a lot less smug."
            )
        }
    }

    private func longCodingLine(for companion: Companion) -> String {
        switch companion.species {
        case .snail, .turtle, .capybara:
            return L10n.text(
                "你已经连续敲很久啦。跟我学一下——慢慢伸个懒腰，再回来会更稳。",
                "You've been typing for a long while. Copy me: take a slow stretch and you'll come back steadier."
            )
        case .dragon, .robot:
            return L10n.text(
                "两小时连击达成。勇者先起身 60 秒，下一轮输出会更高。",
                "Two-hour combo achieved. Stand up for 60 seconds and your next round will hit harder."
            )
        default:
            return L10n.text(
                "你已经连续工作两小时了。站起来、眨眨眼、喝口水，我替你看桌面。",
                "You've been working for two straight hours. Stand up, blink, sip some water, and I'll watch the desk for you."
            )
        }
    }

    private func focusLine(for companion: Companion) -> String {
        L10n.text(
            "窗口切换有点像打鼓了。先只选一件事做完，我在旁边给你守住节奏。",
            "The window switching is starting to sound like drums. Pick one thing to finish and I'll guard the rhythm."
        )
    }

    private func idleLine(for companion: Companion) -> String {
        L10n.text(
            "我先替你占着这块桌面。回来戳我一下，我们继续。",
            "I'll hold this spot on the desk for you. Tap me when you're back and we'll continue."
        )
    }
}
