//
//  ContentViewModel.swift
//  scroll options
//
//  Content adapted from AI content interaction.
//
//  Created by Michael Lee on 11/11/24.
//

import SwiftUI
import Combine

struct ChatTurn: Identifiable, Equatable {
    let id: UUID
    let question: String
    let response: String
}

@MainActor
final class ContentViewModel: ObservableObject {
    @Published private(set) var question: String?
    @Published private(set) var content: String
    @Published private(set) var streamingText = ""
    @Published private(set) var isStreaming = false
    @Published private(set) var responseID = UUID()
    @Published private(set) var streamingLabel = ""
    @Published private(set) var wasStopped = false
    @Published private(set) var previousTurns: [ChatTurn] = []
    /// The saved thread this conversation was opened from; nil for a fresh chat.
    @Published private(set) var currentThreadID: String?

    var displayedText: String { isStreaming ? streamingText : content }

    var turns: [ChatTurn] {
        guard let question else { return previousTurns }
        return previousTurns + [ChatTurn(id: responseID, question: question, response: displayedText)]
    }

    private var streamingTask: Task<Void, Never>?

    convenience init(isNewThread: Bool = false) {
        self.init(thread: isNewThread ? nil : ChatThread.uikitOverview)
    }

    /// Opens on `thread`, or on an empty conversation when nil.
    init(thread: ChatThread?) {
        question = nil
        content = ""
        if let thread {
            loadThread(thread)
        }
    }

    /// Replaces the conversation with a saved thread, ending any stream first.
    func loadThread(_ thread: ChatThread) {
        streamingTask?.cancel()
        streamingTask = nil
        isStreaming = false
        streamingText = ""
        streamingLabel = ""
        wasStopped = false
        currentThreadID = thread.id

        guard let last = thread.turns.last else {
            question = nil
            content = ""
            previousTurns = []
            responseID = UUID()
            return
        }
        previousTurns = Array(thread.turns.dropLast())
        question = last.question
        content = last.response
        responseID = last.id
    }

    private func streamContent(question: String, finalText: String, label: String) {
        // Preserve the visible response, including partial text if it was stopped,
        // before appending the next exchange in this same conversation.
        stopStreaming()
        if let currentQuestion = self.question {
            previousTurns.append(ChatTurn(id: responseID, question: currentQuestion, response: content))
        }
        streamingTask?.cancel()
        let chunks = StreamingChunk.make(from: finalText)
        self.question = question
        content = ""
        streamingLabel = label
        wasStopped = false
        // Publish the first word immediately below the new follow-up message.
        streamingText = chunks.first?.text ?? ""
        isStreaming = !chunks.isEmpty
        responseID = UUID()

        guard !chunks.isEmpty else {
            content = finalText
            streamingTask = nil
            return
        }

        streamingTask = Task { [weak self] in
            for index in chunks.indices.dropFirst() {
                do {
                    try await Task.sleep(for: chunks[index - 1].pause)
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                self.streamingText.append(chunks[index].text)
            }
            guard !Task.isCancelled, let self else { return }
            self.content = finalText
            self.isStreaming = false
            self.streamingTask = nil
        }
    }

    func startNewThread() {
        streamingTask?.cancel()
        streamingTask = nil
        question = nil
        content = ""
        streamingText = ""
        isStreaming = false
        responseID = UUID()
        streamingLabel = ""
        wasStopped = false
        previousTurns = []
        currentThreadID = nil
    }

    func stopStreaming() {
        guard isStreaming else { return }
        streamingTask?.cancel()
        streamingTask = nil
        content = streamingText
        wasStopped = true
        isStreaming = false
    }

    deinit {
        streamingTask?.cancel()
    }

    func simplifyContent() {
        let simplifiedText = """
        UIKit is Apple’s toolkit for building iPhone and iPad interfaces. You assemble a screen from views such as labels, buttons, images, and lists, then use view controllers to manage what appears and how the user moves between screens.

        UIKit is imperative, which means your code tells each interface object what to do. Auto Layout helps the design fit different devices, while events, gestures, delegates, and data sources handle interaction and data. It is mature, flexible, and especially strong when an app needs precise control or uses an existing UIKit codebase.

        UIKit also works with SwiftUI, so an app can use both and adopt SwiftUI gradually.
        """
        streamContent(question: "Simplify", finalText: simplifiedText, label: "Simplifying…")
    }

    func learnMoreContent() {
        let detailedText = """
        UIKit’s architecture starts with UIApplication, which represents the running app, and UIScene, which represents one instance of its interface. A UIWindow hosts the root view controller for a scene. From there, view controllers form a hierarchy that presents and contains screens, while each controller manages a hierarchy of UIView objects. Navigation controllers, tab bar controllers, split view controllers, and presentation controllers provide standard ways to organize those screens.

        UIView is the foundation of rendering and interaction. Views define geometry, appearance, and hit testing, while Core Animation layers perform much of the actual compositing. UIKit provides built-in controls such as UIButton, UITextField, UISlider, and UISwitch, as well as higher-level components for alerts, menus, search, web content, document picking, and sharing. Custom views can draw with Core Graphics or coordinate more advanced rendering technologies.

        Layout is usually managed with Auto Layout constraints. Constraints describe relationships—such as spacing, alignment, and size—instead of hard-coding frames. Safe-area guides keep content clear of system UI, layout margins establish readable spacing, and intrinsic content sizes let controls size themselves naturally. Trait collections and size classes help interfaces respond to environment changes, while Dynamic Type and localization should be considered from the beginning.

        UIKit routes touch, keyboard, motion, press, and remote-control events through the responder chain. UIControl uses target-action for common control events, and UIGestureRecognizer handles taps, pans, pinches, and custom gestures. Delegation is common when one object needs to report behavior to another. For collections of data, UITableView and UICollectionView use reusable cells, and modern diffable data sources apply state snapshots safely with built-in update animations.

        View-controller lifecycle callbacks such as viewDidLoad, viewWillAppear, and viewDidDisappear are places to prepare and react to a screen. Scene and app delegates handle broader transitions such as connecting a window, entering the background, or opening a URL. Because UIKit objects are not thread-safe, interface updates belong on the main actor; networking and expensive work should run asynchronously and publish results back to the UI.

        Accessibility is built into UIKit through properties such as accessibilityLabel, accessibilityValue, traits, and custom actions. Standard controls already provide useful semantics, but custom components need deliberate support. A polished UIKit interface should also account for VoiceOver, Dynamic Type, increased contrast, reduced motion, keyboard navigation, pointer input, and right-to-left layouts.

        UIKit interoperates directly with SwiftUI. UIHostingController embeds a SwiftUI view in a UIKit hierarchy. In the other direction, UIViewRepresentable and UIViewControllerRepresentable wrap UIKit components for SwiftUI. This makes incremental migration practical: teams can keep stable UIKit flows, introduce new SwiftUI screens, and bridge shared state without rewriting an entire app.

        UIKit is a strong choice when a project depends on an established UIKit architecture, needs fine-grained control over navigation or interaction, or relies on a mature UIKit-only component. SwiftUI is often faster for new state-driven interfaces, but the frameworks are complementary rather than mutually exclusive. Understanding UIKit also helps explain the lifecycle, layout, and event systems beneath many Apple-platform interfaces.
        """
        streamContent(question: "Add more details", finalText: detailedText, label: "Exploring UIKit…")
    }
}
