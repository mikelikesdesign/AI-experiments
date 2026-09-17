//
//  ContentView.swift
//  scroll options
//
//  Adapted from AI content interaction
//

import SwiftUI
import UIKit

enum ContentAction: String, CaseIterable {
    case simplify = "Simplify"
    case learnMore = "Learn More"
    case startNewChat = "Start New Chat"

    var symbol: String {
        switch self {
        case .simplify: "text.alignleft"
        case .learnMore: "text.magnifyingglass"
        case .startNewChat: "plus"
        }
    }
}

/// What the pull-through selector offers. A conversation offers the follow-up
/// actions; the empty state offers the most recent threads instead.
enum ScrollOption: Equatable {
    case action(ContentAction)
    case thread(ChatThread)

    var title: String {
        switch self {
        case .action(let action): action.rawValue
        case .thread(let thread): thread.title
        }
    }
}

/// A chat pushed on top of the thread list.
enum ChatRoute: Hashable {
    case thread(id: String)
    case newChat
}

struct ContentView: View {
    /// The thread list is the root; the app opens with a chat already pushed,
    /// so going back pages out to the list.
    @State private var path: [ChatRoute] = [.thread(id: ChatThread.uikitOverview.id)]

    private let threads = ChatThread.samples

    var body: some View {
        NavigationStack(path: $path) {
            ChatThreadListView(
                threads: threads,
                onSelect: { path.append(.thread(id: $0.id)) },
                onNewChat: { path.append(.newChat) }
            )
            .navigationDestination(for: ChatRoute.self) { route in
                ChatThreadView(thread: thread(for: route))
                    .toolbar(.hidden, for: .navigationBar)
                    .navigationBarBackButtonHidden(true)
            }
        }
        .background(.black)
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    private func thread(for route: ChatRoute) -> ChatThread? {
        switch route {
        case .thread(let id): threads.first { $0.id == id }
        case .newChat: nil
        }
    }
}

private struct ChatThreadView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ContentViewModel
    @State private var threadID = UUID()

    init(thread: ChatThread?) {
        _viewModel = StateObject(wrappedValue: ContentViewModel(thread: thread))
    }
    @State private var draft = ""
    @FocusState private var isComposerFocused: Bool
    @State private var menuReveal = OptionMenuReveal()
    @State private var selectedIndex = 0
    @State private var selectionAnchorTranslation: CGFloat?
    @State private var scrollContentLock = ScrollContentLock()
    @State private var isScrubbing = false
    @State private var pullDistance: CGFloat = 0
    @State private var peakPullDistance: CGFloat = 0
    @State private var committedOption: ScrollOption?
    @State private var isCommitLeaving = false
    @State private var followsStream = true
    @State private var isStreamEndVisible = false
    @State private var optionsReady = true
    @State private var responseHeight: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var optionRowHeight: CGFloat = 62

    private let threads = ChatThread.samples
    /// How many recent threads the empty state offers through the pull.
    private let recentThreadLimit = 3

    private let controlHorizontalInset: CGFloat = 16
    /// Every response can scroll at least this far, so the menu is opened and
    /// closed with the same gesture whether the response is long or short.
    private let minimumScrollRange: CGFloat = 200
    /// Fraction of the pull the held response drifts by, so the stop is elastic.
    private let pullGive: CGFloat = 0.12

    /// Options the pull steps through, in order. Empty while there is nothing
    /// to act on, which also hides the selector.
    private var options: [ScrollOption] {
        if viewModel.turns.isEmpty {
            return threads
                .sorted { $0.lastActivity > $1.lastActivity }
                .prefix(recentThreadLimit)
                .map(ScrollOption.thread)
        }
        guard !viewModel.content.isEmpty else { return [] }
        return ContentAction.allCases.map(ScrollOption.action)
    }

    private var committedIndex: Int? {
        committedOption.flatMap { options.firstIndex(of: $0) }
    }

    private var showsOptions: Bool {
        revealProgress > 0 && !viewModel.isStreaming && !isComposerFocused
            && !options.isEmpty && optionsReady
    }

    private var revealProgress: CGFloat { menuReveal.progress }

    // Full blur lands as the last label finishes unfolding (see ScrollActionSelector),
    // so the options never sit over crisp text. ProgressiveBlur eases the curve.
    private var blurStrength: CGFloat {
        showsOptions ? min(revealProgress / 0.85, 1) : 0
    }

