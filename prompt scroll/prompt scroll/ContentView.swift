//
//  ContentView.swift
//  prompt scroll
//
//  Created by Michael Lee on 5/28/26.
//

import SwiftUI
import UIKit

struct ChatExchange: Identifiable, Hashable {
    let id = UUID()
    let prompt: String
    let response: String

    static let samples: [ChatExchange] = [
        ChatExchange(
            prompt: "How would you explain when to use NavigationStack instead of a custom coordinator in SwiftUI?",
            response: "Use NavigationStack when your navigation state maps cleanly to data and can be expressed with a path or simple destination bindings. Reach for a coordinator only when you need orchestration across flows, UIKit interop, or cross-feature routing that would otherwise leak through many views. In practice, the simpler your destinations are, the more value you get from staying with native SwiftUI navigation."
        ),
        ChatExchange(
            prompt: "What is the cleanest way to wrap a UIKit camera controller inside SwiftUI?",
            response: "A UIViewControllerRepresentable is usually the cleanest boundary because it keeps the UIKit lifecycle isolated. Let the representable own setup, forward delegate events through a coordinator, and push only the small set of SwiftUI-facing bindings you actually need. That keeps the SwiftUI side declarative while UIKit still handles the controller-specific details."
        ),
        ChatExchange(
            prompt: "My SwiftUI list jumps when I append new messages. Where would you start debugging that?",
            response: "I would first verify identity stability, because list diffing gets unreliable if ids are regenerated during updates. After that, check whether scroll commands, animations, or conditional rows are running in the same transaction as the insert. Most jumpy chat lists come down to either unstable ids or too many layout changes happening at once."
        ),
        ChatExchange(
            prompt: "If I already have a UIKit tab bar app, is UIHostingController still the right bridge for new SwiftUI screens?",
            response: "Yes, that is still the pragmatic bridge in most mixed apps. Keep UIKit in charge of top-level containers, embed SwiftUI with UIHostingController, and move shared state into observable objects or lightweight adapters rather than letting either side reach too far into the other. That gives you a gradual migration path instead of forcing a full navigation rewrite up front."
        ),
        ChatExchange(
            prompt: "What usually causes SwiftUI views to redraw more than expected?",
            response: "Broad state ownership is the most common culprit. If a parent observes too much mutable state, small updates fan out into large body recomputations, so narrowing the state surface and separating derived presentation data often helps more than micro-optimizing individual views. It is usually a data flow problem before it is a rendering problem."
        ),
        ChatExchange(
            prompt: "How would you add pull to refresh to a UIKit collection view and keep the API friendly for SwiftUI later?",
            response: "Wrap UIRefreshControl behind a tiny controller-facing abstraction instead of hard-coding the refresh logic into the view controller. That gives you a reusable async entry point now and a shape that can later map naturally to SwiftUI refresh actions. The goal is to make the refresh behavior portable even if the view technology changes."
        ),
        ChatExchange(
            prompt: "How do I decide whether an animation belongs in SwiftUI or UIKit?",
            response: "If the animation is driven by view state and lives comfortably inside layout changes, SwiftUI is usually the better fit. If it depends on imperative timing, gesture choreography, or tight control over layers, UIKit or Core Animation will be easier to reason about. The more timeline control you need, the less pleasant SwiftUI animation usually becomes."
        ),
        ChatExchange(
            prompt: "What is your preferred approach for keyboard avoidance in a chat screen built with SwiftUI?",
            response: "I prefer observing the keyboard frame once and translating that into a focused bottom inset rather than stacking multiple safe-area hacks. Combined with ScrollViewReader, it gives you predictable composer movement without fighting every system update. A single source of truth for the inset tends to keep the whole chat layout calmer."
        ),
        ChatExchange(
            prompt: "Why does a UIKit-backed text view still feel easier than TextEditor for some rich input cases?",
            response: "UITextView still exposes more mature control over selection, attributed content, link handling, and input accessory behavior. TextEditor is improving, but once you need fine-grained editing behavior, the UIKit surface area is still materially stronger. That is why many production chat composers still keep a UIKit text view under the hood."
        ),
        ChatExchange(
            prompt: "If I wanted a shared design language across SwiftUI and UIKit, what would you standardize first?",
            response: "Start with tokens, not components. Color roles, spacing, corner radii, typography scales, and elevation rules travel across both frameworks much more reliably than trying to force the same view implementation everywhere. Once the tokens are stable, the framework-specific components become much easier to keep visually aligned."
        ),
        ChatExchange(
            prompt: "How would you keep a SwiftUI chat screen responsive while streaming tokens into the latest message?",
            response: "Keep the streaming buffer narrow and avoid making the entire conversation observe every token. Let the active message update from a small piece of state, coalesce rapid text changes when possible, and reserve broader model updates for message boundaries. That keeps the newest response lively without forcing the full thread to re-render constantly."
        ),
        ChatExchange(
            prompt: "What is the safest way to measure row positions for a custom scrubber in SwiftUI?",
            response: "Prefer stable data mapping first, because live geometry preferences can become fragile in previews and during heavy layout churn. If you need exact row positions, isolate the measurement behind a small preference key and avoid feeding it back into layout every frame. The important part is preventing measurement from becoming a second scrolling system."
        ),
        ChatExchange(
            prompt: "How would you design a long-press interaction so it does not steal normal scroll gestures?",
            response: "Use a longer press duration with a small movement threshold, so ordinary vertical drags fail the press before the alternate mode activates. Once the mode is active, keep the drag behavior intentionally narrow and make the visual transition obvious. The gesture should feel like a deliberate hold, not an accidental scroll interruption."
        ),
        ChatExchange(
            prompt: "When should a chat app jump to a message immediately versus waiting until the user releases a scrub gesture?",
            response: "Jump immediately when the user is directly dragging a scrollbar or index control whose job is navigation. Wait until release when the gesture is exploratory and the user is comparing targets. For a prompt scrubber, live selection feedback plus deferred navigation usually feels calmer because the underlying conversation is not constantly moving."
        ),
        ChatExchange(
            prompt: "How can I make a compact overview mode without making the UI feel like a different screen?",
            response: "Animate the existing content into a denser version instead of swapping to a separate panel. Hide secondary detail, reduce spacing, and keep anchors such as bubble shape and left alignment recognizable. The user should feel that the thread compressed under their finger, not that they were sent somewhere else."
        ),
        ChatExchange(
            prompt: "What should I watch for when mixing context menus with custom long-press gestures?",
            response: "Both features want ownership of a press, so the timing and target area matter. Keep context menus tied to specific controls and use the custom long press at the broader container level with a clear movement threshold. If they conflict, the more intentional gesture should require a more deliberate hold."
        ),
        ChatExchange(
            prompt: "Why do small SwiftUI previews sometimes crash after adding geometry preferences?",
            response: "Previews use dynamic replacement and can be less forgiving when view identity, preference types, or state feedback loops change rapidly. Geometry preferences are useful, but they can trigger repeated layout updates if the measured value changes the layout that created it. Simplifying measurement or moving it out of the hot path usually stabilizes previews."
        ),
        ChatExchange(
            prompt: "How should I choose haptic feedback for a scrub interaction?",
            response: "Use a light impact when entering the mode and only tick again when the selected item actually changes. Avoid haptics on every drag update because that turns useful feedback into noise. The haptic rhythm should match semantic steps, not raw finger movement."
        ),
        ChatExchange(
            prompt: "How would you keep prompt bubbles readable when they shrink for an overview mode?",
            response: "Shrink in layers: reduce response detail first, then spacing, then type size only as much as needed. Keep contrast, padding, and corner radius proportional so the bubbles still feel like the same component. If the text gets too small, show fewer words or widen the bubble before cutting legibility."
        ),
        ChatExchange(
            prompt: "What is the cleanest way to keep a composer out of the way during a temporary navigation mode?",
            response: "Treat the composer as part of the normal chat state and animate its inset away with the mode transition. Fading alone is not enough because the reserved space still affects the content. Collapsing the inset, offsetting the bar, and disabling hit testing makes the temporary mode feel intentional."
        ),
        ChatExchange(
            prompt: "How would you make selected and unselected rows feel different without adding labels?",
            response: "Use scale, weight, opacity, or a nearby marker rather than extra text. The selected row can breathe a little larger while nearby rows recede slightly, which preserves scanability. In a scrubber, the difference should be visible peripherally because the user is focused on finger position."
        ),
        ChatExchange(
            prompt: "When should I use scrollTo in SwiftUI instead of binding scroll position directly?",
            response: "Use scrollTo for discrete jumps to known items, especially in older deployment targets or simple ScrollViewReader flows. A bound scroll position is better when scroll state itself is a first-class part of the UI. For a release-to-navigate scrubber, scrollTo is still a clean fit because the action resolves to one final item."
        ),
        ChatExchange(
            prompt: "What makes a custom gesture feel native instead of decorative?",
            response: "Native-feeling gestures have clear entry, continuous feedback, and a predictable commit or cancel moment. The visuals should explain what the finger is doing without extra labels. If the underlying content obeys the same physical rules every time, the gesture starts to feel like part of the system."
        ),
        ChatExchange(
            prompt: "How would you debug a SwiftUI interaction that works in the app but feels wrong in Preview?",
            response: "Separate source correctness from Preview behavior. First remove fragile preview-only triggers such as fast state feedback, geometry loops, or conflicting gestures, then reintroduce pieces one at a time. Preview is excellent for iteration."
        ),
        ChatExchange(
            prompt: "What is a good way to make an AI chat prototype feel more inspectable without adding another panel?",
            response: "Let the existing conversation transform in place. A hold, pinch, or scrub can compress messages into prompts, assumptions, actions, or decisions while keeping the original spatial context. That makes the AI work feel tied to the conversation instead of hidden behind a separate inspector."
        )
    ]
}

