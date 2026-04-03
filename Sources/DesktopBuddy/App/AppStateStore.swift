import Foundation
import Combine

// MARK: - 内存态单一数据源 / In-memory single source of truth

@MainActor
public final class AppStateStore: ObservableObject {
    @Published public var settings: DesktopBuddySettings
    @Published public var companionProfile: StoredCompanionProfile
    @Published public var companion: Companion
    @Published public var growthState: GrowthState
    @Published public var latestWorkSnapshot: WorkSnapshot?
    @Published public var isActivityMonitoringActive: Bool
    @Published public var libraryStats: LibraryStats
    @Published public var recentMemoryDigest: MemoryDigest?
    @Published public var lastAskResult: AskResult?

    public init(
        settings: DesktopBuddySettings,
        companionProfile: StoredCompanionProfile,
        companion: Companion,
        growthState: GrowthState,
        isActivityMonitoringActive: Bool = false,
        libraryStats: LibraryStats = LibraryStats(),
        recentMemoryDigest: MemoryDigest? = nil,
        lastAskResult: AskResult? = nil
    ) {
        self.settings = settings
        self.companionProfile = companionProfile
        self.companion = companion
        self.growthState = growthState
        self.latestWorkSnapshot = nil
        self.isActivityMonitoringActive = isActivityMonitoringActive
        self.libraryStats = libraryStats
        self.recentMemoryDigest = recentMemoryDigest
        self.lastAskResult = lastAskResult
    }
}
