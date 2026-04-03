import XCTest
@testable import DesktopBuddy

@MainActor
final class WorkStateObserverTests: XCTestCase {
    func testObserverStartsAndStopsRequestedCapabilities() {
        let observer = WorkStateObserver()

        observer.start(capabilities: [])
        XCTAssertFalse(observer.isMonitoringActive)
        XCTAssertTrue(observer.activeCapabilities.isEmpty)

        observer.start(capabilities: [.frontmostApp])
        XCTAssertTrue(observer.isMonitoringActive)
        XCTAssertEqual(observer.activeCapabilities, [.frontmostApp])

        observer.stop()
        XCTAssertFalse(observer.isMonitoringActive)
        XCTAssertTrue(observer.activeCapabilities.isEmpty)
    }

    func testPolicyDisablesObservationForAppStoreUntilConsent() {
        var settings = DesktopBuddySettings(channel: .appStore)
        settings.activityMonitoringEnabled = true
        settings.activityMonitoringConsentState = .notDetermined

        XCTAssertTrue(
            ActivityMonitoringPolicy.observationCapabilities(
                settings: settings,
                channel: .appStore
            ).isEmpty
        )

        settings.activityMonitoringConsentState = .granted
        XCTAssertEqual(
            ActivityMonitoringPolicy.observationCapabilities(
                settings: settings,
                channel: .appStore
            ),
            .all
        )
    }
}