struct ContentView: View {
    private let exchanges = ChatExchange.samples
    private let userBubbleColor = Color(red: 0.92, green: 0.92, blue: 0.94)
    private let composerHeight: CGFloat = 50
    private let threadScrubActivationDuration: TimeInterval = 0.55
    private let threadScrubActivationMovement: CGFloat = 8
    private let threadScrubVerticalPadding: CGFloat = 92
    private let threadScrubDismissDuration: TimeInterval = 0.22
    private let threadScrubLayoutAnimation = Animation.easeInOut(duration: 0.3)

    @State private var isThreadScrubbing = false
    @State private var threadScrubProgress: CGFloat = 0
    @State private var activeThreadIndex = 0
    @State private var lastScrubbedThreadIndex = 0
    @State private var selectedThreadID: ChatExchange.ID?
    @State private var inputText = ""
    @State private var didSetInitialScrollPosition = false
    @State private var exchangeFrames: [UUID: CGRect] = [:]
    @State private var threadScrubStartY: CGFloat?
    @State private var threadScrubStartIndex: Int?

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resolvedComposerHeight: CGFloat {
        composerHeight
    }

    private var composerVisibility: CGFloat {
        resolvedValue(1, 0, progress: threadScrubProgress)
    }

    private var resolvedComposerInsetHeight: CGFloat {
        resolvedValue(72, 0, progress: threadScrubProgress)
    }

