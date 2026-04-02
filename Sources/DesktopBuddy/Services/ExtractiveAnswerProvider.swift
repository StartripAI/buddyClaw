import Foundation

public protocol AnswerProvider: Sendable {
    func answer(question: String, scope: AskScope) async throws -> AskResult
}

public struct ExtractiveAnswerProvider: AnswerProvider {
    private let vault: VaultStore

    public init(vault: VaultStore) {
        self.vault = vault
    }

    public func answer(question: String, scope: AskScope) async throws -> AskResult {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return AskResult(
                question: question,
                answer: L10n.text(
                    "你可以直接问我：今天记了什么、最近导入了什么资料，或者某个关键词出现在哪里。",
                    "You can ask me what was captured today, what you imported recently, or where a keyword appeared."
                ),
                citations: [],
                confidence: 0
            )
        }

        let hits = try await vault.search(query: trimmed, scope: scope, limit: 5)
        guard let best = hits.first, best.score >= 0.12 else {
            return AskResult(
                question: trimmed,
                answer: L10n.text(
                    "我在本地资料里还没找到足够依据。你可以先导入资料，或者换个关键词再问我一次。",
                    "I couldn't find enough support in your local data yet. Try importing content first or ask again with another keyword."
                ),
                citations: hits,
                confidence: hits.first?.score ?? 0
            )
        }

        let topHits = Array(hits.prefix(3))
        let answer: String
        if best.sourceKind == .knowledge {
            let lead = condensed(best.excerpt)
            let followUp = topHits.dropFirst().map { condensed($0.excerpt) }.filter { $0.isEmpty == false }
            if followUp.isEmpty {
                answer = L10n.currentLanguage.isChinese
                    ? "我在本地资料里找到一段最相关的内容：\(lead)"
                    : "The most relevant local passage I found is: \(lead)"
            } else {
                answer = L10n.currentLanguage.isChinese
                    ? "我先找到一段最相关的内容：\(lead)\n\n另外还看到：\(followUp.joined(separator: " / "))"
                    : "The most relevant local passage I found is: \(lead)\n\nI also found: \(followUp.joined(separator: " / "))"
            }
        } else {
            let lead = condensed(best.excerpt)
            answer = L10n.currentLanguage.isChinese
                ? "我在时间线记忆里翻到了一条很接近的问题线索：\(lead)"
                : "I found a closely related clue in your timeline memory: \(lead)"
        }

        return AskResult(
            question: trimmed,
            answer: answer,
            citations: topHits,
            confidence: min(0.96, best.score + Double(topHits.count - 1) * 0.05)
        )
    }

    private func condensed(_ text: String) -> String {
        let singleLine = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if singleLine.count <= 140 {
            return singleLine
        }
        let end = singleLine.index(singleLine.startIndex, offsetBy: 140)
        return "\(singleLine[..<end])..."
    }
}
