import Foundation

public enum AnimationState: String, CaseIterable, Codable, Sendable {
    case idle
    case walkLeft
    case walkRight
    case sit
    case sleep
    case jump
    case pet
    case talk
    case evolve
    case blink

    public var defaultFPS: Double {
        switch self {
        case .idle: return 2
        case .walkLeft, .walkRight: return 6
        case .sit: return 1
        case .sleep: return 2
        case .jump: return 8
        case .pet: return 6
        case .talk: return 7
        case .evolve: return 10
        case .blink: return 12
        }
    }

    public var loops: Bool {
        switch self {
        case .jump, .evolve, .blink:
            return false
        case .idle, .walkLeft, .walkRight, .sit, .sleep, .pet, .talk:
            return true
        }
    }

    public func canTransition(to next: AnimationState) -> Bool {
        switch (self, next) {
        case (.evolve, .sleep):
            return false
        default:
            return true
        }
    }
}