    private var scrubTransitionProgress: CGFloat {
        smoothStep(threadScrubProgress)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ZStack {
                        Color.white
                            .ignoresSafeArea()

                        conversationScrollView
                            .opacity(Double(1 - scrubTransitionProgress))
                            .safeAreaInset(edge: .bottom) {
                                composerBar
                            }
                            .onAppear {
                                scrollToLatestExchange(proxy: proxy)
                            }

                        promptScrubOverlay

                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .coordinateSpace(name: "threadScrubArea")
                    .background {
                        LongPressScrubGestureInstaller(
                            minimumPressDuration: threadScrubActivationDuration,
                            allowableMovement: threadScrubActivationMovement,
                            onBegan: { yLocation in
                                presentThreadScrubber(at: yLocation, proxy: proxy)
                            },
                            onChanged: { yLocation in
                                scrubToThread(
                                    at: yLocation,
                                    containerHeight: geometry.size.height,
                                    proxy: proxy,
                                    shouldScroll: false
                                )
                            },
                            onEnded: { yLocation in
                                scrubToThread(
                                    at: yLocation,
                                    containerHeight: geometry.size.height,
                                    proxy: proxy,
                                    shouldScroll: true
                                )
                                dismissThreadScrubber()
                            },
                            onCancelled: {
                                dismissThreadScrubber()
                            }
                        )
                    }
                }
            }
        }
        .environment(\.colorScheme, .light)
    }

    private var conversationScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(exchanges) { exchange in
                    ExchangeRow(
                        exchange: exchange,
                        userBubbleColor: userBubbleColor,
                        onCopy: {
                            UIPasteboard.general.string = exchange.prompt
                        }
                    )
                    .id(exchange.id)
                    .background {
                        GeometryReader { rowGeometry in
                            Color.clear.preference(
                                key: ExchangeFramePreferenceKey.self,
                                value: [
                                    exchange.id: rowGeometry.frame(in: .global)
                                ]
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .scrollDisabled(isThreadScrubbing)
        .contentShape(Rectangle())
        .accessibilityIdentifier(AccessibilityIdentifier.conversationScrollView)
        .onPreferenceChange(ExchangeFramePreferenceKey.self) { frames in
            exchangeFrames = frames
        }
        .animation(threadScrubLayoutAnimation, value: threadScrubProgress)
    }

    private var promptScrubOverlay: some View {
        ScrollViewReader { scrubProxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(exchanges) { exchange in
                        let isSelected = selectedThreadID == exchange.id

                        PromptScrubRow(
                            prompt: exchange.prompt,
                            color: userBubbleColor,
                            isSelected: isSelected
                        )
                        .id(exchange.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .allowsHitTesting(false)
            .opacity(Double(scrubTransitionProgress))
            .scaleEffect(resolvedValue(0.99, 1, progress: scrubTransitionProgress), anchor: .topLeading)
            .offset(y: resolvedValue(8, 0, progress: scrubTransitionProgress))
            .onChange(of: selectedThreadID) { _, selectedThreadID in
                guard isThreadScrubbing, let selectedThreadID else { return }

                withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9)) {
                    scrubProxy.scrollTo(selectedThreadID, anchor: .center)
                }
            }
            .onAppear {
                guard let selectedThreadID else { return }

                DispatchQueue.main.async {
                    scrubProxy.scrollTo(selectedThreadID, anchor: .center)
                }
            }
        }
    }

    private func presentThreadScrubber(at yLocation: CGFloat, proxy: ScrollViewProxy) {
        let initialIndex = indexForVisibleExchange(at: yLocation) ?? activeThreadIndex

        if !isThreadScrubbing {
            isThreadScrubbing = true
            threadScrubProgress = 0
            threadScrubStartY = yLocation
            threadScrubStartIndex = initialIndex
            lastScrubbedThreadIndex = initialIndex
            selectThread(at: initialIndex, proxy: proxy, shouldScroll: false)
            playThreadScrubFeedback(intensity: 0.48)
        }

        withAnimation(threadScrubLayoutAnimation) {
            threadScrubProgress = 1
        }
    }

    private func scrollToLatestExchange(proxy: ScrollViewProxy) {
        guard !didSetInitialScrollPosition, let lastIndex = exchanges.indices.last else { return }

        didSetInitialScrollPosition = true
        activeThreadIndex = lastIndex
        lastScrubbedThreadIndex = lastIndex

        DispatchQueue.main.async {
            proxy.scrollTo(exchanges[lastIndex].id, anchor: .bottom)
        }
    }

    private func scrubToThread(at yLocation: CGFloat, containerHeight: CGFloat, proxy: ScrollViewProxy, shouldScroll: Bool) {
        guard exchanges.count > 1 else {
            selectThread(at: 0, proxy: proxy, shouldScroll: shouldScroll)
            return
        }

        let index: Int
        let top = threadScrubVerticalPadding
        let bottom = max(top + 1, containerHeight - threadScrubVerticalPadding)

        if let threadScrubStartY, let threadScrubStartIndex {
            let stepHeight = max(1, (bottom - top) / CGFloat(exchanges.count - 1))
            let deltaIndex = Int(((yLocation - threadScrubStartY) / stepHeight).rounded())
            index = min(max(threadScrubStartIndex + deltaIndex, 0), exchanges.count - 1)
        } else {
            let clampedY = min(max(yLocation, top), bottom)
            let fraction = (clampedY - top) / max(1, bottom - top)
            index = Int((fraction * CGFloat(exchanges.count - 1)).rounded())
        }

        selectThread(at: index, proxy: proxy, shouldScroll: shouldScroll)
    }

    private func indexForVisibleExchange(at yLocation: CGFloat) -> Int? {
        let indexedFrames = exchanges.enumerated().compactMap { index, exchange in
            exchangeFrames[exchange.id].map { frame in
                (index: index, frame: frame)
            }
        }

        guard !indexedFrames.isEmpty else { return nil }

        if let containingFrame = indexedFrames.first(where: { $0.frame.minY <= yLocation && yLocation <= $0.frame.maxY }) {
            return containingFrame.index
        }

        return indexedFrames.min { lhs, rhs in
            abs(lhs.frame.midY - yLocation) < abs(rhs.frame.midY - yLocation)
        }?.index
    }

    private func selectThread(at index: Int, proxy: ScrollViewProxy, shouldScroll: Bool = true) {
        guard exchanges.indices.contains(index) else { return }

        activeThreadIndex = index
        selectedThreadID = exchanges[index].id

        guard shouldScroll, lastScrubbedThreadIndex != index else { return }
        lastScrubbedThreadIndex = index
        playThreadScrubFeedback(intensity: 0.36)

        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.88)) {
            proxy.scrollTo(exchanges[index].id, anchor: .top)
        }
    }

    private func dismissThreadScrubber() {
        withAnimation(.easeOut(duration: threadScrubDismissDuration)) {
            threadScrubProgress = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + threadScrubDismissDuration) {
            guard threadScrubProgress <= 0.001 else { return }
            selectedThreadID = nil
            isThreadScrubbing = false
            threadScrubStartY = nil
            threadScrubStartIndex = nil
        }
    }

    private func playThreadScrubFeedback(intensity: CGFloat) {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred(intensity: intensity)
    }

    private var composerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: resolvedComposerHeight, height: resolvedComposerHeight)
                .background(Circle().fill(Color.white))
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.22), lineWidth: 1)
                )

            HStack {
                TextField("Ask here", text: $inputText)
                    .font(.system(size: 15))
                    .textFieldStyle(.plain)

                Spacer()

                Button {
                    inputText = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(canSend ? userBubbleColor : Color.gray.opacity(0.45))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .frame(height: resolvedComposerHeight)
            .background(
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 100, style: .continuous)
                    .stroke(Color.gray.opacity(0.22), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .background(.ultraThinMaterial)
        .opacity(Double(composerVisibility))
        .offset(y: resolvedValue(0, 78, progress: threadScrubProgress))
        .allowsHitTesting(composerVisibility > 0.5)
        .frame(height: resolvedComposerInsetHeight, alignment: .top)
    }
}

private struct LongPressScrubGestureInstaller: UIViewRepresentable {
    let minimumPressDuration: TimeInterval
    let allowableMovement: CGFloat
    let onBegan: (CGFloat) -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void
    let onCancelled: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            minimumPressDuration: minimumPressDuration,
            allowableMovement: allowableMovement,
            onBegan: onBegan,
            onChanged: onChanged,
            onEnded: onEnded,
            onCancelled: onCancelled
        )
    }

    func makeUIView(context: Context) -> InstallerView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: InstallerView, context: Context) {
        context.coordinator.minimumPressDuration = minimumPressDuration
        context.coordinator.allowableMovement = allowableMovement
        context.coordinator.onBegan = onBegan
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        context.coordinator.onCancelled = onCancelled
        uiView.coordinator = context.coordinator
        uiView.installIfNeeded()
    }

    final class InstallerView: UIView {
        weak var coordinator: Coordinator?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            installIfNeeded()
        }

        func installIfNeeded() {
            coordinator?.install(on: window)
        }

        deinit {
            coordinator?.uninstall()
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var minimumPressDuration: TimeInterval
        var allowableMovement: CGFloat
        var onBegan: (CGFloat) -> Void
        var onChanged: (CGFloat) -> Void
        var onEnded: (CGFloat) -> Void
        var onCancelled: () -> Void

        private weak var installedView: UIView?
        private weak var recognizer: UILongPressGestureRecognizer?

        init(
            minimumPressDuration: TimeInterval,
            allowableMovement: CGFloat,
            onBegan: @escaping (CGFloat) -> Void,
            onChanged: @escaping (CGFloat) -> Void,
            onEnded: @escaping (CGFloat) -> Void,
            onCancelled: @escaping () -> Void
        ) {
            self.minimumPressDuration = minimumPressDuration
            self.allowableMovement = allowableMovement
            self.onBegan = onBegan
            self.onChanged = onChanged
            self.onEnded = onEnded
            self.onCancelled = onCancelled
        }

        func install(on view: UIView?) {
            guard let view else { return }

            if installedView === view {
                recognizer?.minimumPressDuration = minimumPressDuration
                recognizer?.allowableMovement = allowableMovement
                return
            }

            uninstall()

            let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            recognizer.minimumPressDuration = minimumPressDuration
            recognizer.allowableMovement = allowableMovement
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self

            view.addGestureRecognizer(recognizer)
            self.installedView = view
            self.recognizer = recognizer
        }

        func uninstall() {
            if let recognizer, let installedView {
                installedView.removeGestureRecognizer(recognizer)
            }

            self.recognizer = nil
            self.installedView = nil
        }

        @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            let yLocation = recognizer.location(in: recognizer.view).y

            switch recognizer.state {
            case .began:
                onBegan(yLocation)
            case .changed:
                onChanged(yLocation)
            case .ended:
                onEnded(yLocation)
            case .cancelled, .failed:
                onCancelled()
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private func resolvedValue(_ normal: CGFloat, _ compact: CGFloat, progress: CGFloat) -> CGFloat {
    let clampedProgress = min(max(progress, 0), 1)
    return normal + ((compact - normal) * clampedProgress)
}

private func smoothStep(_ progress: CGFloat) -> CGFloat {
    let clampedProgress = min(max(progress, 0), 1)
    return clampedProgress * clampedProgress * (3 - (2 * clampedProgress))
}

private enum AccessibilityIdentifier {
    static let conversationScrollView = "conversation-scroll-view"
}

private struct ExchangeFramePreferenceKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

private struct ExchangeRow: View {
    let exchange: ChatExchange
    let userBubbleColor: Color
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer(minLength: 52)

                PromptBubble(prompt: exchange.prompt, color: userBubbleColor)
                    .contentShape(
                        RoundedRectangle(
                            cornerRadius: 24,
                            style: .continuous
                        )
                    )
                    .contextMenu {
                        Button {
                            onCopy()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
            }

            ResponseTextView(response: exchange.response)
        }
    }
}

private struct PromptScrubRow: View {
    let prompt: String
    let color: Color
    let isSelected: Bool

    private var bubbleScale: CGFloat {
        isSelected ? 1.04 : 0.9
    }

    var body: some View {
        HStack {
            PromptThreadTick(isSelected: isSelected, progress: 1)

            Spacer(minLength: 8)

            PromptBubble(
                prompt: prompt,
                color: color,
                maxWidth: 330,
                horizontalPadding: 14,
                verticalPadding: 8,
                cornerRadius: 14
            )
            .scaleEffect(bubbleScale, anchor: .leading)
            .opacity(isSelected ? 1 : 0.72)
            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.86), value: isSelected)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PromptThreadTick: View {
    let isSelected: Bool
    let progress: CGFloat

    var body: some View {
        Capsule()
            .fill(isSelected ? Color.black : Color.black.opacity(0.28))
            .frame(
                width: isSelected ? 36 : 18,
                height: isSelected ? 3 : 1.5
            )
            .frame(width: resolvedValue(0, 42, progress: progress), height: 18, alignment: .leading)
            .opacity(Double(progress))
            .offset(x: resolvedValue(-40, 0, progress: progress))
            .clipped()
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .accessibilityHidden(true)
    }
}

private struct ResponseTextView: View {
    let response: String

    var body: some View {
        Text(response)
            .font(.system(size: 17))
            .foregroundStyle(.primary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.leading, 6)
    }
}

private struct PromptBubble: View {
    let prompt: String
    let color: Color
    var maxWidth: CGFloat = 312
    var horizontalPadding: CGFloat = 18
    var verticalPadding: CGFloat = 14
    var width: CGFloat?
    var height: CGFloat?
    var cornerRadius: CGFloat = 24

    var body: some View {
        Text(prompt)
            .font(.system(size: 16))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: width == nil ? maxWidth : nil, alignment: .leading)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                )
                    .fill(color)
            )
            .clipped()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
