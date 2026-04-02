import Foundation

public struct CompanionIdentityResolution: Sendable {
    public let profile: StoredCompanionProfile
    public let companion: Companion
    public let didResetIdentity: Bool
    public let archivedLegacyProfileURL: URL?

    public init(
        profile: StoredCompanionProfile,
        companion: Companion,
        didResetIdentity: Bool,
        archivedLegacyProfileURL: URL?
    ) {
        self.profile = profile
        self.companion = companion
        self.didResetIdentity = didResetIdentity
        self.archivedLegacyProfileURL = archivedLegacyProfileURL
    }
}

public final class CompanionIdentityService {
    private let storage: StorageManager
    private let generator: CompanionGenerator
    private let nameTable: NameTable
    private let spriteCatalog: VerifiedSpriteCatalog

    public init(
        storage: StorageManager,
        generator: CompanionGenerator = CompanionGenerator(),
        nameTable: NameTable = .shared,
        spriteCatalog: VerifiedSpriteCatalog = VerifiedSpriteCatalog()
    ) {
        self.storage = storage
        self.generator = generator
        self.nameTable = nameTable
        self.spriteCatalog = spriteCatalog
    }

    public var availableSpecies: [Species] {
        spriteCatalog.availableSpecies
    }

    public var defaultSpecies: Species {
        spriteCatalog.defaultSpecies
    }

    public func loadOrCreateProfile(settings: DesktopBuddySettings) -> CompanionIdentityResolution {
        if let profile = validatedProfile(from: storage.loadCompanionProfile()) {
            return CompanionIdentityResolution(
                profile: profile,
                companion: companion(for: profile, settings: settings),
                didResetIdentity: false,
                archivedLegacyProfileURL: nil
            )
        }

        let archivedURL: URL?
        if storage.companionFileExists() {
            archivedURL = storage.archiveExistingCompanionFile(reason: "identity-reset-v2")
        } else {
            archivedURL = nil
        }

        let profile = resetProfile(settings: settings)
        storage.saveCompanionProfile(profile)
        return CompanionIdentityResolution(
            profile: profile,
            companion: companion(for: profile, settings: settings),
            didResetIdentity: true,
            archivedLegacyProfileURL: archivedURL
        )
    }

    public func previewProfile(for species: Species, settings: DesktopBuddySettings, now: Date = .now) -> StoredCompanionProfile {
        let resolvedSpecies = spriteCatalog.isVerified(species) ? species : defaultSpecies
        let seed = profileSeed(
            userIdentifier: generator.stableUserIdentifier(settings: settings),
            species: resolvedSpecies,
            hatchedAt: now.timeIntervalSince1970
        )
        let roll = generator.rollWithSeed(seed)
        return StoredCompanionProfile(
            species: resolvedSpecies,
            name: nameTable.pickName(species: resolvedSpecies, seed: roll.inspirationSeed),
            personality: nameTable.pickPersonality(seed: roll.inspirationSeed),
            hatchedAt: now.timeIntervalSince1970,
            identityVersion: StoredCompanionProfile.currentIdentityVersion
        )
    }

    public func resetProfile(settings: DesktopBuddySettings, now: Date = .now) -> StoredCompanionProfile {
        previewProfile(for: defaultSpecies, settings: settings, now: now)
    }

    public func companion(for profile: StoredCompanionProfile, settings: DesktopBuddySettings) -> Companion {
        let resolvedSpecies = spriteCatalog.isVerified(profile.species) ? profile.species : defaultSpecies
        let seed = profileSeed(
            userIdentifier: generator.stableUserIdentifier(settings: settings),
            species: resolvedSpecies,
            hatchedAt: profile.hatchedAt
        )
        var roll = generator.rollWithSeed(seed)
        roll.bones.species = resolvedSpecies

        return Companion(
            rarity: roll.bones.rarity,
            species: resolvedSpecies,
            eye: roll.bones.eye,
            hat: roll.bones.hat,
            shiny: roll.bones.shiny,
            stats: roll.bones.stats,
            name: profile.name,
            personality: profile.personality,
            hatchedAt: profile.hatchedAt
        )
    }

    public func persist(_ profile: StoredCompanionProfile) {
        storage.saveCompanionProfile(profile)
    }

    private func validatedProfile(from profile: StoredCompanionProfile?) -> StoredCompanionProfile? {
        guard let profile,
              profile.isCurrentVersion,
              spriteCatalog.isVerified(profile.species),
              profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              profile.personality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }
        return profile
    }

    private func profileSeed(userIdentifier: String, species: Species, hatchedAt: TimeInterval) -> String {
        let timestamp = Int((hatchedAt * 1_000).rounded())
        return "\(userIdentifier)::\(species.rawValue)::\(timestamp)"
    }
}
