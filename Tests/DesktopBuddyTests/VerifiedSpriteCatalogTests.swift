import XCTest
@testable import DesktopBuddy

final class VerifiedSpriteCatalogTests: XCTestCase {
    func testCatalogContainsAllPixelReleaseSprites() {
        let catalog = VerifiedSpriteCatalog()

        XCTAssertEqual(catalog.availableSpecies.count, 18)
        XCTAssertEqual(Set(catalog.availableSpecies), Set(Species.allCases))
        XCTAssertEqual(catalog.defaultSpecies, .cat)
        XCTAssertEqual(catalog.availableStyles, ArtStyle.allCases)
        XCTAssertEqual(Set(catalog.availableSpecies(for: .ascii)), Set(Species.allCases))
        XCTAssertEqual(Set(catalog.availableSpecies(for: .pixel)), Set(Species.allCases))
        XCTAssertEqual(catalog.availableSpecies(for: .claw), [])

        for species in Species.allCases {
            XCTAssertTrue(catalog.isVerified(species), "Expected \(species.rawValue) to be verified")
            XCTAssertNotNil(catalog.spriteURL(for: species), "Expected a runtime sprite URL for \(species.rawValue)")
            XCTAssertTrue(catalog.isAvailable(style: .ascii, species: species))
            XCTAssertTrue(catalog.isAvailable(style: .pixel, species: species))
            XCTAssertFalse(catalog.isAvailable(style: .claw, species: species))
            XCTAssertNotNil(catalog.spriteURL(for: species, style: .pixel))
            XCTAssertNil(catalog.spriteURL(for: species, style: .claw))
            XCTAssertEqual(catalog.resolvedStyle(preferred: .claw, species: species), .pixel)
        }
    }
}
