import Foundation

// MARK: - 本地存储管理 / Local Storage Manager
// 纯 JSON 文件持久化，不需要 Keychain 和网络。

public final class StorageManager {
    private let fileManager: FileManager
    private let baseURL: URL

    private let settingsFileName = "settings.json"
    private let companionFileName = "companion.json"
    private let growthFileName = "growth.json"

    public init(fileManager: FileManager = .default, baseURL: URL? = nil) {
        self.fileManager = fileManager
        let supportURL = baseURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.baseURL = supportURL.appendingPathComponent("DesktopBuddy", isDirectory: true)
        ensureDirectories()
    }

    public func loadSettings() -> DesktopBuddySettings {
        loadJSON(DesktopBuddySettings.self, fileName: settingsFileName) ?? .default
    }

    public func saveSettings(_ settings: DesktopBuddySettings) {
        saveJSON(settings, fileName: settingsFileName)
    }

    public func loadStoredCompanion() -> StoredCompanion? {
        loadJSON(StoredCompanion.self, fileName: companionFileName)
    }

    public func saveStoredCompanion(_ companion: StoredCompanion) {
        saveJSON(companion, fileName: companionFileName)
    }

    public func loadCompanionProfile() -> StoredCompanionProfile? {
        loadJSON(StoredCompanionProfile.self, fileName: companionFileName)
    }

    public func saveCompanionProfile(_ profile: StoredCompanionProfile) {
        saveJSON(profile, fileName: companionFileName)
    }

    public func companionFileExists() -> Bool {
        fileManager.fileExists(atPath: fileURL(for: companionFileName).path)
    }

    @discardableResult
    public func archiveExistingCompanionFile(reason: String) -> URL? {
        let sourceURL = fileURL(for: companionFileName)
        guard fileManager.fileExists(atPath: sourceURL.path) else { return nil }

        let sanitizedReason = reason
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        let timestamp = ISO8601DateFormatter().string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        let archiveURL = baseURL.appendingPathComponent("companion.\(sanitizedReason).\(timestamp).json")

        do {
            try fileManager.moveItem(at: sourceURL, to: archiveURL)
            return archiveURL
        } catch {
            NSLog("DesktopBuddy failed archiving companion.json: \(error.localizedDescription)")
            return nil
        }
    }

    public func loadGrowthState() -> GrowthState {
        loadJSON(GrowthState.self, fileName: growthFileName) ?? GrowthState()
    }

    public func saveGrowthState(_ state: GrowthState) {
        saveJSON(state, fileName: growthFileName)
    }

    // MARK: - Private

    private func ensureDirectories() {
        do {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            NSLog("DesktopBuddy failed to create app support directory: \(error.localizedDescription)")
        }
    }

    private func fileURL(for fileName: String) -> URL {
        baseURL.appendingPathComponent(fileName)
    }

    private func loadJSON<T: Decodable>(_ type: T.Type, fileName: String) -> T? {
        let url = fileURL(for: fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return try? decoder.decode(T.self, from: data)
    }

    private func saveJSON<T: Encodable>(_ value: T, fileName: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        do {
            let data = try encoder.encode(value)
            try data.write(to: fileURL(for: fileName), options: .atomic)
        } catch {
            NSLog("DesktopBuddy failed saving \(fileName): \(error.localizedDescription)")
        }
    }
}
