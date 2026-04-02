import Foundation

public enum EvolutionStage: String, CaseIterable, Codable, Sendable {
    case hatchling
    case curious
    case trusted
    case radiant
    case transcendent

    public var displayNameCN: String {
        switch self {
        case .hatchling: return "幼芽"
        case .curious: return "好奇"
        case .trusted: return "同行"
        case .radiant: return "闪耀"
        case .transcendent: return "传说形态"
        }
    }

    public var localizedName: String {
        switch self {
        case .hatchling: return L10n.text("幼芽", "Hatchling")
        case .curious: return L10n.text("好奇", "Curious")
        case .trusted: return L10n.text("同行", "Trusted")
        case .radiant: return L10n.text("闪耀", "Radiant")
        case .transcendent: return L10n.text("传说形态", "Legendary Form")
        }
    }

    public var minimumXP: Int {
        switch self {
        case .hatchling: return 0
        case .curious: return 80
        case .trusted: return 240
        case .radiant: return 560
        case .transcendent: return 1080
        }
    }

    public var unlockedAnimations: [AnimationState] {
        switch self {
        case .hatchling:
            return [.idle, .blink, .talk, .walkLeft, .walkRight]
        case .curious:
            return [.idle, .blink, .talk, .sit, .pet, .walkLeft, .walkRight]
        case .trusted:
            return [.idle, .blink, .talk, .sit, .pet, .walkLeft, .walkRight, .jump]
        case .radiant:
            return [.idle, .blink, .talk, .sit, .pet, .walkLeft, .walkRight, .jump, .sleep]
        case .transcendent:
            return AnimationState.allCases
        }
    }

    public static func stage(for xp: Int) -> EvolutionStage {
        EvolutionStage.allCases.last(where: { xp >= $0.minimumXP }) ?? .hatchling
    }
}

public struct GrowthState: Codable, Sendable {
    public var xp: Int
    public var activeMinutes: Int
    public var conversationCount: Int
    public var petCount: Int
    public var stage: EvolutionStage
    public var lastDailyGreetingKey: String?

    public init(
        xp: Int = 0,
        activeMinutes: Int = 0,
        conversationCount: Int = 0,
        petCount: Int = 0,
        stage: EvolutionStage = .hatchling,
        lastDailyGreetingKey: String? = nil
    ) {
        self.xp = xp
        self.activeMinutes = activeMinutes
        self.conversationCount = conversationCount
        self.petCount = petCount
        self.stage = stage
        self.lastDailyGreetingKey = lastDailyGreetingKey
    }
}
