import Foundation
import Combine

public struct GrowthUpdate: Sendable {
    public var previousStage: EvolutionStage
    public var currentStage: EvolutionStage
    public var gainedXP: Int

    public var evolved: Bool {
        previousStage != currentStage
    }
}

@MainActor
public final class GrowthTracker: ObservableObject {
    @Published public private(set) var state: GrowthState

    public init(initialState: GrowthState) {
        self.state = initialState
    }

    public func recordSample(snapshot: WorkSnapshot) -> GrowthUpdate? {
        guard snapshot.idleSeconds < 120 else { return nil }

        let previousStage = state.stage
        state.activeMinutes += 1
        state.xp += snapshot.isCodingApp ? 2 : 1
        state.stage = EvolutionStage.stage(for: state.xp)

        return GrowthUpdate(
            previousStage: previousStage,
            currentStage: state.stage,
            gainedXP: snapshot.isCodingApp ? 2 : 1
        )
    }

    public func recordConversation() -> GrowthUpdate {
        let previousStage = state.stage
        state.conversationCount += 1
        state.xp += 8
        state.stage = EvolutionStage.stage(for: state.xp)
        return GrowthUpdate(previousStage: previousStage, currentStage: state.stage, gainedXP: 8)
    }

    public func recordPetting() -> GrowthUpdate {
        let previousStage = state.stage
        state.petCount += 1
        state.xp += 2
        state.stage = EvolutionStage.stage(for: state.xp)
        return GrowthUpdate(previousStage: previousStage, currentStage: state.stage, gainedXP: 2)
    }

    public func markMorningGreetingIfNeeded(date: Date = .now) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        state.lastDailyGreetingKey = formatter.string(from: date)
    }

    public func exportState() -> GrowthState {
        state
    }
}
