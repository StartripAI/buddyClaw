import SwiftUI

private struct BubbleTailShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 2, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + 6, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

public struct SpeechBubbleView: View {
    private let text: String
    private let accentColor: Color
    private let fadeProgress: Double

    public init(text: String, accentColor: Color, fadeProgress: Double) {
        self.text = text
        self.accentColor = accentColor
        self.fadeProgress = fadeProgress
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: -1) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(accentColor.opacity(0.85), lineWidth: 1)
                        )
                )
                .frame(maxWidth: 240, alignment: .leading)

            BubbleTailShape()
                .fill(.regularMaterial)
                .frame(width: 18, height: 12)
                .overlay(
                    BubbleTailShape()
                        .stroke(accentColor.opacity(0.85), lineWidth: 1)
                )
                .padding(.trailing, 20)
        }
        .opacity(1.0 - fadeProgress * 0.65)
        .scaleEffect(1.0 - fadeProgress * 0.05, anchor: .topTrailing)
        .animation(.easeInOut(duration: 0.18), value: fadeProgress)
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
