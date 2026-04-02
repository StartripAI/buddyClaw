import Foundation
#if canImport(AppKit)
import AppKit
#endif

// MARK: - Canonical companion enums / 核心枚举

public enum ArtStyle: String, CaseIterable, Codable, Sendable {
    case ascii = "ASCII"
    case pixel = "Pixel"
    case claw = "Claw"
    
    public var displayName: String {
        switch self {
        case .ascii: return L10n.text("ASCII 字符", "ASCII")
        case .pixel: return L10n.text("像素", "Pixel")
        case .claw: return "Claw"
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue.lowercased() {
        case "ascii":
            self = .ascii
        case "pixel":
            self = .pixel
        case "claw", "claude":
            self = .claw
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown art style: \(rawValue)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum Rarity: String, CaseIterable, Codable, Sendable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    public var weight: Int {
        switch self {
        case .common: return 60
        case .uncommon: return 25
        case .rare: return 10
        case .epic: return 4
        case .legendary: return 1
        }
    }

    public var floor: Int {
        switch self {
        case .common: return 5
        case .uncommon: return 15
        case .rare: return 25
        case .epic: return 35
        case .legendary: return 50
        }
    }

    public var stars: String {
        switch self {
        case .common: return "★"
        case .uncommon: return "★★"
        case .rare: return "★★★"
        case .epic: return "★★★★"
        case .legendary: return "★★★★★"
        }
    }

    public var displayNameCN: String {
        switch self {
        case .common: return "普通"
        case .uncommon: return "少见"
        case .rare: return "稀有"
        case .epic: return "史诗"
        case .legendary: return "传说"
        }
    }

    public var localizedName: String {
        switch self {
        case .common: return L10n.text("普通", "Common")
        case .uncommon: return L10n.text("少见", "Uncommon")
        case .rare: return L10n.text("稀有", "Rare")
        case .epic: return L10n.text("史诗", "Epic")
        case .legendary: return L10n.text("传说", "Legendary")
        }
    }

    #if canImport(AppKit)
    public var color: NSColor {
        switch self {
        case .common: return NSColor(calibratedRed: 0.71, green: 0.75, blue: 0.80, alpha: 1.0)
        case .uncommon: return NSColor(calibratedRed: 0.29, green: 0.76, blue: 0.42, alpha: 1.0)
        case .rare: return NSColor(calibratedRed: 0.29, green: 0.58, blue: 0.98, alpha: 1.0)
        case .epic: return NSColor(calibratedRed: 0.62, green: 0.35, blue: 0.93, alpha: 1.0)
        case .legendary: return NSColor(calibratedRed: 0.96, green: 0.74, blue: 0.21, alpha: 1.0)
        }
    }
    #endif
}

public enum Species: String, CaseIterable, Codable, Sendable {
    case duck
    case goose
    case blob
    case cat
    case dragon
    case octopus
    case owl
    case penguin
    case turtle
    case snail
    case ghost
    case axolotl
    case capybara
    case cactus
    case robot
    case rabbit
    case mushroom
    case chonk

    public var displayNameCN: String {
        switch self {
        case .duck: return "鸭鸭"
        case .goose: return "大鹅"
        case .blob: return "史莱姆"
        case .cat: return "猫猫"
        case .dragon: return "小龙"
        case .octopus: return "章鱼"
        case .owl: return "猫头鹰"
        case .penguin: return "企鹅"
        case .turtle: return "乌龟"
        case .snail: return "蜗牛"
        case .ghost: return "幽灵"
        case .axolotl: return "六角恐龙"
        case .capybara: return "卡皮巴拉"
        case .cactus: return "仙人掌"
        case .robot: return "机器人"
        case .rabbit: return "兔兔"
        case .mushroom: return "蘑菇"
        case .chonk: return "团子兽"
        }
    }

    public var localizedName: String {
        switch self {
        case .duck: return L10n.text("鸭鸭", "Duck")
        case .goose: return L10n.text("大鹅", "Goose")
        case .blob: return L10n.text("史莱姆", "Blob")
        case .cat: return L10n.text("猫猫", "Cat")
        case .dragon: return L10n.text("小龙", "Dragon")
        case .octopus: return L10n.text("章鱼", "Octopus")
        case .owl: return L10n.text("猫头鹰", "Owl")
        case .penguin: return L10n.text("企鹅", "Penguin")
        case .turtle: return L10n.text("乌龟", "Turtle")
        case .snail: return L10n.text("蜗牛", "Snail")
        case .ghost: return L10n.text("幽灵", "Ghost")
        case .axolotl: return L10n.text("六角恐龙", "Axolotl")
        case .capybara: return L10n.text("卡皮巴拉", "Capybara")
        case .cactus: return L10n.text("仙人掌", "Cactus")
        case .robot: return L10n.text("机器人", "Robot")
        case .rabbit: return L10n.text("兔兔", "Rabbit")
        case .mushroom: return L10n.text("蘑菇", "Mushroom")
        case .chonk: return L10n.text("团子兽", "Chonk")
        }
    }

    public var emoji: String {
        switch self {
        case .duck: return "🦆"
        case .goose: return "🪿"
        case .blob: return "🫧"
        case .cat: return "🐱"
        case .dragon: return "🐉"
        case .octopus: return "🐙"
        case .owl: return "🦉"
        case .penguin: return "🐧"
        case .turtle: return "🐢"
        case .snail: return "🐌"
        case .ghost: return "👻"
        case .axolotl: return "🦎"
        case .capybara: return "🦫"
        case .cactus: return "🌵"
        case .robot: return "🤖"
        case .rabbit: return "🐰"
        case .mushroom: return "🍄"
        case .chonk: return "🐾"
        }
    }
}

public enum Eye: String, CaseIterable, Codable, Sendable {
    case dot = "·"
    case spark = "✦"
    case cross = "×"
    case big = "◉"
    case at = "@"
    case circle = "°"
}

public enum Hat: String, CaseIterable, Codable, Sendable {
    case none
    case crown
    case tophat
    case propeller
    case halo
    case wizard
    case beanie
    case tinyduck

    public var displayNameCN: String {
        switch self {
        case .none: return "无"
        case .crown: return "皇冠"
        case .tophat: return "礼帽"
        case .propeller: return "竹蜻蜓"
        case .halo: return "光环"
        case .wizard: return "巫师帽"
        case .beanie: return "毛线帽"
        case .tinyduck: return "小鸭帽"
        }
    }

    public var localizedName: String {
        switch self {
        case .none: return L10n.text("无", "None")
        case .crown: return L10n.text("皇冠", "Crown")
        case .tophat: return L10n.text("礼帽", "Top Hat")
        case .propeller: return L10n.text("竹蜻蜓", "Propeller")
        case .halo: return L10n.text("光环", "Halo")
        case .wizard: return L10n.text("巫师帽", "Wizard Hat")
        case .beanie: return L10n.text("毛线帽", "Beanie")
        case .tinyduck: return L10n.text("小鸭帽", "Tiny Duck")
        }
    }
}

public enum StatName: String, CaseIterable, Codable, Sendable {
    case debugging = "DEBUGGING"
    case patience = "PATIENCE"
    case chaos = "CHAOS"
    case wisdom = "WISDOM"
    case snark = "SNARK"

    public var displayNameCN: String {
        switch self {
        case .debugging: return "调试"
        case .patience: return "耐心"
        case .chaos: return "混沌"
        case .wisdom: return "智慧"
        case .snark: return "毒舌"
        }
    }

    public var localizedName: String {
        switch self {
        case .debugging: return L10n.text("调试", "Debugging")
        case .patience: return L10n.text("耐心", "Patience")
        case .chaos: return L10n.text("混沌", "Chaos")
        case .wisdom: return L10n.text("智慧", "Wisdom")
        case .snark: return L10n.text("毒舌", "Snark")
        }
    }
}

public enum BubbleStyle: String, Codable, Sendable {
    case speech
    case system
    case reaction
    case thought
}

public enum ThemeMode: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    public var displayName: String {
        switch self {
        case .system: return L10n.text("跟随系统", "Follow System")
        case .light: return L10n.text("浅色", "Light")
        case .dark: return L10n.text("深色", "Dark")
        }
    }
}

public enum AskScope: String, CaseIterable, Codable, Sendable {
    case knowledgeOnly
    case memoryOnly
    case all

    public var displayName: String {
        switch self {
        case .knowledgeOnly: return L10n.text("资料库优先", "Library First")
        case .memoryOnly: return L10n.text("时间线优先", "Timeline First")
        case .all: return L10n.text("全部", "All")
        }
    }
}

// MARK: - Companion domain models / 宠物领域模型

public struct CompanionBones: Codable, Sendable {
    public var rarity: Rarity
    public var species: Species
    public var eye: Eye
    public var hat: Hat
    public var shiny: Bool
    public var stats: [StatName: Int]

    public init(
        rarity: Rarity,
        species: Species,
        eye: Eye,
        hat: Hat,
        shiny: Bool,
        stats: [StatName: Int]
    ) {
        self.rarity = rarity
        self.species = species
        self.eye = eye
        self.hat = hat
        self.shiny = shiny
        self.stats = stats
    }

    public var strongestStat: StatName {
        stats.max(by: { $0.value < $1.value })?.key ?? .wisdom
    }

    public var weakestStat: StatName {
        stats.min(by: { $0.value < $1.value })?.key ?? .chaos
    }
}

public struct CompanionSoul: Codable, Sendable {
    public var name: String
    public var personality: String

    public init(name: String, personality: String) {
        self.name = name
        self.personality = personality
    }
}

public struct StoredCompanion: Codable, Sendable {
    public var name: String
    public var personality: String
    public var hatchedAt: TimeInterval

    public init(name: String, personality: String, hatchedAt: TimeInterval) {
        self.name = name
        self.personality = personality
        self.hatchedAt = hatchedAt
    }

    public var soul: CompanionSoul {
        CompanionSoul(name: name, personality: personality)
    }
}

public struct StoredCompanionProfile: Codable, Sendable {
    public static let currentIdentityVersion = 2

    public var species: Species
    public var name: String
    public var personality: String
    public var hatchedAt: TimeInterval
    public var identityVersion: Int

    public init(
        species: Species,
        name: String,
        personality: String,
        hatchedAt: TimeInterval,
        identityVersion: Int = Self.currentIdentityVersion
    ) {
        self.species = species
        self.name = name
        self.personality = personality
        self.hatchedAt = hatchedAt
        self.identityVersion = identityVersion
    }

    public var soul: CompanionSoul {
        CompanionSoul(name: name, personality: personality)
    }

    public var isCurrentVersion: Bool {
        identityVersion == Self.currentIdentityVersion
    }
}

public struct Companion: Codable, Sendable {
    public var rarity: Rarity
    public var species: Species
    public var eye: Eye
    public var hat: Hat
    public var shiny: Bool
    public var stats: [StatName: Int]
    public var name: String
    public var personality: String
    public var hatchedAt: TimeInterval

    public init(
        rarity: Rarity,
        species: Species,
        eye: Eye,
        hat: Hat,
        shiny: Bool,
        stats: [StatName: Int],
        name: String,
        personality: String,
        hatchedAt: TimeInterval
    ) {
        self.rarity = rarity
        self.species = species
        self.eye = eye
        self.hat = hat
        self.shiny = shiny
        self.stats = stats
        self.name = name
        self.personality = personality
        self.hatchedAt = hatchedAt
    }

    public var bones: CompanionBones {
        CompanionBones(
            rarity: rarity,
            species: species,
            eye: eye,
            hat: hat,
            shiny: shiny,
            stats: stats
        )
    }

    public var soul: CompanionSoul {
        CompanionSoul(name: name, personality: personality)
    }
}

public struct CompanionRoll: Sendable {
    public var bones: CompanionBones
    public var inspirationSeed: UInt32

    public init(bones: CompanionBones, inspirationSeed: UInt32) {
        self.bones = bones
        self.inspirationSeed = inspirationSeed
    }
}

public struct BubblePayload: Identifiable, Sendable {
    public var id: UUID
    public var text: String
    public var style: BubbleStyle
    public var createdAt: Date
    public var duration: TimeInterval
    public var isStreaming: Bool

    public init(
        id: UUID = UUID(),
        text: String,
        style: BubbleStyle,
        createdAt: Date = .now,
        duration: TimeInterval,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.text = text
        self.style = style
        self.createdAt = createdAt
        self.duration = duration
        self.isStreaming = isStreaming
    }
}

public enum ConversationRole: String, Codable, Sendable {
    case user
    case assistant
}

public struct ConversationTurn: Identifiable, Codable, Sendable {
    public var id: UUID
    public var role: ConversationRole
    public var text: String
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        role: ConversationRole,
        text: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
    }
}

public struct WorkSnapshot: Codable, Sendable {
    public var capturedAt: Date
    public var frontmostAppName: String?
    public var frontmostBundleIdentifier: String?
    public var idleSeconds: TimeInterval
    public var activeSessionSeconds: TimeInterval
    public var continuousCodingSeconds: TimeInterval
    public var keyPressesLastMinute: Int
    public var appSwitchesLastTenMinutes: Int
    public var recentBuildFailure: Bool

