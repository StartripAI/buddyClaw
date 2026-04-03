import Foundation

public enum DistributionChannel: String, CaseIterable, Codable, Sendable {
    case direct = "direct"
    case appStore = "app-store"

    public static var current: DistributionChannel {
        #if APP_STORE_DISTRIBUTION
        return .appStore
        #elseif DIRECT_DISTRIBUTION
        return .direct
        #else
        if let rawValue = Bundle.main.object(forInfoDictionaryKey: "BuddyClawDistributionChannel") as? String,
           let resolved = DistributionChannel(rawValue: rawValue) {
            return resolved
        }
        return .direct
        #endif
    }

    public var requiresExplicitActivityConsent: Bool {
        self == .appStore
    }
}

public enum ActivityMonitoringConsentState: String, CaseIterable, Codable, Sendable {
    case notDetermined
    case declined
    case granted
}

public struct ActivityMonitoringDefaults: Equatable, Sendable {
    public var enabled: Bool
    public var consentState: ActivityMonitoringConsentState
    public var hasSeenOnboarding: Bool

    public init(
        enabled: Bool,
        consentState: ActivityMonitoringConsentState,
        hasSeenOnboarding: Bool
    ) {
        self.enabled = enabled
        self.consentState = consentState
        self.hasSeenOnboarding = hasSeenOnboarding
    }
}

public enum ActivityMonitoringPolicy {
    public static func defaults(for channel: DistributionChannel) -> ActivityMonitoringDefaults {
        switch channel {
        case .direct:
            return ActivityMonitoringDefaults(
                enabled: true,
                consentState: .granted,
                hasSeenOnboarding: true
            )
        case .appStore:
            return ActivityMonitoringDefaults(
                enabled: false,
                consentState: .notDetermined,
                hasSeenOnboarding: false
            )
        }
    }

    public static func observationCapabilities(
        settings: DesktopBuddySettings,
        channel: DistributionChannel
    ) -> WorkStateObserver.MonitoringCapabilities {
        guard settings.activityMonitoringEnabled else { return [] }
        guard channel.requiresExplicitActivityConsent == false || settings.activityMonitoringConsentState == .granted else {
            return []
        }
        return .all
    }

    public static func isMonitoringActive(
        settings: DesktopBuddySettings,
        channel: DistributionChannel
    ) -> Bool {
        observationCapabilities(settings: settings, channel: channel).isEmpty == false
    }
}
