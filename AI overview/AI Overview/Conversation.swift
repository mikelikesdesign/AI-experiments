import Foundation

/// Something the reply leaned on: a tool call it made, or a source it read.
struct Trace: Identifiable {
    enum Kind {
        case tool(doing: String, done: String, detail: String, result: String)
        case source(title: String, domain: String, snippet: String)
    }

    let id: String
    let kind: Kind
    /// Tool latency in milliseconds (0 for sources).
    var ms: Int = 0
    /// Display number for sources (1, 2, 3…); 0 for tools.
    var number: Int = 0

    var isTool: Bool { if case .tool = kind { true } else { false } }
}

/// One paragraph of message text, in UTF-16 units so it maps straight onto CoreText.
/// Every cited span is followed by a single U+FFFC marker that becomes the inline citation.
struct Paragraph {
    var text: NSString
    var spans: [(range: NSRange, id: String)]
    var markers: [(index: Int, id: String)]
    var length: Int { text.length }

    static let markerChar = "\u{FFFC}"

    /// Parses `plain text [[a cited span|s1]] more text`.
    init(_ raw: String) {
        let out = NSMutableString()
        var spans: [(NSRange, String)] = []
        var markers: [(Int, String)] = []
        var rest = Substring(raw)
        while let open = rest.range(of: "[[") {
            out.append(String(rest[..<open.lowerBound]))
            guard let close = rest.range(of: "]]", range: open.upperBound..<rest.endIndex),
                  let bar = rest.range(of: "|", range: open.upperBound..<close.lowerBound)
            else { break }
            let span = String(rest[open.upperBound..<bar.lowerBound])
            let id = String(rest[bar.upperBound..<close.lowerBound])
            let start = out.length
            out.append(span)
            spans.append((NSRange(location: start, length: out.length - start), id))
            // A word joiner keeps the marker on the same line as the word it cites.
            out.append("\u{2060}")
            markers.append((out.length, id))
            out.append(Self.markerChar)
            rest = rest[close.upperBound...]
        }
        out.append(String(rest))
        text = out
        self.spans = spans
        self.markers = markers
    }
}

enum Role { case user, assistant }

/// A message in the conversation. Assistant replies play out over time:
/// tool calls run one after another, then the text streams in.
@MainActor
final class Message: Identifiable {
    let id: Int
    let role: Role
    let paragraphs: [Paragraph]
    private(set) var traces: [Trace]
    let totalLength: Int
    let tokens: Int

    /// Model-clock time the reply started; tools are scheduled from here.
    var startedAt: Double = -.infinity
    /// UTF-16 units of text revealed so far.
    var revealed: Double

    init(id: Int, role: Role, text: String, traces: [Trace] = [], live: Bool = false) {
        self.id = id
        self.role = role
        paragraphs = text.components(separatedBy: "\n\n").map(Paragraph.init)
        var n = 0
        self.traces = traces.map { t in
            var t = t
            if !t.isTool { n += 1; t.number = n }
            return t
        }
        totalLength = paragraphs.reduce(0) { $0 + $1.length }
        tokens = Int(Double(text.count) / 3.7) + 40 * traces.filter(\.isTool).count
        revealed = live ? 0 : Double(totalLength)
    }

    func trace(_ id: String) -> Trace? { traces.first { $0.id == id } }

    /// Gives this reply's sources display numbers starting at `first`; returns the next free number.
    @discardableResult
    func numberSources(from first: Int) -> Int {
        var n = first
        for i in traces.indices where !traces[i].isTool {
            traces[i].number = n
            n += 1
        }
        return n
    }

    // MARK: Timeline

    static let toolGap = 0.18
    static let charsPerSecond = 260.0

    private var tools: [Trace] { traces.filter(\.isTool) }

    /// Start and end (model clock) of each tool call, back to back.
    func toolWindow(_ id: String) -> (start: Double, end: Double)? {
        var t = startedAt + 0.35
        for tool in tools {
            let end = t + Double(tool.ms) / 1000
            if tool.id == id { return (t, end) }
            t = end + Self.toolGap
        }
        return nil
    }

    /// When the text starts streaming.
    var textStart: Double {
        guard let last = tools.last, let w = toolWindow(last.id) else { return startedAt + 0.35 }
        return w.end + 0.3
    }

    var seconds: Double {
        let toolTime = tools.reduce(0.35) { $0 + Double($1.ms) / 1000 + Self.toolGap }
        return toolTime + 0.3 + Double(totalLength) / Self.charsPerSecond
    }

    var isComplete: Bool { revealed >= Double(totalLength) }

    /// Tool currently running at `now`, if any.
    func runningTool(at now: Double) -> Trace? {
        tools.first { t in
            guard let w = toolWindow(t.id) else { return false }
            return now >= w.start && now < w.end
        }
    }

    /// Whether the marker for `id` has streamed in.
    func markerRevealed(_ id: String) -> Bool {
        var offset = 0
        for p in paragraphs {
            if let m = p.markers.first(where: { $0.id == id }) {
                return revealed > Double(offset + m.index)
            }
            offset += p.length
        }
        return false
    }
}


// MARK: - Seed conversation & scripted replies (learning UIKit)

