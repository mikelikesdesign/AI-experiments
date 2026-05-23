//
//  ContentView.swift
//  pinch prompts
//
//  Created by Michael Lee on 4/17/26.
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
            prompt: "Is there a good rule for deciding whether an animation belongs in SwiftUI or UIKit?",
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
        )
    ]
}

struct ContentView: View {
    private let exchanges = ChatExchange.samples
    private let userBubbleColor = Color(red: 0.92, green: 0.92, blue: 0.94)
    private let composerHeight: CGFloat = 50
    private let promptNavigatorPinchThreshold: CGFloat = 0.9
    private let promptNavigatorPresentAnimation = Animation.easeInOut(duration: 0.2)
    private let promptNavigatorDismissAnimation = Animation.easeInOut(duration: 0.14)
    private let promptNavigatorDismissDuration: TimeInterval = 0.14

    @State private var isPromptNavigatorPresented = false
    @State private var promptNavigatorVisibility: CGFloat = 0
    @State private var promptNavigatorPresentationSource: PromptNavigatorPresentationSource = .action
    @State private var selectedPromptID: ChatExchange.ID?
    @State private var inputText = ""
    @State private var hasTriggeredPromptNavigatorPinch = false

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ZStack {
                        Color.white
                            .ignoresSafeArea()

                        conversationScrollView(proxy: proxy, containerSize: geometry.size)
                            .safeAreaInset(edge: .bottom) {
                                composerBar
                            }
                            .blur(radius: 12 * promptNavigatorVisibility)

                        if isPromptNavigatorPresented {
                            Color.black
                                .opacity(0.18 * promptNavigatorVisibility)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        }

                        promptNavigatorOverlay(proxy: proxy)
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
        }
        .environment(\.colorScheme, .light)
    }

    @ViewBuilder
    private func conversationScrollView(proxy: ScrollViewProxy, containerSize: CGSize) -> some View {
        let scrollView = ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                ForEach(exchanges) { exchange in
                    ExchangeRow(
                        exchange: exchange,
                        userBubbleColor: userBubbleColor,
                        onCopy: {
                            UIPasteboard.general.string = exchange.prompt
                        },
                        onViewPrompts: {
                            presentPromptNavigator(selectedPromptID: exchange.id, source: .action)
                        }
                    )
                    .id(exchange.id)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .contentShape(Rectangle())
        .accessibilityIdentifier(AccessibilityIdentifier.conversationScrollView)

        if isPromptNavigatorPresented {
            scrollView
        } else {
            scrollView
                .simultaneousGesture(promptNavigatorPinchGesture)
        }
    }

    private var promptNavigatorPinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard !isPromptNavigatorPresented else { return }
                guard !hasTriggeredPromptNavigatorPinch else { return }
                guard value.magnification <= promptNavigatorPinchThreshold else { return }

                hasTriggeredPromptNavigatorPinch = true
                presentPromptNavigator(selectedPromptID: nil, source: .pinch)
            }
            .onEnded { _ in
                guard !isPromptNavigatorPresented else { return }
                hasTriggeredPromptNavigatorPinch = false
            }
    }

    @ViewBuilder
    private func promptNavigatorOverlay(proxy: ScrollViewProxy) -> some View {
        if isPromptNavigatorPresented {
            PromptNavigatorOverlay(
                exchanges: exchanges,
                userBubbleColor: userBubbleColor,
                presentationSource: promptNavigatorPresentationSource,
                selectedPromptID: selectedPromptID,
                onSelect: { exchange in
                    selectedPromptID = exchange.id
                    dismissPromptNavigator()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        withAnimation(.easeInOut(duration: 0.28)) {
                            proxy.scrollTo(exchange.id, anchor: .top)
                        }
                    }
                },
                onClose: dismissPromptNavigator
            )
            .opacity(promptNavigatorVisibility)
            .offset(
                y: promptNavigatorPresentationSource == .pinch
                    ? (14 * (1 - promptNavigatorVisibility))
                    : 0
            )
            .allowsHitTesting(promptNavigatorVisibility > 0.01)
        }
    }

    private func presentPromptNavigator(selectedPromptID: ChatExchange.ID?, source: PromptNavigatorPresentationSource) {
        self.selectedPromptID = selectedPromptID
        promptNavigatorPresentationSource = source

        if !isPromptNavigatorPresented {
            promptNavigatorVisibility = 0
            isPromptNavigatorPresented = true
        }

        withAnimation(promptNavigatorPresentAnimation) {
            promptNavigatorVisibility = 1
        }
    }

    private func dismissPromptNavigator() {
        hasTriggeredPromptNavigatorPinch = false

        withAnimation(promptNavigatorDismissAnimation) {
            promptNavigatorVisibility = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + promptNavigatorDismissDuration) {
            guard promptNavigatorVisibility <= 0.001 else { return }
            selectedPromptID = nil
            isPromptNavigatorPresented = false
            promptNavigatorPresentationSource = .action
        }
    }

    private var composerBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: composerHeight, height: composerHeight)
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
            .frame(height: composerHeight)
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
    }
}

