import SwiftUI

@main
struct AIOverviewApp: App {
    /// Launched with `-demo` for screen recordings: also keep the home indicator out of frame.
    private let isDemo = ProcessInfo.processInfo.arguments.contains("-demo")

    var body: some Scene {
        WindowGroup {
            ChatView()
                .persistentSystemOverlays(isDemo ? .hidden : .automatic)
        }
    }
}
