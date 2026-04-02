import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Direct Swift port of the legacy buddy deterministic generator.
/// 中英双语：直接移植自早期 buddy 原型的确定性生成算法。
public final class CompanionGenerator: Sendable {
    public static let salt = "friend-2026-401"

    private let rarities: [Rarity] = Rarity.allCases
    private let species: [Species] = Species.allCases
    private let eyes: [Eye] = Eye.allCases
    private let hats: [Hat] = Hat.allCases

    public init() {}

    public func roll(userID: String) -> CompanionRoll {
        let key = userID + Self.salt
        return rollFrom(seed: hashString(key))
    }

    public func rollWithSeed(_ seed: String) -> CompanionRoll {
        rollFrom(seed: hashString(seed))
    }

    public func stableUserIdentifier(settings: DesktopBuddySettings) -> String {
        let override = settings.userIdentifierOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !override.isEmpty {
            return override
        }
        #if canImport(AppKit)
        return NSUserName()
        #else
        return "anon"
        #endif
    }

    public func merge(bones: CompanionBones, soul: StoredCompanion) -> Companion {
        Companion(
            rarity: bones.rarity,
            species: bones.species,
            eye: bones.eye,
            hat: bones.hat,
            shiny: bones.shiny,
            stats: bones.stats,
            name: soul.name,
            personality: soul.personality,
            hatchedAt: soul.hatchedAt
        )
    }

    private func rollFrom(seed: UInt32) -> CompanionRoll {
        var rng = Mulberry32(seed: seed)
        let rarity = rollRarity(rng: &rng)

        let bones = CompanionBones(
            rarity: rarity,
            species: pick(rng: &rng, from: species),
            eye: pick(rng: &rng, from: eyes),
            hat: rarity == .common ? .none : pick(rng: &rng, from: hats),
            shiny: rng.next() < 0.01,
            stats: rollStats(rng: &rng, rarity: rarity)
        )

        let inspirationSeed = UInt32((rng.next() * 1_000_000_000.0).rounded(.down))
        return CompanionRoll(bones: bones, inspirationSeed: inspirationSeed)
    }

    private func rollRarity(rng: inout Mulberry32) -> Rarity {
        let totalWeight = rarities.reduce(0) { $0 + $1.weight }
        var roll = rng.next() * Double(totalWeight)
        for rarity in rarities {
            roll -= Double(rarity.weight)
            if roll < 0 {
                return rarity
            }
        }
        return .common
    }

    private func rollStats(rng: inout Mulberry32, rarity: Rarity) -> [StatName: Int] {
        let floor = rarity.floor
        let peak = pick(rng: &rng, from: StatName.allCases)
        var dump = pick(rng: &rng, from: StatName.allCases)
        while dump == peak {
            dump = pick(rng: &rng, from: StatName.allCases)
        }

        var result: [StatName: Int] = [:]
        for name in StatName.allCases {
            if name == peak {
                result[name] = min(100, floor + 50 + Int((rng.next() * 30.0).rounded(.down)))
            } else if name == dump {
                result[name] = max(1, floor - 10 + Int((rng.next() * 15.0).rounded(.down)))
            } else {
                result[name] = floor + Int((rng.next() * 40.0).rounded(.down))
            }
        }
        return result
    }

    private func pick<T>(rng: inout Mulberry32, from array: [T]) -> T {
        array[Int((rng.next() * Double(array.count)).rounded(.down))]
    }

    private func hashString(_ string: String) -> UInt32 {
        var hash: UInt32 = 2_166_136_261
        for codeUnit in string.utf16 {
            hash ^= UInt32(codeUnit)
            hash = hash &* 16_777_619
        }
        return hash
    }
}

public struct Mulberry32: Sendable {
    private var state: UInt32

    public init(seed: UInt32) {
        self.state = seed
    }

    public mutating func next() -> Double {
        state = state &+ 0x6D2B79F5
        var t = (state ^ (state >> 15)) &* (1 | state)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296.0
    }
}
