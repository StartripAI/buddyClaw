import Foundation
import XCTest
@testable import DesktopBuddy

final class CompanionIdentityServiceTests: XCTestCase {
    func testLegacyCompanionFileResetsToDefaultProfileAndArchivesOldState() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let storage = StorageManager(baseURL: rootURL)
        storage.saveStoredCompanion(
            StoredCompanion(
                name: "软软",
                personality: "有点胆小但很勇敢",
                hatchedAt: 1_717_171_717
            )
        )

        let service = CompanionIdentityService(storage: storage)
        let resolution = service.loadOrCreateProfile(settings: .default)

        XCTAssertTrue(resolution.didResetIdentity)
        XCTAssertEqual(resolution.profile.identityVersion, StoredCompanionProfile.currentIdentityVersion)
        XCTAssertEqual(resolution.profile.species, .cat)
        XCTAssertEqual(resolution.companion.species, .cat)
        XCTAssertNotEqual(resolution.profile.name, "软软")
        XCTAssertNotNil(resolution.archivedLegacyProfileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: resolution.archivedLegacyProfileURL!.path))

        let persistedProfile = storage.loadCompanionProfile()
        XCTAssertEqual(persistedProfile?.species, .cat)
        XCTAssertEqual(persistedProfile?.identityVersion, StoredCompanionProfile.currentIdentityVersion)
    }

    func testPreviewProfileBuildsMatchingCompanion() {
        let storage = StorageManager(baseURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true))
        let service = CompanionIdentityService(storage: storage)
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let profile = service.previewProfile(for: .penguin, settings: .default, now: now)
        let companion = service.companion(for: profile, settings: .default)

        XCTAssertEqual(profile.species, .penguin)
        XCTAssertEqual(companion.species, .penguin)
        XCTAssertEqual(companion.name, profile.name)
        XCTAssertEqual(companion.personality, profile.personality)
        XCTAssertEqual(companion.hatchedAt, profile.hatchedAt)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
