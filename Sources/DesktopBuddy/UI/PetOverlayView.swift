import AppKit
import SwiftUI

public struct PetOverlayView: View {
    @ObservedObject private var animator: SpriteAnimator
    @ObservedObject private var bubbleManager: SpeechBubbleManager
    @ObservedObject private var heartBurstEffect: HeartBurstEffect

    private let onPet: () -> Void
    private let onTalk: () -> Void

    public init(
        animator: SpriteAnimator,
        bubbleManager: SpeechBubbleManager,
        onPet: @escaping () -> Void,
        onTalk: @escaping () -> Void
    ) {
        self.animator = animator
        self.bubbleManager = bubbleManager
        self.heartBurstEffect = animator.heartBurstEffect
        self.onPet = onPet
        self.onTalk = onTalk
    }

    public var body: some View {
        VStack(spacing: 6) {
            if let bubble = bubbleManager.currentBubble, bubble.text.isEmpty == false {
                SpeechBubbleView(
                    text: bubble.text,
                    accentColor: Color(nsColor: animator.companion.rarity.color),
                    fadeProgress: bubbleManager.fadeProgress
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ZStack {
                ForEach(heartBurstEffect.hearts) { heart in
                    Text(heart.symbol)
                        .font(.system(size: CGFloat(14 * heart.scale), weight: .bold))
                        .foregroundStyle(Color(nsColor: animator.companion.rarity.color))
                        .offset(x: heart.xOffset, y: heart.yOffset)
                        .opacity(heart.opacity)
                }

                Image(nsImage: animator.currentFrameImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: animator.preferredCanvasSize.width, height: animator.preferredCanvasSize.height)
            }
            .frame(width: animator.preferredCanvasSize.width, height: animator.preferredCanvasSize.height)
            .contentShape(Rectangle())
            .highPriorityGesture(
                TapGesture(count: 2)
                    .onEnded { onTalk() }
            )
            .onTapGesture {
                onPet()
            }

            Text("\(animator.companion.name) · \(animator.companion.rarity.stars)")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule(style: .continuous))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(Color.clear)
        .frame(width: 260, height: 260, alignment: .bottom)
    }
}