    public init(
        capturedAt: Date = .now,
        frontmostAppName: String? = nil,
        frontmostBundleIdentifier: String? = nil,
        idleSeconds: TimeInterval = 0,
        activeSessionSeconds: TimeInterval = 0,
        continuousCodingSeconds: TimeInterval = 0,
        keyPressesLastMinute: Int = 0,
        appSwitchesLastTenMinutes: Int = 0,
        recentBuildFailure: Bool = false
    ) {
        self.capturedAt = capturedAt
        self.frontmostAppName = frontmostAppName
        self.frontmostBundleIdentifier = frontmostBundleIdentifier
        self.idleSeconds = idleSeconds
        self.activeSessionSeconds = activeSessionSeconds
        self.continuousCodingSeconds = continuousCodingSeconds
        self.keyPressesLastMinute = keyPressesLastMinute
        self.appSwitchesLastTenMinutes = appSwitchesLastTenMinutes
        self.recentBuildFailure = recentBuildFailure
    }

    public var isCodingApp: Bool {
        guard let bundleIdentifier = frontmostBundleIdentifier?.lowercased() else { return false }
        return bundleIdentifier.contains("xcode")
            || bundleIdentifier.contains("code")
            || bundleIdentifier.contains("zed")
            || bundleIdentifier.contains("jetbrains")
            || bundleIdentifier.contains("sublime")
            || bundleIdentifier.contains("vim")
            || bundleIdentifier.contains("terminal")
            || bundleIdentifier.contains("iterm")
    }
}

// MARK: - App settings / 应用设置

public struct DesktopBuddySettings: Codable, Sendable {
    public var model: String
    public var isMuted: Bool
    public var preferredArtStyle: ArtStyle
    public var proactiveCommentsEnabled: Bool
    public var themeMode: ThemeMode
    public var speechBubbleSeconds: Double
    public var petScalePercent: Double
    public var maxResponseTokens: Int
    public var userIdentifierOverride: String?
    public var movementEnabled: Bool
    public var openSettingsOnLaunch: Bool
    public var memoryCaptureEnabled: Bool
    public var rawEventRetentionDays: Int
    public var starterPackEnabled: Bool
    public var defaultAskScope: AskScope