private enum AccessibilityIdentifier {
    static let conversationScrollView = "conversation-scroll-view"
    static let promptNavigator = "prompt-navigator"
    static let promptNavigatorCloseButton = "prompt-navigator-close-button"
}

private enum PromptNavigatorPresentationSource {
    case action
    case pinch
}

private struct ExchangeRow: View {
    let exchange: ChatExchange
    let userBubbleColor: Color
    let onCopy: () -> Void
    let onViewPrompts: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Spacer(minLength: 52)

                PromptBubble(prompt: exchange.prompt, color: userBubbleColor)
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .contextMenu {
                        Button {
                            onCopy()
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }

                        Button {
                            onViewPrompts()
                        } label: {
                            Label("View Prompts", systemImage: "list.bullet")
                        }
                    }
            }

            ResponseTextView(response: exchange.response)
        }
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
    var width: CGFloat?
    var height: CGFloat?
    var cornerRadius: CGFloat = 24

    var body: some View {
        Text(prompt)
            .font(.system(size: 16))
            .foregroundStyle(.black)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: width == nil ? 312 : nil, alignment: .leading)
            .frame(width: width, height: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(color)
            )
            .clipped()
    }
}

private struct PromptNavigatorOverlay: View {
    let exchanges: [ChatExchange]
    let userBubbleColor: Color
    let presentationSource: PromptNavigatorPresentationSource
    let selectedPromptID: ChatExchange.ID?
    let onSelect: (ChatExchange) -> Void
    let onClose: () -> Void

    @State private var animatePrompts = false

    private var promptRowAnimationDuration: Double {
        presentationSource == .pinch ? 0.16 : 0.2
    }

    private var promptRowAnimationDelay: Double {
        presentationSource == .pinch ? 0.025 : 0.04
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Color.clear
                    .ignoresSafeArea()

                ScrollViewReader { listProxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(exchanges.enumerated()), id: \.element.id) { index, exchange in
                                HStack {
                                    Spacer(minLength: 0)

                                    Button {
                                        onSelect(exchange)
                                    } label: {
                                        PromptBubble(prompt: exchange.prompt, color: userBubbleColor)
                                            .opacity(selectedPromptID == exchange.id ? 0.82 : 1)
                                    }
                                    .buttonStyle(.plain)
                                    .id(exchange.id)

                                    Spacer(minLength: 0)
                                }
                                .opacity(animatePrompts ? 1 : 0)
                                .offset(y: animatePrompts ? 0 : 12)
                                .animation(
                                    .easeOut(duration: promptRowAnimationDuration).delay(Double(index) * promptRowAnimationDelay),
                                    value: animatePrompts
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 110)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        animatePrompts = false

                        DispatchQueue.main.async {
                            animatePrompts = true
                            if let selectedPromptID {
                                listProxy.scrollTo(selectedPromptID, anchor: .center)
                            }
                        }
                    }
                }

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(
                            Circle()
                                .fill(Color.black)
                        )
                        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 3)
                }
                .accessibilityIdentifier(AccessibilityIdentifier.promptNavigatorCloseButton)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 14))
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(AccessibilityIdentifier.promptNavigator)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
