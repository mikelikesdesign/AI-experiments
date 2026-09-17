// Run from the project directory:
// xcrun swiftc -parse-as-library "scroll options/StreamingChunk.swift" \
//   "scroll options/ChatThread.swift" "scroll options/ContentViewModel.swift" \
//   Tests/StreamingChecks.swift \
//   -o /tmp/scroll-options-streaming-checks && /tmp/scroll-options-streaming-checks
import Foundation

@main
struct StreamingChecks {
    @MainActor
    static func main() async throws {
        for source in ["", "  \n", "One word.", "Hello,  world!\n\nNext paragraph.\n",
                       "👨‍👩‍👧‍👦 café e\u{301}\t한글 日本語"] {
            let chunks = StreamingChunk.make(from: source)
            precondition(chunks.map(\.text).joined() == source, "Streaming must preserve exact Unicode and spacing")
        }

        let model = ContentViewModel()
        let original = model.turns
        precondition(original.count == 1)
        model.learnMoreContent()
        precondition(model.turns.count == 2)
        precondition(model.turns.first == original.first, "A follow-up must preserve the original exchange")
        precondition(model.turns.last?.question == "Add more details")
        let detailedTurnID = model.turns.last!.id
        precondition(model.isStreaming && !model.displayedText.isEmpty, "First word must appear immediately")
        try await Task.sleep(for: .milliseconds(180))
        model.stopStreaming()
        let partial = model.displayedText
        precondition(model.wasStopped && !model.isStreaming && partial == model.streamingText)
        try await Task.sleep(for: .milliseconds(250))
        precondition(model.displayedText == partial, "Cancelled work must not append more text")
        let stoppedHistory = model.turns

        model.learnMoreContent()
        precondition(Array(model.turns.prefix(2)) == stoppedHistory, "Stopped responses must stay in the chat")
        try await Task.sleep(for: .milliseconds(100))
        let beforeSimplify = model.turns
        model.simplifyContent()
        precondition(model.turns.count == 4)
        precondition(Array(model.turns.prefix(3)) == beforeSimplify,
                     "Simplify must append without altering earlier messages or their IDs")
        precondition(model.turns.last?.question == "Simplify")
        precondition(model.turns[1].id == detailedTurnID && model.turns[1].response == partial)
        let simplifiedTurnID = model.turns.last!.id
        precondition(!model.wasStopped)
        precondition(model.streamingLabel == "Simplifying…")
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while model.isStreaming && ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(100))
        }
        precondition(!model.isStreaming, "Simplified response must finish")
        precondition(model.content == model.streamingText)
        precondition(model.content.hasPrefix("UIKit is Apple’s toolkit"), "Replaced stream must not leak text")
        precondition(model.content.hasSuffix("adopt SwiftUI gradually."))
        precondition(model.turns.last?.id == simplifiedTurnID, "Streaming must keep the same message identity")
        precondition(model.turns.last?.response == model.content)
        precondition(Array(model.turns.prefix(3)) == beforeSimplify, "Only the latest response may stream")
        let complete = model.content
        model.stopStreaming()
        precondition(model.content == complete && !model.wasStopped, "Stopping completed work must be a no-op")
        let newThread = ContentViewModel(isNewThread: true)
        precondition(newThread.turns.isEmpty && model.turns.count == 4,
                     "A separate blank thread must have independent history")
        // Reset from populated, streaming, stopped, completed, and already-empty states.
        for state in ["populated", "streaming", "stopped", "completed", "empty"] {
            let resetModel = state == "completed" ? model : ContentViewModel(isNewThread: state == "empty")
            if state == "streaming" || state == "stopped" {
                resetModel.learnMoreContent()
                try await Task.sleep(for: .milliseconds(100))
                if state == "stopped" { resetModel.stopStreaming() }
            }
            let oldID = resetModel.responseID
            resetModel.startNewThread()
            precondition(resetModel.turns.isEmpty && resetModel.question == nil, state)
            precondition(resetModel.content.isEmpty && resetModel.streamingText.isEmpty, state)
            precondition(!resetModel.isStreaming && !resetModel.wasStopped, state)
            precondition(resetModel.streamingLabel.isEmpty && resetModel.responseID != oldID, state)
            for _ in 0..<5 { resetModel.startNewThread() }
            try await Task.sleep(for: .milliseconds(250))
            precondition(resetModel.turns.isEmpty && resetModel.displayedText.isEmpty,
                         "Repeated resets must stay blank; cancelled streaming must not revive: \(state)")
        }
        let resumed = ContentViewModel()
        resumed.learnMoreContent()
        resumed.startNewThread()
        resumed.simplifyContent()
        try await Task.sleep(for: .milliseconds(250))
        precondition(resumed.turns.count == 1 && resumed.question == "Simplify")
        precondition(resumed.displayedText.hasPrefix("UIKit is Apple’s"),
                     "An old stream must not append into work started after reset")
        resumed.stopStreaming()
        print("PASS: streaming, history, reset across all model states, repeated reset, and cancellation isolation")
    }
}