    private var pullPosition: OptionPullPosition {
        OptionPullPosition(distance: pullDistance, optionCount: options.count)
    }

    private func extraScrollSpace(viewportHeight: CGFloat) -> CGFloat {
        max(viewportHeight + minimumScrollRange - responseHeight, 0)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            // Only the conversation dissolves; controls retain their identity
            // and remain tappable during repeated new-thread requests.
            // The empty state is the same scroll surface with no turns, so the
            // pull past its end offers recent threads the way a response
            // offers follow-up actions.
            GeometryReader { viewport in
                scrollContent(viewportHeight: viewport.size.height)
            }
            .id(threadID)
            .transition(.opacity)

            if showsOptions {
                ScrollActionSelector(
                    options: options.map(\.title),
                    selectedIndex: selectedIndex,
                    selectionPosition: pullPosition.position,
                    isScrubbing: isScrubbing,
                    revealProgress: revealProgress,
                    committedIndex: committedIndex,
                    isDismissing: isCommitLeaving,
                    rowHeight: optionRowHeight
                )
                .padding(.horizontal, 36)
                .padding(.bottom, 22)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .overlay(alignment: .topLeading) {
            Button {
                isComposerFocused = false
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("Back to chats")
            .accessibilityIdentifier("backToThreads")
            .padding(.leading, controlHorizontalInset)
            .padding(.top, 8)
        }
        .overlay(alignment: .topTrailing) {
            Button(action: startNewChat) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: Circle())
            .accessibilityLabel("Start new chat")
            .accessibilityIdentifier("startNewChat")
            .padding(.trailing, controlHorizontalInset)
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            chatComposer
                .padding(.horizontal, controlHorizontalInset)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .background(.black)
        .onChange(of: selectedIndex) { _, _ in
            guard showsOptions, isScrubbing, committedOption == nil else { return }
            UISelectionFeedbackGenerator().selectionChanged()
        }
        .onChange(of: isScrubbing) { _, isActive in
            if isActive {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
            }
        }
        .task(id: committedOption) {
            guard let option = committedOption else { return }
            let optionThreadID = threadID
            if !reduceMotion {
                do {
                    // Dwell on the choice, lift it out of view, then hand over.
                    try await Task.sleep(for: .milliseconds(180))
                    guard !Task.isCancelled, threadID == optionThreadID,
                          committedOption == option else { return }
                    withAnimation(.easeIn(duration: 0.3)) {
                        isCommitLeaving = true
                    }
                    try await Task.sleep(for: .milliseconds(300))
                } catch {
                    return
                }
            }
            // A top-right reset takes priority even if this task has already
            // resumed before SwiftUI delivers its cancellation.
            guard !Task.isCancelled, threadID == optionThreadID,
                  committedOption == option else { return }
            completeOption(option)
        }
        .onDisappear {
            scrollContentLock.onPanChange = nil
            scrollContentLock.unlock()
            viewModel.stopStreaming()
        }
    }

    private func scrollContent(viewportHeight: CGFloat) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    ForEach(viewModel.turns) { turn in
                        VStack(alignment: .leading, spacing: 28) {
                            HStack(spacing: 0) {
                                Spacer(minLength: 16)
                                Text(turn.question)
                                    .font(.system(size: 17))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 12)
                                    .background(
                                        .white.opacity(0.14),
                                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    )
                                    .accessibilityIdentifier("chatQuestion")
                            }

                            Text(turn.response)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .animation(.none, value: turn.response)
                                .accessibilityIdentifier("chatResponse")
                        }
                        .id(turn.id)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("responseEnd")
                }
                .id("responseStart")
                .padding(.horizontal, 24)
                .padding(.top, 68)
                .padding(.bottom, optionRowHeight * 3 + 42)
                .textSelection(.disabled)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    responseHeight = height
                }
                // Room below a short response, so it can scroll far enough for
                // the menu to open and, just as importantly, close again.
                .padding(.bottom, extraScrollSpace(viewportHeight: viewportHeight))
                .modifier(ProgressiveBlur(
                    viewportHeight: viewportHeight,
                    height: optionRowHeight * 3 + 260,
                    strength: blurStrength
                ))
                // Scroll thresholds, hold-open pinning, and option visibility all
                // step the strength; a short retargeting spring turns them into a
                // continuous change that trails the finger imperceptibly.
                .animation(.smooth(duration: 0.3), value: blurStrength)
                .background(ScrollContentLockReader(
                    controller: scrollContentLock, onPanChange: handleScrollPan
                ))
            }
            .coordinateSpace(name: "chatViewport")
            .scrollDismissesKeyboard(.interactively)
            .onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
                ScrollMetrics(
                    offset: geometry.contentOffset.y + geometry.contentInsets.top,
                    maximumOffset: max(
                        geometry.contentSize.height + geometry.contentInsets.top
                            + geometry.contentInsets.bottom - geometry.containerSize.height,
                        0
                    ),
                    contentHeight: geometry.contentSize.height
                )
            } action: { oldMetrics, metrics in
                let remainingDistance = max(metrics.maximumOffset - metrics.offset, 0)
                // The extra room below a short response is not part of it.
                let remainingResponse = max(
                    remainingDistance - extraScrollSpace(viewportHeight: viewportHeight), 0
                )
                isStreamEndVisible = remainingResponse <= optionRowHeight * 3 + 96
                if selectionAnchorTranslation == nil && committedOption == nil {
                    menuReveal.update(
                        remainingDistance: remainingDistance, scrollRange: metrics.maximumOffset
                    )
                    if revealProgress == 0 {
                        resetSelection()
                    }
                }
                // Follow layout growth, rather than issuing a scroll for every word.
                if viewModel.isStreaming, followsStream,
                   oldMetrics.contentHeight != metrics.contentHeight {
                    proxy.scrollTo("responseEnd", anchor: .bottom)
                }
            }
            .onScrollPhaseChange { oldPhase, phase in
                if phase == .tracking || phase == .interacting {
                    if viewModel.isStreaming {
                        followsStream = false
                    } else {
                        optionsReady = true
                    }
                } else if phase == .idle,
                          oldPhase == .tracking || oldPhase == .interacting || oldPhase == .decelerating {
                    followsStream = isStreamEndVisible
                }
            }
            .onChange(of: viewModel.responseID) { _, _ in
                followsStream = !UIAccessibility.isVoiceOverRunning
                optionsReady = false
                menuReveal.reset()
                proxy.scrollTo(viewModel.responseID, anchor: .top)
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    isComposerFocused = false
                }
            )
            .accessibilityIdentifier(viewModel.turns.isEmpty ? "emptyChatThread" : "chatThread")
        }
        .accessibilityActions {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button(option.title) { performOption(option) }
            }
        }
    }

    private var chatComposer: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField(
                "Ask question...",
                text: $draft,
                prompt: Text("Ask question...")
                    .foregroundStyle(.white.opacity(0.5)),
                axis: .vertical
            )
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .tint(.white)
                .focused($isComposerFocused)
                .submitLabel(.return)
                .lineLimit(1...4)
                .padding(.vertical, 11)
                .accessibilityLabel("Chat message")
                .accessibilityHint("Placeholder input. Sending messages is not connected yet.")
                .accessibilityIdentifier("chatInput")

            if viewModel.isStreaming {
                Button(action: viewModel.stopStreaming) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.14), in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop response")
                .accessibilityHint("Keeps the text already shown.")
                .accessibilityIdentifier("stopResponse")
            } else {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .frame(width: 36, height: 36)
                    .background(.white.opacity(0.08), in: Circle())
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, 22)
        .padding(.trailing, 10)
        .padding(.vertical, 7)
        .frame(minHeight: 58)
        // Let the text field handle focus without a container-wide glass press effect.
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 29, style: .continuous))
    }

    // Observe the scroll view's own pan, so holding the response does not leave
    // a second gesture recognizer competing for the rest of the drag. One drag
    // can scroll to the end, pull through the options in either direction, pull
    // back below the anchor to resume scrolling, and pull in again.
    private func handleScrollPan(_ event: ScrollPanEvent) {
        guard committedOption == nil else { return }
        switch event.phase {
        case .began:
            resetSelection()
            if viewModel.isStreaming {
                followsStream = false
            } else {
                optionsReady = true
            }
            // A new chat opens with the keyboard up. Pulling on the blank thread
            // is a request for recent chats, so let it dismiss the keyboard
            // rather than showing nothing.
            if viewModel.turns.isEmpty, isComposerFocused {
                isComposerFocused = false
            }
            updateSelection(with: event)
        case .changed:
            updateSelection(with: event)
        case .ended:
            let releaseDistance = selectionAnchorTranslation.map { $0 - event.translation.height }
            let releaseIndex = OptionPullPosition.releaseCandidate(
                distance: releaseDistance,
                peakDistance: peakPullDistance,
                previousIndex: selectedIndex,
                optionCount: options.count
            )
            selectionAnchorTranslation = nil
            if let releaseIndex, options.indices.contains(releaseIndex) {
                pullDistance = max(releaseDistance ?? 0, 0)
                performOption(options[releaseIndex])
            } else {
                resetSelection()
            }
        case .cancelled:
            resetSelection()
        }
    }

    private func updateSelection(with event: ScrollPanEvent) {
        guard showsOptions else {
            resetSelection()
            return
        }
        guard let anchor = selectionAnchorTranslation else {
            // The response scrolls all the way to its end first. Only the pull
            // that continues past the end becomes a selection.
            guard OptionPullPosition.canBeginSelection(
                optionsVisible: showsOptions,
                remainingDistance: event.remainingDistance,
                translation: event.translation,
                entryDistance: OptionPullPosition.entryDistance(
                    forRevealDistance: menuReveal.revealDistance
                )
            ) else { return }
            selectionAnchorTranslation = event.translation.height
            menuReveal.holdOpen()
            scrollContentLock.lock()
            return
        }

        let position = OptionPullPosition(
            distance: anchor - event.translation.height,
            optionCount: options.count
        )
        if position.cancelsSelection {
            // Hand the same drag back to the scroll view; it may pull in again.
            resetSelection()
            return
        }
        pullDistance = max(position.distance, 0)
        peakPullDistance = max(peakPullDistance, pullDistance)
        scrollContentLock.setPullGive(pullDistance * pullGive)
        // Scrubbing (and its haptic) starts when the first option becomes live,
        // not when the response merely reaches its end.
        if !isScrubbing, position.isArmed(afterPeakDistance: peakPullDistance) {
            isScrubbing = true
        }
        if let index = position.candidateIndex(
            previousIndex: selectedIndex, peakDistance: peakPullDistance
        ), options.indices.contains(index) {
            selectedIndex = index
        }
    }

    private func performOption(_ option: ScrollOption) {
        guard committedOption == nil, let index = options.firstIndex(of: option) else { return }
        isComposerFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.8)) {
            selectedIndex = index
            committedOption = option
        }
    }

    private func completeOption(_ option: ScrollOption) {
        // The chosen option has already left the screen, so removing the
        // selector here is invisible. Hiding it for every option keeps the
        // outgoing thread from showing the first choice highlighted behind the next flow.
        menuReveal.reset()
        committedOption = nil
        isCommitLeaving = false
        resetSelection()

        switch option {
        case .action(.simplify):
            viewModel.simplifyContent()
        case .action(.learnMore):
            viewModel.learnMoreContent()
        case .action(.startNewChat):
            startNewChat()
        case .thread(let thread):
            openThread(thread)
        }
    }

    private func startNewChat() {
        replaceThread {
            viewModel.startNewThread()
        }
        isComposerFocused = true
    }

    private func openThread(_ thread: ChatThread) {
        guard thread.id != viewModel.currentThreadID || viewModel.turns.isEmpty else { return }
        replaceThread {
            viewModel.loadThread(thread)
        }
        isComposerFocused = false
    }

    /// Tears down the current conversation synchronously, before it fades out,
    /// then swaps in whatever `load` puts in the view model.
    private func replaceThread(_ load: () -> Void) {
        committedOption = nil
        isCommitLeaving = false
        scrollContentLock.onPanChange = nil
        scrollContentLock.detach()
        resetSelection()
        menuReveal.reset()
        followsStream = true
        isStreamEndVisible = false
        optionsReady = true
        responseHeight = 0
        draft = ""
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
            load()
            threadID = UUID()
        }
    }

    private func resetSelection() {
        scrollContentLock.unlock()
        selectedIndex = 0
        selectionAnchorTranslation = nil
        isScrubbing = false
        pullDistance = 0
        peakPullDistance = 0
    }
}

private struct ScrollMetrics: Equatable {
    let offset: CGFloat
    let maximumOffset: CGFloat
    let contentHeight: CGFloat
}

#Preview {
    ContentView()
}