@MainActor
enum Script {
    static func seed() -> [Message] {
        [
            Message(id: 0, role: .user, text: "When does layoutSubviews actually get called in UIKit?"),
            Message(id: 1, role: .assistant, text: """
                Not when you call it yourself. [[UIKit calls layoutSubviews during the layout pass, once per run-loop turn, for every view marked as needing layout|s1]]. You mark a view with setNeedsLayout(), and [[several calls in the same turn collapse into a single pass|t3]].

                [[If you need layout to happen right now, say before reading a frame, call layoutIfNeeded()|s2]]. It runs any pending layout immediately, top-down from that view.

                UIKit also marks views for you: [[changing a view’s bounds size, adding or removing a subview, and updating Auto Layout constraints all trigger it|s3]]. [[Your project overrides layoutSubviews in some view classes|t2]].
                """, traces: [
                    Trace(id: "t1", kind: .tool(doing: "Searching the web", done: "Searched the web", detail: "for “when is layoutSubviews called”", result: "Found 5 articles"), ms: 620),
                    Trace(id: "t2", kind: .tool(doing: "Searching your project", done: "Searched your project", detail: "for views that override layoutSubviews", result: "Found FeedCell, AvatarView, BadgeView and ChartView"), ms: 180),
                    Trace(id: "t3", kind: .tool(doing: "Running a quick test", done: "Ran a quick test", detail: "Called setNeedsLayout() three times in one turn", result: "Layout ran once"), ms: 860),
                    Trace(id: "s1", kind: .source(title: "The layout pass, explained", domain: "layoutpass.dev", snippet: "Views marked with setNeedsLayout are laid out together on the next update cycle, not at the moment you mark them.")),
                    Trace(id: "s2", kind: .source(title: "layoutIfNeeded vs. setNeedsLayout", domain: "runloop.notes", snippet: "layoutIfNeeded lays out the receiver and its subviews immediately if an update is pending; otherwise it does nothing.")),
                    Trace(id: "s3", kind: .source(title: "What invalidates layout", domain: "viewcycle.io", snippet: "Bounds size changes, subview changes and constraint updates all mark a view as needing layout.")),
                ]),
            Message(id: 2, role: .user, text: "How is that different from viewDidLayoutSubviews?"),
            Message(id: 3, role: .assistant, text: """
                It’s the view controller’s side of the same pass. [[viewDidLayoutSubviews runs right after the controller’s root view finishes its own layoutSubviews|s1]], so the root view’s bounds and its direct subviews are settled by then.

                [[It can run many times: on rotation, on size-class changes, even when the keyboard appears|s2]], so keep the work there cheap and repeatable. [[Your FeedViewController adds a gradient layer there on every call|t1]]. Create it once in viewDidLoad and only update its frame here.
                """, traces: [
                    Trace(id: "t1", kind: .tool(doing: "Reading FeedViewController", done: "Read FeedViewController", detail: "Looked at its viewDidLayoutSubviews", result: "Adds a gradient layer on every call"), ms: 90),
                    Trace(id: "s1", kind: .source(title: "The view controller lifecycle", domain: "viewcycle.io", snippet: "viewDidLayoutSubviews is called after the view controller’s view has laid out its subviews.")),
                    Trace(id: "s2", kind: .source(title: "Layout callbacks you can’t count on", domain: "layoutpass.dev", snippet: "Expect layout callbacks to fire repeatedly. Anything that adds subviews or layers there will pile up.")),
                ]),
        ]
    }

    private static var turn = 0

    /// A canned reply shaped around whatever was asked. Nothing here calls a model.
    static func reply(to question: String, id: Int) -> Message {
        let q = String(question.filter { !"[]|".contains($0) }.prefix(56))
        defer { turn += 1 }
        if turn % 2 == 0 {
            return Message(id: id, role: .assistant, text: """
                Here’s how I’d approach “\(q)” in UIKit. [[Most UIKit questions come down to who owns the view, and when in the run loop the work happens|s1]], which matches [[the guide I read through|t2]].

                [[Start from the smallest reproduction you can, a single view controller, then add pieces back|s2]]. This is a scripted demo reply, so treat the specifics as placeholders.
                """, traces: [
                    Trace(id: "t1", kind: .tool(doing: "Searching the web", done: "Searched the web", detail: "for “UIKit \(q)”", result: "Found 6 articles"), ms: 720),
                    Trace(id: "t2", kind: .tool(doing: "Reading a guide", done: "Read a guide", detail: "“Ownership and timing in UIKit” on layoutpass.dev", result: "Read it in full"), ms: 560),
                    Trace(id: "s1", kind: .source(title: "Ownership and timing in UIKit", domain: "layoutpass.dev", snippet: "Ask two questions: which object owns this view, and which pass of the run loop changes it?")),
                    Trace(id: "s2", kind: .source(title: "Debugging by subtraction", domain: "runloop.notes", snippet: "Strip a screen down to one view controller and add things back until the bug returns.")),
                ], live: true)
        } else {
            return Message(id: id, role: .assistant, text: """
                [[I searched your project first|t1]] and found nothing matching “\(q)”, so this comes from general sources.

                [[In UIKit, prefer changing state and letting the next layout or display pass pick it up, rather than forcing the work immediately|s1]]. [[At 60 Hz each frame gets about 16.7 ms|t2]], so keep main-thread work well under that. These are scripted demo replies, so this one is a placeholder too.
                """, traces: [
                    Trace(id: "t1", kind: .tool(doing: "Searching your project", done: "Searched your project", detail: "for “\(q)”", result: "Nothing matched"), ms: 280),
                    Trace(id: "t2", kind: .tool(doing: "Working out the frame budget", done: "Worked out the frame budget", detail: "One second shared across 60 frames", result: "About 16.7 ms per frame"), ms: 30),
                    Trace(id: "s1", kind: .source(title: "Let the run loop do it", domain: "runloop.notes", snippet: "setNeedsLayout and setNeedsDisplay batch work into the next update cycle, which is almost always cheaper.")),
                ], live: true)
        }
    }
}