    public init(
        model: String = "local-extractive-v1",
        isMuted: Bool = false,
        preferredArtStyle: ArtStyle = .pixel,
        proactiveCommentsEnabled: Bool = true,
        themeMode: ThemeMode = .system,
        speechBubbleSeconds: Double = 10,
        petScalePercent: Double = 50,
        maxResponseTokens: Int = 220,
        userIdentifierOverride: String? = nil,
        movementEnabled: Bool = true,
        openSettingsOnLaunch: Bool = false,
        memoryCaptureEnabled: Bool = true,
        rawEventRetentionDays: Int = 90,
        starterPackEnabled: Bool = true,
        defaultAskScope: AskScope = .all
    ) {
        self.model = model
        self.isMuted = isMuted
        self.preferredArtStyle = preferredArtStyle
        self.proactiveCommentsEnabled = proactiveCommentsEnabled
        self.themeMode = themeMode
        self.speechBubbleSeconds = speechBubbleSeconds
        self.petScalePercent = petScalePercent
        self.maxResponseTokens = maxResponseTokens
        self.userIdentifierOverride = userIdentifierOverride
        self.movementEnabled = movementEnabled
        self.openSettingsOnLaunch = openSettingsOnLaunch
        self.memoryCaptureEnabled = memoryCaptureEnabled
        self.rawEventRetentionDays = rawEventRetentionDays
        self.starterPackEnabled = starterPackEnabled
        self.defaultAskScope = defaultAskScope
    }

