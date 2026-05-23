//
//  ContentView.swift
//  AI-LLM
//
//  Created by Michael Lee on 5/3/26.
//

import SwiftUI
import UIKit

private struct ChatMessage: Identifiable, Equatable {
    enum Role {
        case user
        case assistant
    }

    let id = UUID()
    let role: Role
    let text: String
}

private let pinchPromptConversationMessages: [ChatMessage] = [
    ChatMessage(
        role: .user,
        text: "How would you explain when to use NavigationStack instead of a custom coordinator in SwiftUI?"
    ),
    ChatMessage(
        role: .assistant,
        text: "Use NavigationStack when your navigation state maps cleanly to data and can be expressed with a path or simple destination bindings. Reach for a coordinator only when you need orchestration across flows, UIKit interop, or cross-feature routing that would otherwise leak through many views. In practice, the simpler your destinations are, the more value you get from staying with native SwiftUI navigation."
    ),
    ChatMessage(
        role: .user,
        text: "What is the cleanest way to wrap a UIKit camera controller inside SwiftUI?"
    ),
    ChatMessage(
        role: .assistant,
        text: "A UIViewControllerRepresentable is usually the cleanest boundary because it keeps the UIKit lifecycle isolated. Let the representable own setup, forward delegate events through a coordinator, and push only the small set of SwiftUI-facing bindings you actually need. That keeps the SwiftUI side declarative while UIKit still handles the controller-specific details."
    ),
    ChatMessage(
        role: .user,
        text: "My SwiftUI list jumps when I append new messages. Where would you start debugging that?"
    ),
    ChatMessage(
        role: .assistant,
        text: "I would first verify identity stability, because list diffing gets unreliable if ids are regenerated during updates. After that, check whether scroll commands, animations, or conditional rows are running in the same transaction as the insert. Most jumpy chat lists come down to either unstable ids or too many layout changes happening at once."
    ),
    ChatMessage(
        role: .user,
        text: "If I already have a UIKit tab bar app, is UIHostingController still the right bridge for new SwiftUI screens?"
    ),
    ChatMessage(
        role: .assistant,
        text: "Yes, that is still the pragmatic bridge in most mixed apps. Keep UIKit in charge of top-level containers, embed SwiftUI with UIHostingController, and move shared state into observable objects or lightweight adapters rather than letting either side reach too far into the other. That gives you a gradual migration path instead of forcing a full navigation rewrite up front."
    ),
    ChatMessage(
        role: .user,
        text: "What usually causes SwiftUI views to redraw more than expected?"
    ),
    ChatMessage(
        role: .assistant,
        text: "Broad state ownership is the most common culprit. If a parent observes too much mutable state, small updates fan out into large body recomputations, so narrowing the state surface and separating derived presentation data often helps more than micro-optimizing individual views. It is usually a data flow problem before it is a rendering problem."
    ),
    ChatMessage(
        role: .user,
        text: "How would you add pull to refresh to a UIKit collection view and keep the API friendly for SwiftUI later?"
    ),
    ChatMessage(
        role: .assistant,
        text: "Wrap UIRefreshControl behind a tiny controller-facing abstraction instead of hard-coding the refresh logic into the view controller. That gives you a reusable async entry point now and a shape that can later map naturally to SwiftUI refresh actions. The goal is to make the refresh behavior portable even if the view technology changes."
    ),
    ChatMessage(
        role: .user,
        text: "Is there a good rule for deciding whether an animation belongs in SwiftUI or UIKit?"
    ),
    ChatMessage(
        role: .assistant,
        text: "If the animation is driven by view state and lives comfortably inside layout changes, SwiftUI is usually the better fit. If it depends on imperative timing, gesture choreography, or tight control over layers, UIKit or Core Animation will be easier to reason about. The more timeline control you need, the less pleasant SwiftUI animation usually becomes."
    ),
    ChatMessage(
        role: .user,
        text: "What is your preferred approach for keyboard avoidance in a chat screen built with SwiftUI?"
    ),
    ChatMessage(
        role: .assistant,
        text: "I prefer observing the keyboard frame once and translating that into a focused bottom inset rather than stacking multiple safe-area hacks. Combined with ScrollViewReader, it gives you predictable composer movement without fighting every system update. A single source of truth for the inset tends to keep the whole chat layout calmer."
    ),
    ChatMessage(
        role: .user,
        text: "Why does a UIKit-backed text view still feel easier than TextEditor for some rich input cases?"
    ),
    ChatMessage(
        role: .assistant,
        text: "UITextView shows more control over selection, attributed content, link handling, and input accessory behavior. TextEditor is improving, but once you need fine-grained editing behavior, the UIKit surface area is still materially stronger. That is why many production chat composers still keep a UIKit text view under the hood."
    ),
    ChatMessage(
        role: .user,
        text: "If I wanted a shared design language across SwiftUI and UIKit, what would you standardize first?"
    ),
    ChatMessage(
        role: .assistant,
        text: "Start with tokens, not components. Color roles, spacing, corner radii, typography scales, and elevation rules travel across both frameworks much more reliably than trying to force the same view implementation everywhere. Once the tokens are stable, the framework-specific components become much easier to keep visually aligned."
    )
]

