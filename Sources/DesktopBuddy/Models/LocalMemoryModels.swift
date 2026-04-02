import Foundation

public enum KnowledgeSourceKind: String, CaseIterable, Codable, Sendable, Equatable {
    case manualNote
    case importedMarkdown
    case importedText
    case importedJSON
    case pack

    public var displayName: String {
        switch self {
        case .manualNote: return L10n.text("手动笔记", "Manual Note")
        case .importedMarkdown: return "Markdown"
        case .importedText: return L10n.text("文本", "Text")
        case .importedJSON: return "JSON"
        case .pack: return L10n.text("内容包", "Pack")
        }
    }
}

public struct KnowledgeItem: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var title: String
    public var body: String
    public var sourceKind: KnowledgeSourceKind
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    public var sourcePath: String?

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        sourceKind: KnowledgeSourceKind,
        tags: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sourcePath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.sourceKind = sourceKind
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourcePath = sourcePath
    }
}

public struct KnowledgeChunk: Codable, Sendable, Equatable {
    public var itemID: UUID
    public var chunkIndex: Int
    public var text: String

    public init(itemID: UUID, chunkIndex: Int, text: String) {
        self.itemID = itemID
        self.chunkIndex = chunkIndex
        self.text = text
    }

    public var chunkID: String {
        "\(itemID.uuidString)-\(chunkIndex)"
    }
}

public enum MemoryEventKind: String, CaseIterable, Codable, Sendable, Equatable {
    case appSwitch
    case focusMilestone
    case buildFailure
    case petting
    case proactiveComment
    case ask
    case importContent
    case manualNote
    case dailyReview

    public var displayName: String {
        switch self {
        case .appSwitch: return L10n.text("切换应用", "App Switch")
        case .focusMilestone: return L10n.text("专注里程碑", "Focus Milestone")
        case .buildFailure: return L10n.text("构建失败", "Build Failure")
        case .petting: return L10n.text("摸摸互动", "Petting")
        case .proactiveComment: return L10n.text("主动提醒", "Proactive Prompt")
        case .ask: return L10n.text("本地问答", "Local Q&A")
        case .importContent: return L10n.text("导入资料", "Import")
        case .manualNote: return L10n.text("手动笔记", "Manual Note")
        case .dailyReview: return L10n.text("今日回顾", "Daily Review")
        }
    }
}

public struct MemoryEvent: Identifiable, Codable, Sendable, Equatable {
    public var id: UUID
    public var kind: MemoryEventKind
    public var timestamp: Date
    public var summary: String
    public var metadata: [String: String]
    public var frontmostApp: String?

    public init(
        id: UUID = UUID(),
        kind: MemoryEventKind,
        timestamp: Date = .now,
        summary: String,
        metadata: [String: String] = [:],
        frontmostApp: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.summary = summary
        self.metadata = metadata
        self.frontmostApp = frontmostApp
    }
}

public struct DailySummary: Codable, Sendable, Equatable {
    public var date: Date
    public var headline: String
    public var highlights: [String]
    public var stats: [String: Int]

    public init(
        date: Date,
        headline: String,
        highlights: [String],
        stats: [String: Int]
    ) {
        self.date = date
        self.headline = headline
        self.highlights = highlights
        self.stats = stats
    }
}

public enum SearchHitSourceKind: String, Codable, Sendable, Equatable {
    case knowledge
    case memory
}

public struct SearchHit: Codable, Sendable, Equatable {
    public var sourceKind: SearchHitSourceKind
    public var sourceID: String
    public var excerpt: String
    public var score: Double
    public var timestamp: Date

    public init(
        sourceKind: SearchHitSourceKind,
        sourceID: String,
        excerpt: String,
        score: Double,
        timestamp: Date
    ) {
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.excerpt = excerpt
        self.score = score
        self.timestamp = timestamp
    }
}

public struct AskResult: Codable, Sendable, Equatable {
    public var question: String
    public var answer: String
    public var citations: [SearchHit]
    public var confidence: Double

    public init(
        question: String,
        answer: String,
        citations: [SearchHit],
        confidence: Double
    ) {
        self.question = question
        self.answer = answer
        self.citations = citations
        self.confidence = confidence
    }
}

public struct KnowledgePackItem: Codable, Sendable, Equatable {
    public var title: String
    public var body: String
    public var tags: [String]

    public init(title: String, body: String, tags: [String] = []) {
        self.title = title
        self.body = body
        self.tags = tags
    }
}

public struct KnowledgePackManifest: Codable, Sendable, Equatable {
    public var packID: String
    public var version: String
    public var title: String
    public var items: [KnowledgePackItem]

    public init(
        packID: String,
        version: String,
        title: String,
        items: [KnowledgePackItem]
    ) {
        self.packID = packID
        self.version = version
        self.title = title
        self.items = items
    }
}

public struct LibraryStats: Sendable, Equatable {
    public var itemCount: Int
    public var chunkCount: Int
    public var eventCount: Int
    public var summaryCount: Int

    public init(
        itemCount: Int = 0,
        chunkCount: Int = 0,
        eventCount: Int = 0,
        summaryCount: Int = 0
    ) {
        self.itemCount = itemCount
        self.chunkCount = chunkCount
        self.eventCount = eventCount
        self.summaryCount = summaryCount
    }
}

public struct MemoryDigest: Sendable, Equatable {
    public var date: Date
    public var headline: String
    public var highlights: [String]

    public init(date: Date, headline: String, highlights: [String]) {
        self.date = date
        self.headline = headline
        self.highlights = highlights
    }
}

public struct ImportResult: Sendable, Equatable {
    public var importedCount: Int
    public var sourceLabel: String

    public init(importedCount: Int, sourceLabel: String) {
        self.importedCount = importedCount
        self.sourceLabel = sourceLabel
    }
}