    private enum CodingKeys: String, CodingKey {
        case model
        case isMuted
        case preferredArtStyle
        case artStyle
        case proactiveCommentsEnabled
        case themeMode
        case speechBubbleSeconds
        case petScalePercent
        case petScale
        case maxResponseTokens
        case userIdentifierOverride
        case movementEnabled
        case openSettingsOnLaunch
        case memoryCaptureEnabled
        case rawEventRetentionDays
        case starterPackEnabled
        case defaultAskScope
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.model = try container.decodeIfPresent(String.self, forKey: .model) ?? "local-extractive-v1"
        self.isMuted = try container.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        let preferredStyle = try container.decodeIfPresent(ArtStyle.self, forKey: .preferredArtStyle)
        let legacyStyle = try container.decodeIfPresent(ArtStyle.self, forKey: .artStyle)
        self.preferredArtStyle = preferredStyle ?? legacyStyle ?? .pixel
        self.proactiveCommentsEnabled = try container.decodeIfPresent(Bool.self, forKey: .proactiveCommentsEnabled) ?? true
        self.themeMode = try container.decodeIfPresent(ThemeMode.self, forKey: .themeMode) ?? .system
        self.speechBubbleSeconds = try container.decodeIfPresent(Double.self, forKey: .speechBubbleSeconds) ?? 10
        if let percent = try container.decodeIfPresent(Double.self, forKey: .petScalePercent) {
            self.petScalePercent = percent
        } else if let oldScale = try container.decodeIfPresent(Double.self, forKey: .petScale) {
            self.petScalePercent = oldScale * 25
        } else {
            self.petScalePercent = 50
        }
        self.maxResponseTokens = try container.decodeIfPresent(Int.self, forKey: .maxResponseTokens) ?? 220
        self.userIdentifierOverride = try container.decodeIfPresent(String.self, forKey: .userIdentifierOverride)
        self.movementEnabled = try container.decodeIfPresent(Bool.self, forKey: .movementEnabled) ?? true
        self.openSettingsOnLaunch = try container.decodeIfPresent(Bool.self, forKey: .openSettingsOnLaunch) ?? false
        self.memoryCaptureEnabled = try container.decodeIfPresent(Bool.self, forKey: .memoryCaptureEnabled) ?? true
        self.rawEventRetentionDays = try container.decodeIfPresent(Int.self, forKey: .rawEventRetentionDays) ?? 90
        self.starterPackEnabled = try container.decodeIfPresent(Bool.self, forKey: .starterPackEnabled) ?? true
        self.defaultAskScope = try container.decodeIfPresent(AskScope.self, forKey: .defaultAskScope) ?? .all
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(model, forKey: .model)
        try container.encode(isMuted, forKey: .isMuted)
        try container.encode(preferredArtStyle, forKey: .preferredArtStyle)
        try container.encode(proactiveCommentsEnabled, forKey: .proactiveCommentsEnabled)
        try container.encode(themeMode, forKey: .themeMode)
        try container.encode(speechBubbleSeconds, forKey: .speechBubbleSeconds)
        try container.encode(petScalePercent, forKey: .petScalePercent)
        try container.encode(maxResponseTokens, forKey: .maxResponseTokens)
        try container.encodeIfPresent(userIdentifierOverride, forKey: .userIdentifierOverride)
        try container.encode(movementEnabled, forKey: .movementEnabled)
        try container.encode(openSettingsOnLaunch, forKey: .openSettingsOnLaunch)
        try container.encode(memoryCaptureEnabled, forKey: .memoryCaptureEnabled)
        try container.encode(rawEventRetentionDays, forKey: .rawEventRetentionDays)
        try container.encode(starterPackEnabled, forKey: .starterPackEnabled)
        try container.encode(defaultAskScope, forKey: .defaultAskScope)
    }
}

public extension DesktopBuddySettings {
    var petScale: Double {
        get { max(0.5, petScalePercent / 25.0) }
        set { petScalePercent = max(25, newValue * 25.0) }
    }
}

public extension DesktopBuddySettings {
    static let `default` = DesktopBuddySettings()
}
