//
//  ChatThread.swift
//  scroll options
//
//  Sample conversation history shown from the menu button.
//

import Foundation

struct ChatThread: Identifiable, Equatable {
    let id: String
    let title: String
    let lastActivity: Date
    let turns: [ChatTurn]

    var preview: String {
        turns.last?.response
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first.map(String.init) ?? ""
    }
}

extension ChatThread {
    /// The conversation the app opens on. Kept here so the menu can show it as
    /// the current thread and reopen it after switching away.
    static let uikitOverview = ChatThread(
        id: "uikit-overview",
        title: "UIKit overview",
        lastActivity: .now,
        turns: [
            ChatTurn(
                id: UUID(uuidString: "6A1B4B0E-6D5C-4E6B-9A4C-0F0D5B4E1A01")!,
                question: "Give me an overview on UIKit, thanks",
                response: """
                UIKit is Apple’s event-driven framework for building graphical interfaces on iOS and iPadOS. It supplies the views, controls, navigation systems, layout tools, and app-lifecycle APIs behind many Apple-platform apps. Unlike SwiftUI’s declarative approach, UIKit is imperative: you create objects, configure them, and respond to state changes and user events directly.

                A UIKit interface is built as a hierarchy of UIView objects. Labels, buttons, images, text fields, and custom drawing surfaces are all views. UIViewController objects manage those views and coordinate navigation, presentation, and screen-level behavior. At the top, UIWindow and UIScene connect the hierarchy to an app window and its lifecycle.

                UIKit includes familiar containers such as UINavigationController, UITabBarController, UITableView, and UICollectionView. Auto Layout expresses relationships between views so an interface can adapt to different screen sizes, orientations, Dynamic Type settings, and languages. Interfaces can be created in code, with Interface Builder and storyboards, or with a combination of both.

                User interaction flows through UIKit’s event and responder systems. Controls expose target-action events, gestures are handled by gesture recognizers, and delegates or data sources let objects report events without tightly coupling components. Modern UIKit also supports diffable data sources, compositional collection-view layouts, drag and drop, pointer interactions, accessibility, animation, and rich text editing.

                UIKit and SwiftUI can coexist in the same app. UIHostingController places SwiftUI inside UIKit, while UIViewRepresentable and UIViewControllerRepresentable expose UIKit components to SwiftUI. UIKit remains especially useful for mature codebases, highly customized interactions, and APIs that do not yet have an equivalent SwiftUI abstraction.

                In practice, a UIKit app benefits from clear separation between view code, state, and business logic. UI work should stay on the main actor, view controllers should remain focused, and reusable views should own presentation rather than application behavior. This makes an imperative UIKit codebase easier to test, maintain, and gradually combine with SwiftUI.
                """
            )
        ]
    )

