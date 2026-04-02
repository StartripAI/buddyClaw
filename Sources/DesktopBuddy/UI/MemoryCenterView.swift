import SwiftUI

public enum MemoryCenterTab: Int, CaseIterable, Sendable {
    case library
    case timeline
    case ask

    public var title: String {
        switch self {
        case .library: return L10n.text("资料库", "Library")
        case .timeline: return L10n.text("时间线", "Timeline")
        case .ask: return L10n.text("问问我", "Ask")
        }
    }

    public var systemImage: String {
        switch self {
        case .library: return "books.vertical"
        case .timeline: return "clock.arrow.circlepath"
        case .ask: return "sparkle.magnifyingglass"
        }
    }
}

@MainActor
public final class MemoryCenterViewModel: ObservableObject {
    @Published public var selectedTab: MemoryCenterTab
    @Published public var libraryItems: [KnowledgeItem] = []
    @Published public var timelineEvents: [MemoryEvent] = []
    @Published public var dailySummaries: [DailySummary] = []
    @Published public var libraryQuery: String = ""
    @Published public var askQuestion: String = ""
    @Published public var askResult: AskResult?
    @Published public var noteTitle: String = ""
    @Published public var noteBody: String = ""
    @Published public var noteTags: String = ""
    @Published public var isBusy: Bool = false
    @Published public var statusMessage: String?

    private let vault: VaultStore
    private let answerProvider: any AnswerProvider
    private let settingsProvider: @MainActor () -> DesktopBuddySettings
    private let appStateUpdater: @MainActor (LibraryStats, MemoryDigest?, AskResult?) -> Void
    private let importHandler: @MainActor () -> Void
    private var didLoad = false

    public init(
        selectedTab: MemoryCenterTab = .library,
        vault: VaultStore,
        answerProvider: any AnswerProvider,
        settingsProvider: @escaping @MainActor () -> DesktopBuddySettings,
        appStateUpdater: @escaping @MainActor (LibraryStats, MemoryDigest?, AskResult?) -> Void,
        importHandler: @escaping @MainActor () -> Void
    ) {
        self.selectedTab = selectedTab
        self.vault = vault
        self.answerProvider = answerProvider
        self.settingsProvider = settingsProvider
        self.appStateUpdater = appStateUpdater
        self.importHandler = importHandler
    }

    public func loadIfNeeded() async {
        guard didLoad == false else { return }
        didLoad = true
        await refresh()
    }

