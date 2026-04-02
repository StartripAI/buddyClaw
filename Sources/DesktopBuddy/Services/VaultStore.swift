import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public actor VaultStore {
    private let fileManager: FileManager
    private let baseURL: URL
    private let db: OpaquePointer
    private let calendar = Calendar(identifier: .gregorian)

    public init(fileManager: FileManager = .default, baseURL: URL? = nil) throws {
        self.fileManager = fileManager
        let supportURL = baseURL
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.baseURL = supportURL.appendingPathComponent("DesktopBuddy", isDirectory: true)
        try fileManager.createDirectory(at: self.baseURL, withIntermediateDirectories: true, attributes: nil)

        let dbURL = self.baseURL.appendingPathComponent("vault.sqlite")
        var rawDB: OpaquePointer?
        guard sqlite3_open(dbURL.path, &rawDB) == SQLITE_OK, let rawDB else {
            throw NSError(domain: "VaultStore", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to open vault.sqlite",
            ])
        }

        self.db = rawDB

        try Self.execute("PRAGMA foreign_keys = ON;", on: rawDB)
        try Self.execute("PRAGMA journal_mode = WAL;", on: rawDB)
        try Self.execute("PRAGMA synchronous = NORMAL;", on: rawDB)
        try Self.createSchemaIfNeeded(on: rawDB)
    }

    deinit {
        sqlite3_close(db)
    }

    public func bootstrapStarterPackIfNeeded(enabled: Bool) throws -> Bool {
        guard enabled else { return false }
        guard try hasKnowledgeContent() == false else { return false }
        let preferredPackName = L10n.currentLanguage.isChinese ? "starter-pack" : "starter-pack-en"
        let packURL =
            Bundle.module.url(
                forResource: preferredPackName,
                withExtension: "buddypack",
                subdirectory: "StarterPack"
            )
            ?? Bundle.module.url(
                forResource: preferredPackName,
                withExtension: "buddypack",
                subdirectory: "Resources/StarterPack"
            )
            ?? Bundle.module.url(
                forResource: "starter-pack",
                withExtension: "buddypack",
                subdirectory: "StarterPack"
            )
            ?? Bundle.module.url(
                forResource: "starter-pack",
                withExtension: "buddypack",
                subdirectory: "Resources/StarterPack"
            )

        guard let packURL else {
            return false
        }

        _ = try importPack(at: packURL, sourceLabel: "Starter Pack")
        return true
    }

    public func hasKnowledgeContent() throws -> Bool {
        try scalarInt("SELECT COUNT(*) FROM knowledge_items;") > 0
    }

    public func importFiles(at urls: [URL], retentionDays: Int) throws -> ImportResult {
        var total = 0
        var labels: [String] = []

        for url in urls {
            let ext = url.pathExtension.lowercased()
            let result: ImportResult
            switch ext {
            case "md", "markdown":
                result = try importTextLikeFile(at: url, sourceKind: .importedMarkdown)
            case "txt":
                result = try importTextLikeFile(at: url, sourceKind: .importedText)
            case "json":
                result = try importJSON(at: url)
            case "buddypack":
                result = try importPack(at: url, sourceLabel: url.deletingPathExtension().lastPathComponent)
            default:
                continue
            }
            total += result.importedCount
            labels.append(result.sourceLabel)
        }

        if total > 0 {
            try recordEvent(
                MemoryEvent(
                    kind: .importContent,
                    summary: L10n.format("导入了 %d 条资料。", "Imported %d items.", total),
                    metadata: ["sources": labels.joined(separator: ", ")],
                    frontmostApp: nil
                ),
                retentionDays: retentionDays
            )
        }

        return ImportResult(importedCount: total, sourceLabel: labels.joined(separator: ", "))
    }

    public func saveManualNote(title: String, body: String, tags: [String], retentionDays: Int) throws -> KnowledgeItem {
        let item = KnowledgeItem(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? L10n.text("未命名笔记", "Untitled Note") : title,
            body: body,
            sourceKind: .manualNote,
            tags: tags
        )
        try upsertKnowledgeItem(item)
        try recordEvent(
            MemoryEvent(
                kind: .manualNote,
                summary: L10n.currentLanguage.isChinese ? "新增笔记：\(item.title)" : "Added note: \(item.title)",
                metadata: ["itemID": item.id.uuidString],
                frontmostApp: nil
            ),
                retentionDays: retentionDays
            )
        return item
    }

    public func fetchKnowledgeItems(matching query: String? = nil, limit: Int = 200) throws -> [KnowledgeItem] {
        if let query, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            let like = "%\(query)%"
            return try queryKnowledgeItems(
                """
                SELECT id, title, body, source_kind, tags_json, created_at, updated_at, source_path
                FROM knowledge_items
                WHERE title LIKE ? OR body LIKE ?
                ORDER BY updated_at DESC
                LIMIT ?;
                """,
                bind: { stmt in
                    bindText(like, to: 1, in: stmt)
                    bindText(like, to: 2, in: stmt)
                    sqlite3_bind_int(stmt, 3, Int32(limit))
                }
            )
        }

        return try queryKnowledgeItems(
            """
            SELECT id, title, body, source_kind, tags_json, created_at, updated_at, source_path
            FROM knowledge_items
            ORDER BY updated_at DESC
            LIMIT ?;
            """,
            bind: { stmt in
                sqlite3_bind_int(stmt, 1, Int32(limit))
            }
        )
    }

    public func fetchMemoryEvents(limit: Int = 120) throws -> [MemoryEvent] {
        try queryMemoryEvents(
            """
            SELECT id, kind, timestamp, summary, metadata_json, frontmost_app
            FROM memory_events
            ORDER BY timestamp DESC
            LIMIT ?;
            """
        ) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(limit))
        }
    }

    public func fetchDailySummaries(limit: Int = 30) throws -> [DailySummary] {
        var summaries: [DailySummary] = []
        let stmt = try prepare(
            """
            SELECT timestamp, headline, highlights_json, stats_json
            FROM daily_summaries
            ORDER BY timestamp DESC
            LIMIT ?;
            """
        )
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int(stmt, 1, Int32(limit))

        while sqlite3_step(stmt) == SQLITE_ROW {
            let timestamp = sqlite3_column_double(stmt, 0)
            let headline = string(from: stmt, column: 1) ?? ""
            let highlights = decodeStringArray(from: string(from: stmt, column: 2)) ?? []
            let stats = decodeIntDictionary(from: string(from: stmt, column: 3)) ?? [:]
            summaries.append(
                DailySummary(
                    date: Date(timeIntervalSince1970: timestamp),
                    headline: headline,
                    highlights: highlights,
                    stats: stats
                )
            )
        }

        return summaries
    }

    public func latestDigest() throws -> MemoryDigest? {
        guard let summary = try fetchDailySummaries(limit: 1).first else {
            return nil
        }
        return MemoryDigest(date: summary.date, headline: summary.headline, highlights: summary.highlights)
    }

    public func todaySummary() throws -> DailySummary? {
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)

        let stmt = try prepare(
            """
            SELECT timestamp, headline, highlights_json, stats_json
            FROM daily_summaries
            WHERE timestamp >= ? AND timestamp < ?
            ORDER BY timestamp DESC
            LIMIT 1;
            """
        )
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, start.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 2, end.timeIntervalSince1970)

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return DailySummary(
            date: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0)),
            headline: string(from: stmt, column: 1) ?? "",
            highlights: decodeStringArray(from: string(from: stmt, column: 2)) ?? [],
            stats: decodeIntDictionary(from: string(from: stmt, column: 3)) ?? [:]
        )
    }

    public func libraryStats() throws -> LibraryStats {
        LibraryStats(
            itemCount: try scalarInt("SELECT COUNT(*) FROM knowledge_items;"),
            chunkCount: try scalarInt("SELECT COUNT(*) FROM knowledge_chunks;"),
            eventCount: try scalarInt("SELECT COUNT(*) FROM memory_events;"),
            summaryCount: try scalarInt("SELECT COUNT(*) FROM daily_summaries;")
        )
    }

    public func search(query: String, scope: AskScope, limit: Int = 6) throws -> [SearchHit] {
        let normalized = normalizedFTSQuery(query)
        var hits: [SearchHit] = []
        if normalized.isEmpty == false {
            if scope != .memoryOnly {
                hits.append(contentsOf: try searchKnowledge(normalizedQuery: normalized, limit: limit))
            }
            if scope != .knowledgeOnly {
                hits.append(contentsOf: try searchMemory(normalizedQuery: normalized, limit: limit))
            }
        }

        if hits.isEmpty, let fallbackToken = fallbackToken(from: query) {
            if scope != .memoryOnly {
                hits.append(contentsOf: try fallbackKnowledgeSearch(token: fallbackToken, limit: limit))
            }
            if scope != .knowledgeOnly {
                hits.append(contentsOf: try fallbackMemorySearch(token: fallbackToken, limit: limit))
            }
        }

        return hits.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    public func recordSnapshotTransition(
        previous: WorkSnapshot?,
        current: WorkSnapshot,
        retentionDays: Int
    ) throws {
        let currentApp = current.frontmostAppName ?? current.frontmostBundleIdentifier ?? L10n.text("未知应用", "Unknown App")

        if previous?.frontmostBundleIdentifier != current.frontmostBundleIdentifier {
            try recordEvent(
                MemoryEvent(
                    kind: .appSwitch,
                    timestamp: current.capturedAt,
                    summary: L10n.currentLanguage.isChinese ? "切换到了 \(currentApp)。" : "Switched to \(currentApp).",
                    metadata: ["bundle": current.frontmostBundleIdentifier ?? ""],
                    frontmostApp: current.frontmostAppName
                ),
                retentionDays: retentionDays
            )
        }

        let thresholds: [TimeInterval] = [1_800, 3_600, 7_200]
        for threshold in thresholds {
            let crossed = (previous?.continuousCodingSeconds ?? 0) < threshold && current.continuousCodingSeconds >= threshold
            if crossed {
                let minutes = Int(threshold / 60)
                try recordEvent(
                    MemoryEvent(
                        kind: .focusMilestone,
                        timestamp: current.capturedAt,
                        summary: L10n.currentLanguage.isChinese
                            ? "连续专注 \(minutes) 分钟，正在使用 \(currentApp)。"
                            : "Focused for \(minutes) minutes while using \(currentApp).",
                        metadata: ["thresholdMinutes": "\(minutes)"],
                        frontmostApp: current.frontmostAppName
                    ),
                    retentionDays: retentionDays
                )
            }
        }

        if (previous?.recentBuildFailure ?? false) == false && current.recentBuildFailure {
            try recordEvent(
                MemoryEvent(
                    kind: .buildFailure,
                    timestamp: current.capturedAt,
                    summary: L10n.currentLanguage.isChinese
                        ? "\(currentApp) 刚刚出现了一次构建失败。"
                        : "\(currentApp) just hit a build failure.",
                    metadata: [:],
                    frontmostApp: current.frontmostAppName
                ),
                retentionDays: retentionDays
            )
        }
    }

    public func recordEvent(_ event: MemoryEvent, retentionDays: Int) throws {
        let metadataJSON = encodeJSONString(event.metadata)
        let stmt = try prepare(
            """
            INSERT INTO memory_events (id, kind, timestamp, summary, metadata_json, frontmost_app)
            VALUES (?, ?, ?, ?, ?, ?);
            """
        )
        defer { sqlite3_finalize(stmt) }

        bindText(event.id.uuidString, to: 1, in: stmt)
        bindText(event.kind.rawValue, to: 2, in: stmt)
        sqlite3_bind_double(stmt, 3, event.timestamp.timeIntervalSince1970)
        bindText(event.summary, to: 4, in: stmt)
        bindText(metadataJSON, to: 5, in: stmt)
        bindText(event.frontmostApp, to: 6, in: stmt)
        try stepDone(stmt)

        let ftsStmt = try prepare(
            "INSERT INTO memory_events_fts (id, summary, frontmost_app) VALUES (?, ?, ?);"
        )
        defer { sqlite3_finalize(ftsStmt) }
        bindText(event.id.uuidString, to: 1, in: ftsStmt)
        bindText(event.summary, to: 2, in: ftsStmt)
        bindText(event.frontmostApp, to: 3, in: ftsStmt)
        try stepDone(ftsStmt)

        try pruneEvents(olderThanDays: retentionDays)
        _ = try rebuildDailySummary(for: event.timestamp)
    }

    private func createSchemaIfNeeded() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS knowledge_items (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                source_kind TEXT NOT NULL,
                tags_json TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                source_path TEXT
            );
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS knowledge_chunks (
                id TEXT PRIMARY KEY,
                item_id TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                text TEXT NOT NULL,
                FOREIGN KEY(item_id) REFERENCES knowledge_items(id) ON DELETE CASCADE
            );
            """
        )
        try execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_chunks_fts
            USING fts5(id UNINDEXED, item_id UNINDEXED, text);
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS memory_events (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                timestamp REAL NOT NULL,
                summary TEXT NOT NULL,
                metadata_json TEXT NOT NULL,
                frontmost_app TEXT
            );
            """
        )
        try execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS memory_events_fts
            USING fts5(id UNINDEXED, summary, frontmost_app);
            """
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS daily_summaries (
                date_key TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                headline TEXT NOT NULL,
                highlights_json TEXT NOT NULL,
                stats_json TEXT NOT NULL
            );
            """
        )
    }

    private static func createSchemaIfNeeded(on db: OpaquePointer) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS knowledge_items (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                source_kind TEXT NOT NULL,
                tags_json TEXT NOT NULL,
                created_at REAL NOT NULL,
                updated_at REAL NOT NULL,
                source_path TEXT
            );
            """,
            on: db
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS knowledge_chunks (
                id TEXT PRIMARY KEY,
                item_id TEXT NOT NULL,
                chunk_index INTEGER NOT NULL,
                text TEXT NOT NULL,
                FOREIGN KEY(item_id) REFERENCES knowledge_items(id) ON DELETE CASCADE
            );
            """,
            on: db
        )
        try execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS knowledge_chunks_fts
            USING fts5(id UNINDEXED, item_id UNINDEXED, text);
            """,
            on: db
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS memory_events (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                timestamp REAL NOT NULL,
                summary TEXT NOT NULL,
                metadata_json TEXT NOT NULL,
                frontmost_app TEXT
            );
            """,
            on: db
        )
        try execute(
            """
            CREATE VIRTUAL TABLE IF NOT EXISTS memory_events_fts
            USING fts5(id UNINDEXED, summary, frontmost_app);
            """,
            on: db
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS daily_summaries (
                date_key TEXT PRIMARY KEY,
                timestamp REAL NOT NULL,
                headline TEXT NOT NULL,
                highlights_json TEXT NOT NULL,
                stats_json TEXT NOT NULL
            );
            """,
            on: db
        )
    }

    private func importTextLikeFile(at url: URL, sourceKind: KnowledgeSourceKind) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        guard let body = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "VaultStore", code: 2, userInfo: [
                NSLocalizedDescriptionKey: L10n.currentLanguage.isChinese
                    ? "\(url.lastPathComponent) 使用了暂不支持的文本编码。"
                    : "Unsupported text encoding for \(url.lastPathComponent).",
            ])
        }

        let item = KnowledgeItem(
            title: url.deletingPathExtension().lastPathComponent,
            body: body,
            sourceKind: sourceKind,
            tags: suggestedTags(for: url),
            sourcePath: url.path
        )
        try upsertKnowledgeItem(item)
        return ImportResult(importedCount: 1, sourceLabel: url.lastPathComponent)
    }

    private func importJSON(at url: URL) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)

        if let array = object as? [[String: Any]] {
            var imported = 0
            for (index, entry) in array.enumerated() {
                let title = (entry["title"] as? String)
                    ?? (entry["name"] as? String)
                    ?? "\(url.deletingPathExtension().lastPathComponent) #\(index + 1)"
                let body = prettyJSONString(from: entry) ?? "\(entry)"
                let item = KnowledgeItem(
                    title: title,
                    body: body,
                    sourceKind: .importedJSON,
                    tags: suggestedTags(for: url),
                    sourcePath: url.path
                )
                try upsertKnowledgeItem(item)
                imported += 1
            }
            return ImportResult(importedCount: imported, sourceLabel: url.lastPathComponent)
        }

        let title = url.deletingPathExtension().lastPathComponent
        let body = prettyJSONString(from: object) ?? String(data: data, encoding: .utf8) ?? ""
        let item = KnowledgeItem(
            title: title,
            body: body,
            sourceKind: .importedJSON,
            tags: suggestedTags(for: url),
            sourcePath: url.path
        )
        try upsertKnowledgeItem(item)
        return ImportResult(importedCount: 1, sourceLabel: url.lastPathComponent)
    }

    private func importPack(at url: URL, sourceLabel: String) throws -> ImportResult {
        let data = try Data(contentsOf: url)
        let manifest = try JSONDecoder().decode(KnowledgePackManifest.self, from: data)
        var imported = 0
        for entry in manifest.items {
            let item = KnowledgeItem(
                title: entry.title,
                body: entry.body,
                sourceKind: .pack,
                tags: entry.tags + [manifest.title],
                sourcePath: "pack:\(manifest.packID)"
            )
            try upsertKnowledgeItem(item)
            imported += 1
        }
        return ImportResult(importedCount: imported, sourceLabel: sourceLabel)
    }

    private func upsertKnowledgeItem(_ item: KnowledgeItem) throws {
        let stmt = try prepare(
            """
            INSERT OR REPLACE INTO knowledge_items
            (id, title, body, source_kind, tags_json, created_at, updated_at, source_path)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
        )
        defer { sqlite3_finalize(stmt) }
        bindText(item.id.uuidString, to: 1, in: stmt)
        bindText(item.title, to: 2, in: stmt)
        bindText(item.body, to: 3, in: stmt)
        bindText(item.sourceKind.rawValue, to: 4, in: stmt)
        bindText(encodeJSONString(item.tags), to: 5, in: stmt)
        sqlite3_bind_double(stmt, 6, item.createdAt.timeIntervalSince1970)
        sqlite3_bind_double(stmt, 7, item.updatedAt.timeIntervalSince1970)
        bindText(item.sourcePath, to: 8, in: stmt)
        try stepDone(stmt)

        try deleteKnowledgeChunks(for: item.id.uuidString)

        let chunks = chunk(item.body).enumerated().map {
            KnowledgeChunk(itemID: item.id, chunkIndex: $0.offset, text: $0.element)
        }
        for chunk in chunks {
            let chunkStmt = try prepare(
                """
                INSERT INTO knowledge_chunks (id, item_id, chunk_index, text)
                VALUES (?, ?, ?, ?);
                """
            )
            defer { sqlite3_finalize(chunkStmt) }
            bindText(chunk.chunkID, to: 1, in: chunkStmt)
            bindText(chunk.itemID.uuidString, to: 2, in: chunkStmt)
            sqlite3_bind_int(chunkStmt, 3, Int32(chunk.chunkIndex))
            bindText(chunk.text, to: 4, in: chunkStmt)
            try stepDone(chunkStmt)

            let ftsStmt = try prepare(
                "INSERT INTO knowledge_chunks_fts (id, item_id, text) VALUES (?, ?, ?);"
            )
            defer { sqlite3_finalize(ftsStmt) }
            bindText(chunk.chunkID, to: 1, in: ftsStmt)
            bindText(chunk.itemID.uuidString, to: 2, in: ftsStmt)
            bindText(chunk.text, to: 3, in: ftsStmt)
            try stepDone(ftsStmt)
        }
    }

    private func deleteKnowledgeChunks(for itemID: String) throws {
        let existingChunkIDs = try queryStrings(
            "SELECT id FROM knowledge_chunks WHERE item_id = ?;",
            bind: { stmt in bindText(itemID, to: 1, in: stmt) }
        )

        let deleteChunks = try prepare("DELETE FROM knowledge_chunks WHERE item_id = ?;")
        defer { sqlite3_finalize(deleteChunks) }
        bindText(itemID, to: 1, in: deleteChunks)
        try stepDone(deleteChunks)

        for chunkID in existingChunkIDs {
            let deleteFTS = try prepare("DELETE FROM knowledge_chunks_fts WHERE id = ?;")
            defer { sqlite3_finalize(deleteFTS) }
            bindText(chunkID, to: 1, in: deleteFTS)
            try stepDone(deleteFTS)
        }
    }

    private func rebuildDailySummary(for date: Date) throws -> DailySummary {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        let events = try queryMemoryEvents(
            """
            SELECT id, kind, timestamp, summary, metadata_json, frontmost_app
            FROM memory_events
            WHERE timestamp >= ? AND timestamp < ?
            ORDER BY timestamp DESC;
            """
        ) { stmt in
            sqlite3_bind_double(stmt, 1, start.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 2, end.timeIntervalSince1970)
        }

        let askCount = events.filter { $0.kind == .ask }.count
        let noteCount = events.filter { $0.kind == .manualNote || $0.kind == .importContent }.count
        let focusCount = events.filter { $0.kind == .focusMilestone }.count
        let buildFailures = events.filter { $0.kind == .buildFailure }.count

        let headline: String
        if askCount > 0 {
            headline = L10n.currentLanguage.isChinese
                ? "今天你和宠物一起查阅了 \(askCount) 次本地记忆。"
                : "Today you and your pet searched local memory \(askCount) times."
        } else if focusCount > 0 {
            headline = L10n.currentLanguage.isChinese
                ? "今天有 \(focusCount) 次专注里程碑，被我悄悄记住了。"
                : "Today I quietly recorded \(focusCount) focus milestones."
        } else if noteCount > 0 {
            headline = L10n.currentLanguage.isChinese
                ? "今天补充了 \(noteCount) 条资料，记忆库更厚了。"
                : "Today you added \(noteCount) items, and the vault grew richer."
        } else if buildFailures > 0 {
            headline = L10n.currentLanguage.isChinese
                ? "今天我注意到 \(buildFailures) 次构建波动。"
                : "Today I noticed \(buildFailures) build failures."
        } else if events.isEmpty == false {
            headline = L10n.currentLanguage.isChinese
                ? "今天发生了 \(events.count) 条值得记住的小事。"
                : "Today there were \(events.count) small things worth remembering."
        } else {
            headline = L10n.text("今天还没有新的本地记忆。", "There is no new local memory for today yet.")
        }

        let summary = DailySummary(
            date: start,
            headline: headline,
            highlights: Array(events.prefix(3).map(\.summary)),
            stats: [
                "eventCount": events.count,
                "askCount": askCount,
                "noteCount": noteCount,
                "focusCount": focusCount,
                "buildFailures": buildFailures,
            ]
        )

        let stmt = try prepare(
            """
            INSERT OR REPLACE INTO daily_summaries
            (date_key, timestamp, headline, highlights_json, stats_json)
            VALUES (?, ?, ?, ?, ?);
            """
        )
        defer { sqlite3_finalize(stmt) }
        bindText(dayKey(for: start), to: 1, in: stmt)
        sqlite3_bind_double(stmt, 2, start.timeIntervalSince1970)
        bindText(summary.headline, to: 3, in: stmt)
        bindText(encodeJSONString(summary.highlights), to: 4, in: stmt)
        bindText(encodeJSONString(summary.stats), to: 5, in: stmt)
        try stepDone(stmt)

        return summary
    }

    private func pruneEvents(olderThanDays retentionDays: Int) throws {
        guard retentionDays > 0 else { return }
        let cutoff = Date().addingTimeInterval(TimeInterval(-retentionDays * 86_400))
        let oldIDs = try queryStrings(
            "SELECT id FROM memory_events WHERE timestamp < ?;",
            bind: { stmt in sqlite3_bind_double(stmt, 1, cutoff.timeIntervalSince1970) }
        )
        guard oldIDs.isEmpty == false else { return }

        let deleteEvents = try prepare("DELETE FROM memory_events WHERE timestamp < ?;")
        defer { sqlite3_finalize(deleteEvents) }
        sqlite3_bind_double(deleteEvents, 1, cutoff.timeIntervalSince1970)
        try stepDone(deleteEvents)

        for id in oldIDs {
            let deleteFTS = try prepare("DELETE FROM memory_events_fts WHERE id = ?;")
            defer { sqlite3_finalize(deleteFTS) }
            bindText(id, to: 1, in: deleteFTS)
            try stepDone(deleteFTS)
        }
    }

    private func searchKnowledge(normalizedQuery: String, limit: Int) throws -> [SearchHit] {
        var hits: [SearchHit] = []
        let stmt = try prepare(
            """
            SELECT knowledge_items.id, knowledge_chunks.text, knowledge_items.updated_at, bm25(knowledge_chunks_fts)
            FROM knowledge_chunks_fts
            JOIN knowledge_chunks ON knowledge_chunks.id = knowledge_chunks_fts.id
            JOIN knowledge_items ON knowledge_items.id = knowledge_chunks.item_id
            WHERE knowledge_chunks_fts MATCH ?
            ORDER BY bm25(knowledge_chunks_fts)
            LIMIT ?;
            """
        )
        defer { sqlite3_finalize(stmt) }
        bindText(normalizedQuery, to: 1, in: stmt)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        while sqlite3_step(stmt) == SQLITE_ROW {
            let sourceID = string(from: stmt, column: 0) ?? ""
            let excerpt = string(from: stmt, column: 1) ?? ""
            let timestamp = sqlite3_column_double(stmt, 2)
            let rawScore = sqlite3_column_double(stmt, 3)
            hits.append(
                SearchHit(
                    sourceKind: .knowledge,
                    sourceID: sourceID,
                    excerpt: excerpt,
                    score: normalizedScore(from: rawScore),
                    timestamp: Date(timeIntervalSince1970: timestamp)
                )
            )
        }

        return hits
    }

    private func searchMemory(normalizedQuery: String, limit: Int) throws -> [SearchHit] {
        var hits: [SearchHit] = []
        let stmt = try prepare(
            """
            SELECT memory_events.id, memory_events.summary, memory_events.timestamp, bm25(memory_events_fts)
            FROM memory_events_fts
            JOIN memory_events ON memory_events.id = memory_events_fts.id
            WHERE memory_events_fts MATCH ?
            ORDER BY bm25(memory_events_fts)
            LIMIT ?;
            """
        )
        defer { sqlite3_finalize(stmt) }
        bindText(normalizedQuery, to: 1, in: stmt)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        while sqlite3_step(stmt) == SQLITE_ROW {
            let sourceID = string(from: stmt, column: 0) ?? ""
            let excerpt = string(from: stmt, column: 1) ?? ""
            let timestamp = sqlite3_column_double(stmt, 2)
            let rawScore = sqlite3_column_double(stmt, 3)
            hits.append(
                SearchHit(
                    sourceKind: .memory,
                    sourceID: sourceID,
                    excerpt: excerpt,
                    score: normalizedScore(from: rawScore),
                    timestamp: Date(timeIntervalSince1970: timestamp)
                )
            )
        }

        return hits
    }

    private func fallbackKnowledgeSearch(token: String, limit: Int) throws -> [SearchHit] {
        var hits: [SearchHit] = []
        let like = "%\(token)%"
        let stmt = try prepare(
            """
            SELECT id, body, updated_at
            FROM knowledge_items
            WHERE title LIKE ? OR body LIKE ?
            ORDER BY updated_at DESC
            LIMIT ?;
            """
        )
        defer { sqlite3_finalize(stmt) }
        bindText(like, to: 1, in: stmt)
        bindText(like, to: 2, in: stmt)
        sqlite3_bind_int(stmt, 3, Int32(limit))

        while sqlite3_step(stmt) == SQLITE_ROW {
            hits.append(
                SearchHit(
                    sourceKind: .knowledge,
                    sourceID: string(from: stmt, column: 0) ?? "",
                    excerpt: String((string(from: stmt, column: 1) ?? "").prefix(220)),
                    score: 0.22,
                    timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                )
            )
        }
        return hits
    }

    private func fallbackMemorySearch(token: String, limit: Int) throws -> [SearchHit] {
        var hits: [SearchHit] = []
        let like = "%\(token)%"
        let stmt = try prepare(
            """
            SELECT id, summary, timestamp
            FROM memory_events
            WHERE summary LIKE ?
            ORDER BY timestamp DESC
            LIMIT ?;
            """
        )
        defer { sqlite3_finalize(stmt) }
        bindText(like, to: 1, in: stmt)
        sqlite3_bind_int(stmt, 2, Int32(limit))

        while sqlite3_step(stmt) == SQLITE_ROW {
            hits.append(
                SearchHit(
                    sourceKind: .memory,
                    sourceID: string(from: stmt, column: 0) ?? "",
                    excerpt: string(from: stmt, column: 1) ?? "",
                    score: 0.18,
                    timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
                )
            )
        }
        return hits
    }

    private func queryKnowledgeItems(
        _ sql: String,
        bind: (OpaquePointer) -> Void
    ) throws -> [KnowledgeItem] {
        var items: [KnowledgeItem] = []
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: string(from: stmt, column: 0) ?? "") ?? UUID()
            let title = string(from: stmt, column: 1) ?? ""
            let body = string(from: stmt, column: 2) ?? ""
            let sourceKind = KnowledgeSourceKind(rawValue: string(from: stmt, column: 3) ?? "") ?? .manualNote
            let tags = decodeStringArray(from: string(from: stmt, column: 4)) ?? []
            let createdAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5))
            let updatedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 6))
            let sourcePath = string(from: stmt, column: 7)

            items.append(
                KnowledgeItem(
                    id: id,
                    title: title,
                    body: body,
                    sourceKind: sourceKind,
                    tags: tags,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    sourcePath: sourcePath
                )
            )
        }
        return items
    }

    private func queryMemoryEvents(
        _ sql: String,
        bind: (OpaquePointer) -> Void
    ) throws -> [MemoryEvent] {
        var events: [MemoryEvent] = []
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            let id = UUID(uuidString: string(from: stmt, column: 0) ?? "") ?? UUID()
            let kind = MemoryEventKind(rawValue: string(from: stmt, column: 1) ?? "") ?? .appSwitch
            let timestamp = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2))
            let summary = string(from: stmt, column: 3) ?? ""
            let metadata = decodeStringDictionary(from: string(from: stmt, column: 4)) ?? [:]
            let frontmostApp = string(from: stmt, column: 5)
            events.append(
                MemoryEvent(
                    id: id,
                    kind: kind,
                    timestamp: timestamp,
                    summary: summary,
                    metadata: metadata,
                    frontmostApp: frontmostApp
                )
            )
        }
        return events
    }

    private func queryStrings(
        _ sql: String,
        bind: (OpaquePointer) -> Void
    ) throws -> [String] {
        var values: [String] = []
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        bind(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            values.append(string(from: stmt, column: 0) ?? "")
        }
        return values
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw sqliteError(message: "Failed to prepare SQL", sql: sql)
        }
        return stmt
    }

    private func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(message: "Failed to execute SQL", sql: sql)
        }
    }

    private static func execute(_ sql: String, on db: OpaquePointer) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw sqliteError(message: "Failed to execute SQL", sql: sql, db: db)
        }
    }

    private func stepDone(_ stmt: OpaquePointer) throws {
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw sqliteError(message: "Failed stepping SQL statement", sql: nil)
        }
    }

    private func scalarInt(_ sql: String) throws -> Int {
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    private func sqliteError(message: String, sql: String?) -> NSError {
        let reason = String(cString: sqlite3_errmsg(db))
        let sqlPart = sql.map { " SQL: \($0)" } ?? ""
        return NSError(domain: "VaultStore", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "\(message). \(reason)\(sqlPart)",
        ])
    }

    private static func sqliteError(message: String, sql: String?, db: OpaquePointer) -> NSError {
        let reason = String(cString: sqlite3_errmsg(db))
        let sqlPart = sql.map { " SQL: \($0)" } ?? ""
        return NSError(domain: "VaultStore", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "\(message). \(reason)\(sqlPart)",
        ])
    }

    private func bindText(_ value: String?, to index: Int32, in stmt: OpaquePointer) {
        if let value {
            sqlite3_bind_text(stmt, index, value, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func string(from stmt: OpaquePointer, column: Int32) -> String? {
        guard let pointer = sqlite3_column_text(stmt, column) else { return nil }
        return String(cString: pointer)
    }

    private func normalizedFTSQuery(_ query: String) -> String {
        let tokens = query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }

        guard tokens.isEmpty == false else { return "" }
        return tokens.map { "\($0)*" }.joined(separator: " AND ")
    }

    private func fallbackToken(from query: String) -> String? {
        let alphaNumericTokens = query
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }

        if let preferred = alphaNumericTokens.first(where: {
            $0.range(of: "[a-z0-9]", options: .regularExpression) != nil
        }) {
            return preferred
        }

        if let first = alphaNumericTokens.first {
            return first
        }

        return query
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { $0.isEmpty == false })
    }

    private func normalizedScore(from raw: Double) -> Double {
        let magnitude = abs(raw)
        return 1.0 / (1.0 + magnitude)
    }

    private func chunk(_ text: String, maxLength: Int = 320) -> [String] {
        let cleaned = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleaned.isEmpty == false else { return [""] }

        let paragraphs = cleaned
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        var chunks: [String] = []
        var current = ""

        for paragraph in paragraphs {
            if paragraph.count > maxLength {
                if current.isEmpty == false {
                    chunks.append(current)
                    current = ""
                }

                var start = paragraph.startIndex
                while start < paragraph.endIndex {
                    let end = paragraph.index(start, offsetBy: maxLength, limitedBy: paragraph.endIndex) ?? paragraph.endIndex
                    chunks.append(String(paragraph[start..<end]))
                    start = end
                }
                continue
            }

            let candidate = current.isEmpty ? paragraph : "\(current)\n\n\(paragraph)"
            if candidate.count <= maxLength {
                current = candidate
            } else {
                if current.isEmpty == false {
                    chunks.append(current)
                }
                current = paragraph
            }
        }

        if current.isEmpty == false {
            chunks.append(current)
        }

        return chunks.isEmpty ? [cleaned] : chunks
    }

    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 0
        let month = parts.month ?? 0
        let day = parts.day ?? 0
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func encodeJSONString<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }

    private func decodeStringArray(from value: String?) -> [String]? {
        guard let value, let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String].self, from: data)
    }

    private func decodeStringDictionary(from value: String?) -> [String: String]? {
        guard let value, let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    private func decodeIntDictionary(from value: String?) -> [String: Int]? {
        guard let value, let data = value.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([String: Int].self, from: data)
    }

    private func suggestedTags(for url: URL) -> [String] {
        var tags: [String] = []
        tags.append(url.pathExtension.uppercased())
        let filename = url.deletingPathExtension().lastPathComponent
        if filename.isEmpty == false {
            tags.append(filename)
        }
        return tags
    }

    private func prettyJSONString(from object: Any) -> String? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }
}
