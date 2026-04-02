import XCTest
@testable import DesktopBuddy

final class CompanionGeneratorTests: XCTestCase {
    func testDeterministicRollMatchesReferencePort() {
        let generator = CompanionGenerator()
        let roll = generator.roll(userID: "alice@example.com")

        XCTAssertEqual(roll.bones.rarity, .epic)
        XCTAssertEqual(roll.bones.species, .owl)
        XCTAssertEqual(roll.bones.eye, .at)
        XCTAssertEqual(roll.bones.hat, .tophat)
        XCTAssertEqual(roll.bones.shiny, false)
        XCTAssertEqual(roll.bones.stats[.debugging], 87)
        XCTAssertEqual(roll.bones.stats[.patience], 47)
        XCTAssertEqual(roll.bones.stats[.chaos], 63)
        XCTAssertEqual(roll.bones.stats[.wisdom], 45)
        XCTAssertEqual(roll.bones.stats[.snark], 30)
        XCTAssertEqual(roll.inspirationSeed, 389_707_495)
    }

    func testRollWithSeedIsStable() {
        let generator = CompanionGenerator()
        let first = generator.rollWithSeed("seed-123")
        let second = generator.rollWithSeed("seed-123")

        XCTAssertEqual(first.bones.rarity, second.bones.rarity)
        XCTAssertEqual(first.bones.species, second.bones.species)
        XCTAssertEqual(first.bones.eye, second.bones.eye)
        XCTAssertEqual(first.bones.hat, second.bones.hat)
        XCTAssertEqual(first.bones.shiny, second.bones.shiny)
        XCTAssertEqual(first.bones.stats[.wisdom], second.bones.stats[.wisdom])
        XCTAssertEqual(first.inspirationSeed, second.inspirationSeed)
    }
}