    public func refresh() async {
        isBusy = true
        defer { isBusy = false }

        do {
            let items = try await vault.fetchKnowledgeItems(matching: libraryQuery.isEmpty ? nil : libraryQuery)
            let events = try await vault.fetchMemoryEvents()
            let summaries = try await vault.fetchDailySummaries()
            let stats = try await vault.libraryStats()
            let digest = try await vault.latestDigest()

            libraryItems = items
            timelineEvents = events
            dailySummaries = summaries
            appStateUpdater(stats, digest, askResult)
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func saveNote() async {
        let body = noteBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.isEmpty == false else {
            statusMessage = L10n.text("先写一点想保存的内容吧。", "Write a little something before saving.")
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let tags = noteTags
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { $0.isEmpty == false }
            _ = try await vault.saveManualNote(
                title: noteTitle,
                body: body,
                tags: tags,
                retentionDays: settingsProvider().rawEventRetentionDays
            )
            noteTitle = ""
            noteBody = ""
            noteTags = ""
            statusMessage = L10n.text("已保存到本地资料库。", "Saved to your local library.")
            await refresh()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func ask() async {
        let question = askQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard question.isEmpty == false else {
            statusMessage = L10n.text("先给我一个关键词或问题。", "Give me a keyword or a question first.")
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await answerProvider.answer(question: question, scope: settingsProvider().defaultAskScope)
            askResult = result
            try await vault.recordEvent(
                MemoryEvent(
                    kind: .ask,
                    summary: L10n.format("问了一个本地问题：%@", "Asked a local question: %@", question),
                    metadata: [
                        "confidence": String(format: "%.2f", result.confidence),
                        "citationCount": "\(result.citations.count)",
                    ],
                    frontmostApp: nil
                ),
                retentionDays: settingsProvider().rawEventRetentionDays
            )
            await refresh()
            appStateUpdater(
                try await vault.libraryStats(),
                try await vault.latestDigest(),
                result
            )
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func primeAsk() {
        selectedTab = .ask
    }

    public func requestImport() {
        importHandler()
    }
}

public struct MemoryCenterView: View {
    @ObservedObject private var viewModel: MemoryCenterViewModel

    public init(viewModel: MemoryCenterViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        TabView(selection: $viewModel.selectedTab) {
            libraryTab
                .tabItem { Label(MemoryCenterTab.library.title, systemImage: MemoryCenterTab.library.systemImage) }
                .tag(MemoryCenterTab.library)

            timelineTab
                .tabItem { Label(MemoryCenterTab.timeline.title, systemImage: MemoryCenterTab.timeline.systemImage) }
                .tag(MemoryCenterTab.timeline)

            askTab
                .tabItem { Label(MemoryCenterTab.ask.title, systemImage: MemoryCenterTab.ask.systemImage) }
                .tag(MemoryCenterTab.ask)
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 620)
        .task {
            await viewModel.loadIfNeeded()
        }
        .overlay(alignment: .bottomLeading) {
            if let statusMessage = viewModel.statusMessage, statusMessage.isEmpty == false {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(.leading, 6)
                    .padding(.bottom, 6)
            }
        }
    }

    private var libraryTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField(L10n.text("搜索标题或正文", "Search titles or content"), text: $viewModel.libraryQuery)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await viewModel.refresh() }
                    }

                Button(L10n.text("刷新", "Refresh")) {
                    Task { await viewModel.refresh() }
                }

                Button(L10n.text("导入资料…", "Import Content…")) {
                    viewModel.requestImport()
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(L10n.text("手动笔记", "Manual Note"))
                    .font(.headline)

                TextField(L10n.text("标题", "Title"), text: $viewModel.noteTitle)
                    .textFieldStyle(.roundedBorder)

                TextEditor(text: $viewModel.noteBody)
                    .font(.body)
                    .frame(minHeight: 110)
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.secondary.opacity(0.15))
                    }

                HStack {
                    TextField(L10n.text("标签，多个用英文逗号分隔", "Tags, separated by commas"), text: $viewModel.noteTags)
                        .textFieldStyle(.roundedBorder)

                    Button(L10n.text("保存到资料库", "Save to Library")) {
                        Task { await viewModel.saveNote() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            List(viewModel.libraryItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.title)
                            .font(.headline)
                        Spacer()
                        Text(item.sourceKind.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(item.body)
                        .font(.body)
                        .lineLimit(4)

                    if item.tags.isEmpty == false {
                        Text(item.tags.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
    }

    private var timelineTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let summary = viewModel.dailySummaries.first {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("今天回顾", "Today"))
                        .font(.headline)
                    Text(summary.headline)
                        .font(.body)
                    if summary.highlights.isEmpty == false {
                        ForEach(summary.highlights, id: \.self) { highlight in
                            Text("• \(highlight)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            List {
                if viewModel.dailySummaries.isEmpty == false {
                    Section(L10n.text("每日摘要", "Daily Summaries")) {
                        ForEach(viewModel.dailySummaries, id: \.date) { summary in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(summary.headline)
                                    .font(.headline)
                                Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if summary.highlights.isEmpty == false {
                                    Text(summary.highlights.joined(separator: " / "))
                                        .font(.body)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section(L10n.text("事件流", "Event Stream")) {
                    ForEach(viewModel.timelineEvents) { event in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(event.kind.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(event.timestamp.formatted(date: .omitted, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }

                            Text(event.summary)
                                .font(.body)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var askTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                TextField(
                    L10n.text(
                        "问我：最近导入了什么、今天做了什么、某个关键词在哪些资料里出现过？",
                        "Ask me: what was imported recently, what happened today, or where a keyword appeared?"
                    ),
                    text: $viewModel.askQuestion
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    Task { await viewModel.ask() }
                }

                Button(L10n.text("问问我", "Ask")) {
                    Task { await viewModel.ask() }
                }
                .buttonStyle(.borderedProminent)
            }

            if let result = viewModel.askResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text("回答", "Answer"))
                                .font(.headline)
                            Text(result.answer)
                                .font(.body)
                            Text(
                                L10n.currentLanguage.isChinese
                                    ? "置信度 \(Int(result.confidence * 100))%"
                                    : "Confidence \(Int(result.confidence * 100))%"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.text("命中来源", "Sources"))
                                .font(.headline)

                            ForEach(Array(result.citations.enumerated()), id: \.offset) { index, citation in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(
                                        "\(index + 1). " +
                                        (citation.sourceKind == .knowledge
                                            ? L10n.text("资料库", "Library")
                                            : L10n.text("时间线", "Timeline"))
                                    )
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    Text(citation.excerpt)
                                        .font(.body)
                                    Text(citation.timestamp.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.text("离线抽取式问答", "Offline Extractive Q&A"))
                        .font(.headline)
                    Text(
                        L10n.text(
                            "我会只在本地资料库和时间线里检索，不会联网，也不会伪装成云端模型。",
                            "I only search your local library and timeline. I do not go online and I do not pretend to be a cloud model."
                        )
                    )
                    .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }

            Spacer(minLength: 0)
        }
    }
}