struct ContentView: View {
    private let userBubbleColor = Color(red: 0.92, green: 0.92, blue: 0.94)
    private let topControlIconColor = Color(uiColor: .systemGray)
    private let composerHeight: CGFloat = 52

    @State private var inputText = ""
    @State private var isVideoInteractionPresented = false
    @State private var isModelMenuPresented = false
    @State private var selectedModel = AIModelOption.defaultModel
    @State private var modelToastMessage: String?
    @State private var modelToastToken = UUID()
    @State private var messages: [ChatMessage] = []
    @State private var hasLoadedInitialMessages = false

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                Color.white
                    .ignoresSafeArea()

                menuDismissBackdrop

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        ForEach(messages) { message in
                            ChatMessageRow(
                                message: message,
                                userBubbleColor: userBubbleColor
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 76)
                    .padding(.bottom, 28)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    composerBar
                }
                .onChange(of: messages.count) { _, _ in
                    guard let lastMessage = messages.last else { return }

                    withAnimation(.easeOut(duration: 0.24)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }

                VStack {
                    ZStack(alignment: .top) {
                        HStack(alignment: .top) {
                            backChevronPlaceholder
                            Spacer()
                            modelSettingsMenu
                        }

                        if let modelToastMessage {
                            modelToast(message: modelToastMessage)
                                .transition(
                                    .asymmetric(
                                        insertion: .opacity.combined(
                                            with: .scale(scale: 0.96, anchor: .center)
                                        ),
                                        removal: .opacity.combined(
                                            with: .scale(scale: 0.98, anchor: .center)
                                        )
                                    )
                                )
                                .zIndex(3)
                        }
                    }
                    Spacer()
                }
                .padding(.top, 12)
                .padding(.leading, 18)
                .padding(.trailing, 18)
                .zIndex(2)
            }
            .onAppear(perform: loadInitialMessagesIfNeeded)
        }
        .environment(\.colorScheme, .light)
        .fullScreenCover(isPresented: $isVideoInteractionPresented) {
            VideoInteractionView(selectedModel: selectedModel) { model in
                updateSelectedModel(model)
            }
        }
    }

    private var backChevronPlaceholder: some View {
        Image(systemName: "chevron.left")
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(topControlIconColor)
            .frame(width: 48, height: 48)
            .topIconCircle()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var menuDismissBackdrop: some View {
        if isModelMenuPresented {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture {
                    dismissKeyboard()
                    dismissModelMenu()
                }
                .zIndex(1)
        }
    }

    private var modelSettingsMenu: some View {
        VStack(alignment: .trailing, spacing: 10) {
            modelSettingsButton

            if isModelMenuPresented {
                modelDropdown
                    .transition(
                        .opacity.combined(
                            with: .scale(scale: 0.96, anchor: .topTrailing)
                        )
                    )
            }
        }
    }

    private var modelSettingsButton: some View {
        Button(action: toggleModelMenu) {
            modelSettingsIcon
                .topIconCircle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Switch model")
    }

    private var modelSettingsIcon: some View {
        Image(systemName: "gearshape.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(topControlIconColor)
            .frame(width: 48, height: 48)
    }

    private var modelDropdown: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("Current")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text(selectedModel.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .padding(.vertical, 2)

            Divider()

            Button {
                withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                    isModelMenuPresented = false
                }
                presentVideoInteraction()
            } label: {
                HStack(spacing: 10) {
                    Text("Switch Model")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 244, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 18, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
    }

    private func modelToast(message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.74)
            .padding(.horizontal, 14)
            .frame(height: 48)
            .frame(maxWidth: 244)
            .liquidGlass(cornerRadius: 24, interactive: false)
            .shadow(color: Color.black.opacity(0.12), radius: 16, y: 6)
            .padding(.horizontal, 68)
            .allowsHitTesting(false)
    }

    private var composerBar: some View {
        HStack(spacing: 8) {
            Button(action: {}) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: composerHeight, height: composerHeight)
                    .background(Circle().fill(Color.white))
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.22), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                TextField("Ask here", text: $inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .submitLabel(.send)
                    .onSubmit(sendMessage)

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(canSend ? Color.black : Color.gray.opacity(0.45))
                }
                .disabled(!canSend)
            }
            .padding(.leading, 16)
            .padding(.trailing, 12)
            .frame(minHeight: composerHeight)
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

    private func sendMessage() {
        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        inputText = ""
        messages.append(ChatMessage(role: .user, text: trimmedInput))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            messages.append(ChatMessage(role: .assistant, text: response(for: trimmedInput)))
        }
    }

    private func response(for input: String) -> String {
        let cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        A practical way to approach "\(cleanedInput)" is to start with the native SwiftUI API, then introduce UIKit only where you need lifecycle control, mature delegates, or lower-level rendering behavior. That keeps the implementation easy to reason about while preserving an escape hatch for the parts SwiftUI does not own cleanly yet.
        """
    }

    private func presentVideoInteraction() {
        guard !isVideoInteractionPresented else { return }

        dismissKeyboard()
        isModelMenuPresented = false
        isVideoInteractionPresented = true
    }

    private func toggleModelMenu() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            isModelMenuPresented.toggle()
        }
    }

    private func dismissModelMenu() {
        guard isModelMenuPresented else { return }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
            isModelMenuPresented = false
        }
    }

    private func loadInitialMessagesIfNeeded() {
        guard !hasLoadedInitialMessages else { return }
        hasLoadedInitialMessages = true

        DispatchQueue.main.async {
            messages = pinchPromptConversationMessages
        }
    }

    private func updateSelectedModel(_ model: AIModelOption) {
        selectedModel = model

        let token = UUID()
        modelToastToken = token

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard modelToastToken == token else { return }

            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                modelToastMessage = "Model updated to \(model.displayName)"
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
            guard modelToastToken == token else { return }

            withAnimation(.easeInOut(duration: 0.36)) {
                modelToastMessage = nil
            }
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

private extension View {
    func topIconCircle() -> some View {
        self
            .background(Circle().fill(Color.white))
            .shadow(color: Color.black.opacity(0.09), radius: 14, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.04), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    func liquidGlass(cornerRadius: CGFloat, interactive: Bool) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            self.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 1)
            )
        }
    }
}

private struct ChatMessageRow: View {
    let message: ChatMessage
    let userBubbleColor: Color

    var body: some View {
        switch message.role {
        case .user:
            HStack {
                Spacer(minLength: 52)

                Text(message.text)
                    .font(.system(size: 16))
                    .foregroundStyle(.black)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .frame(maxWidth: 312, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(userBubbleColor)
                    )
            }

        case .assistant:
            Text(message.text)
                .font(.system(size: 17))
                .foregroundStyle(.primary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 6)
                .padding(.trailing, 12)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