    static let samples: [ChatThread] = [
        uikitOverview,
        ChatThread(
            id: "swiftui-state",
            title: "State vs. Observable",
            lastActivity: .now.addingTimeInterval(-3 * 3600),
            turns: [
                ChatTurn(
                    id: UUID(),
                    question: "When should I use @State, @StateObject, or @Observable?",
                    response: """
                    Use @State for simple value types that belong to a single view, such as a toggle, a text field draft, or a selected tab. SwiftUI owns the storage and the view is re-evaluated whenever the value changes.

                    @StateObject is for reference types that conform to ObservableObject. The view creates the object once and keeps it alive across re-renders, so it suits view models that own tasks, subscriptions, or other long-lived work. Pass it down as @ObservedObject or through the environment.

                    With iOS 17 and later, the @Observable macro replaces most of this. Mark the class @Observable, hold it in @State, and SwiftUI tracks only the properties each view actually reads. That gives finer-grained updates than ObservableObject, where any @Published change refreshes every observer.
                    """
                ),
                ChatTurn(
                    id: UUID(),
                    question: "Can I mix ObservableObject and @Observable?",
                    response: """
                    Yes. They can live in the same app and even in the same view hierarchy. The main rule is to keep one model type on one system: an @Observable class should not also adopt ObservableObject, and @Published does nothing on an @Observable type.

                    Migrate leaf models first, then move shared ones once every view that reads them targets iOS 17 or later. Bindable replaces ObservedObject when you need bindings into an @Observable model.
                    """
                ),
            ]
        ),
        ChatThread(
            id: "uiviewrepresentable",
            title: "Wrapping UIKit views",
            lastActivity: .now.addingTimeInterval(-26 * 3600),
            turns: [
                ChatTurn(
                    id: UUID(),
                    question: "How do I wrap a UIKit view in SwiftUI?",
                    response: """
                    Conform a struct to UIViewRepresentable. makeUIView creates the UIKit view once, and updateUIView pushes new SwiftUI state into it every time the representable is re-evaluated. Treat the struct as a description, not the view itself; it is recreated freely.

                    When UIKit needs to talk back, add a Coordinator. makeCoordinator returns an object that can act as the delegate or target, and it can hold bindings or closures to update SwiftUI state. Keep the coordinator’s references weak where UIKit already retains the view.

                    Sizing is the most common surprise. UIKit views often report an intrinsic content size that SwiftUI honors, so a UITextView or UILabel may grow without limit. Set contentHuggingPriority and compression resistance in makeUIView, or implement sizeThatFits on iOS 16 and later to give SwiftUI a precise answer.
                    """
                )
            ]
        ),
        ChatThread(
            id: "layout-comparison",
            title: "Auto Layout vs. SwiftUI",
            lastActivity: .now.addingTimeInterval(-2 * 86400),
            turns: [
                ChatTurn(
                    id: UUID(),
                    question: "How is SwiftUI layout different from Auto Layout?",
                    response: """
                    Auto Layout is a constraint solver. You describe relationships between edges, centers, and sizes, and the engine finds frames that satisfy them. Ambiguity and conflicts are runtime problems, and priorities decide which constraints yield.

                    SwiftUI layout is a negotiation. A parent proposes a size, each child chooses its own size within that proposal, and the parent then positions the children. There are no constraints to break; a view simply reports what it wants. Stacks, frames, padding, and spacers compose that negotiation into most layouts.

                    In practice, SwiftUI layouts are quicker to write and easier to reason about locally, while Auto Layout handles cross-hierarchy alignment more directly. The Layout protocol lets you write custom containers that participate in the proposal cycle when the built-in stacks fall short.
                    """
                )
            ]
        ),
        ChatThread(
            id: "navigation",
            title: "Navigation stacks",
            lastActivity: .now.addingTimeInterval(-3 * 86400),
            turns: [
                ChatTurn(
                    id: UUID(),
                    question: "Compare NavigationStack with UINavigationController",
                    response: """
                    UINavigationController manages an array of view controllers and exposes push, pop, and the navigation bar directly. It is imperative and predictable: you decide exactly when a screen appears and how it is configured.

                    NavigationStack drives the same stack from state. Bind it to a path array of Hashable values, declare destinations with navigationDestination(for:), and appending to the path pushes a screen. Because the path is plain data, deep links, restoration, and programmatic pops become simple array edits.

                    Under the hood NavigationStack still uses UINavigationController on iOS, which is why interactive pop and bar appearance behave the same. It also means UIKit appearance proxies affect SwiftUI navigation bars when the modifiers do not reach far enough.
                    """
                )
            ]
        ),
        ChatThread(
            id: "swiftui-animation",
            title: "Animating changes",
            lastActivity: .now.addingTimeInterval(-5 * 86400),
            turns: [
                ChatTurn(
                    id: UUID(),
                    question: "What is the difference between withAnimation and .animation?",
                    response: """
                    withAnimation animates every change caused by the state mutation inside its closure. It is explicit and scoped to a moment in time, so it suits button taps and other discrete events.

                    The .animation(_:value:) modifier watches a specific value and animates any change that flows from it, wherever the change originated. It works well for values that update continuously, such as scroll offsets or gesture translations, where wrapping every mutation is impractical.

                    Both use the same animation types. Springs are the default in modern SwiftUI, and .smooth, .snappy, and .bouncy are presets tuned for interface motion. Use a Transaction when you need to disable or override an animation for part of a hierarchy.
                    """
                )
            ]
        ),
        ChatThread(
            id: "diffable-data-sources",
            title: "Diffable data sources",
            lastActivity: .now.addingTimeInterval(-9 * 86400),
            turns: [
                ChatTurn(
                    id: UUID(),
                    question: "Why use UICollectionViewDiffableDataSource?",
                    response: """
                    A diffable data source replaces the index-path bookkeeping of the classic delegate pattern with snapshots. You build an NSDiffableDataSourceSnapshot describing the sections and item identifiers, apply it, and the collection view computes the inserts, deletes, and moves itself.

                    That removes an entire class of crashes where the data changed but the batch update did not match. It also pairs naturally with compositional layouts and cell registrations, so a modern UIKit list can be a few dozen lines.

                    Identifiers must be Hashable and stable. If you use whole model structs as identifiers, any field change looks like a delete and insert; keep the identifier small and use reconfigureItems to refresh content in place.
                    """
                )
            ]
        ),
        ChatThread(
            id: "list-performance",
            title: "List vs. UITableView",
            lastActivity: .now.addingTimeInterval(-14 * 86400),
            turns: [
                ChatTurn(
                    id: UUID(),
                    question: "Is SwiftUI List as fast as UITableView?",
                    response: """
                    List is backed by UICollectionView on recent iOS versions, so scrolling performance is close to UIKit for straightforward rows. It reuses cells, only builds visible rows, and handles selection, swipe actions, and editing without extra code.

                    The gaps show up with complex per-row state, very large data sets that need prefetching, or layouts that depend on precise cell heights. There, UITableView or UICollectionView still give more control, and you can embed them with UIViewControllerRepresentable.

                    Whichever you choose, keep row identity stable and avoid heavy work inside the row body. Most List slowdowns are caused by expensive formatting or image decoding in the view, not by the container.
                    """
                )
            ]
        ),
    ]
}
