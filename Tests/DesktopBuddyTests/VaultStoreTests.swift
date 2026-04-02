import Foundation
import XCTest
@testable import DesktopBuddy

final class VaultStoreTests: XCTestCase {
    func testManualNoteIsIndexedAndAnswerableOffline() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let vault = try VaultStore(baseURL: rootURL)
        _ = try await vault.saveManualNote(
            title: "构建记录",
            body: "今天 Xcode build failed，因为资源路径写错了，修正后再次构建成功。",
            tags: ["xcode", "build"],
            retentionDays: 90
        )

        let hits = try await vault.search(query: "build failed 资源路径", scope: .all, limit: 5)
        XCTAssertFalse(hits.isEmpty)
        XCTAssertEqual(hits.first?.sourceKind, .knowledge)

        let provider = ExtractiveAnswerProvider(vault: vault)
        let result = try await provider.answer(question: "今天为什么 build failed？", scope: .all)

        XCTAssertFalse(result.citations.isEmpty)
        XCTAssertGreaterThan(result.confidence, 0.1)
        XCTAssertFalse(result.answer.isEmpty)
    }

    func testMemoryEventBuildsDailySummary() async throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let vault = try VaultStore(baseURL: rootURL)
        try await vault.recordEvent(
            MemoryEvent(
                kind: .focusMilestone,
                summary: "连续专注 60 分钟，正在使用 Xcode。",
                metadata: ["thresholdMinutes": "60"],
                frontmostApp: "Xcode"
            ),
            retentionDays: 90
        )

        let today = try await vault.todaySummary()
        XCTAssertNotNil(today)
        XCTAssertEqual(today?.stats["focusCount"], 1)
        XCTAssertFalse(today?.headline.isEmpty ?? true)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
