import Foundation
import XCTest
@testable import DesktopBuddy

final class DesktopBuddySettingsTests: XCTestCase {
    func testLegacySettingsDecodeMigratesArtStyleAndScale() throws {
        let json = """
        {
          "artStyle": "ASCII",
          "petScale": 2.0,
          "isMuted": true
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(DesktopBuddySettings.self, from: json)

        XCTAssertEqual(settings.preferredArtStyle, .ascii)
        XCTAssertEqual(settings.petScalePercent, 50)
        XCTAssertEqual(settings.petScale, 2.0)
        XCTAssertTrue(settings.isMuted)
    }

    func testScalePercentBacksComputedScale() {
        var settings = DesktopBuddySettings.default
        settings.petScalePercent = 75

        XCTAssertEqual(settings.petScale, 3.0)

        settings.petScale = 4.0
        XCTAssertEqual(settings.petScalePercent, 100)
    }
}
