import Foundation
import SwiftUI

public struct HeartSprite: Identifiable, Sendable {
    public let id: UUID
    public let symbol: String
    public let xOffset: CGFloat
    public let yOffset: CGFloat
    public let opacity: Double
    public let scale: Double

    public init(
        id: UUID = UUID(),
        symbol: String,
        xOffset: CGFloat,
        yOffset: CGFloat,
        opacity: Double,
        scale: Double
    ) {
        self.id = id
        self.symbol = symbol
        self.xOffset = xOffset
        self.yOffset = yOffset
        self.opacity = opacity
        self.scale = scale
    }
}

@MainActor
public final class HeartBurstEffect: ObservableObject {
    @Published public private(set) var hearts: [HeartSprite] = []

    private var timer: Timer?
    private let lifetime: TimeInterval = 2.5
    private let heartRows: [[CGFloat]] = [
        [-18, 18],
        [-28, 0, 28],
        [-36, -8, 20],
        [-18, 18],
        [0],
    ]

    public init() {}

    public func emitBurst() {
        stop()
        var snapshots: [HeartSprite] = []
        let symbols = ["♥", "♥", "♥", "♥", "·"]
        for (rowIndex, row) in heartRows.enumerated() {
            let progress = Double(rowIndex) / Double(max(1, heartRows.count - 1))
            for (index, x) in row.enumerated() {
                let symbol = symbols[min(index, symbols.count - 1)]
                snapshots.append(
                    HeartSprite(
                        symbol: symbol,
                        xOffset: x,
                        yOffset: CGFloat(-progress * 64),
                        opacity: max(0.25, 1.0 - progress),
                        scale: 0.9 + (0.1 * progress)
                    )
                )
            }
        }
        hearts = snapshots

        let start = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] timer in
            Task { @MainActor [weak self] in
                guard let self else {
                    timer.invalidate()
                    return
                }
                let elapsed = Date().timeIntervalSince(start)
                let progress = min(1.0, elapsed / self.lifetime)

                self.hearts = snapshots.map { heart in
                    HeartSprite(
                        id: heart.id,
                        symbol: heart.symbol,
                        xOffset: heart.xOffset,
                        yOffset: heart.yOffset - CGFloat(progress * 36),
                        opacity: max(0, heart.opacity * (1.0 - progress)),
                        scale: heart.scale + (progress * 0.25)
                    )
                }

                if progress >= 1.0 {
                    timer.invalidate()
                    self.hearts = []
                }
            }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        hearts = []
    }
}
