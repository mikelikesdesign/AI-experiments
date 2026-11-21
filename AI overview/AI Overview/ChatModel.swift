import SwiftUI
import QuartzCore
import UIKit

/// Frame-rate independent exponential approach: 1 - e^(-dt*k).
@inline(__always) func approach(_ dt: Double, _ k: Double) -> Double { 1 - exp(-dt * k) }
@inline(__always) func clamp<T: Comparable>(_ v: T, _ lo: T, _ hi: T) -> T { min(hi, max(lo, v)) }
@inline(__always) func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }
@inline(__always) func smooth(_ t: CGFloat) -> CGFloat { let t = clamp(t, 0, 1); return t * t * (3 - 2 * t) }

// MARK: - Laid-out content (content coordinates: y grows down the whole conversation)

struct PlacedBlock {
    let block: TextBlock
    let origin: CGPoint
    let fontSize: CGFloat
}

struct PlacedMessage {
    let index: Int
    let role: Role
    let top: CGFloat
    let height: CGFloat
    let blocks: [PlacedBlock]
    let bubble: CGRect?
    /// Vertical centre of the assistant's meta line ("2 tools · 3 sources").
    let metaY: CGFloat
}

/// Where a trace is cited in the text.
struct Anchor {
    /// Citation marker, in content coordinates.
    let marker: CGRect
    /// The gap just under the marker's line, where the leader runs to the divider.
    let gapY: CGFloat
}

/// A card on the right-hand rail. Its y is in screen space and eases toward its
/// anchor, so while you scroll the cards trail a little and the connectors stretch.
struct Card {
    let key: String
    let message: Int
    let trace: String
    var y: CGFloat
    var appear: Double = 0
    var emph: Double = 0
    var pulse: Double = 1
    var visible = false
    var target: CGFloat = 0
    var anchorY: CGFloat = 0
}

struct CardLayout {
    var height: CGFloat
    var texts: [(block: TextBlock, origin: CGPoint)]
    var rule: CGRect?
}

@Observable
@MainActor
final class ChatModel {
    // MARK: Inputs

    private(set) var size: CGSize = .zero
    private(set) var scrollY: CGFloat = 0
    var scrollPosition = ScrollPosition(edge: .top)
    var draft = ""

    private(set) var messages: [Message] = ChatModel.numbered(Script.seed())

    /// Source numbers run on through the whole conversation (1, 2, 3, then 4, 5…), not per reply.
    private static func numbered(_ ms: [Message]) -> [Message] {
        var n = 1
        for m in ms where m.role == .assistant { n = m.numberSources(from: n) }
        return ms
    }

    // MARK: Debug split

    /// 0 = plain chat, 1 = split into "As said" | "As traced". Sprung, so it can overshoot a touch.
    private(set) var d: Double = 0
    private var dVelocity: Double = 0
    private(set) var dTarget: Double = 0
    /// Divider position as a fraction of the width once open.
    private(set) var split: Double = 0.5
    private var splitTarget: Double = 0.5
    private(set) var draggingDivider = false
    private(set) var dragY: CGFloat = 0
    private(set) var tagsY: CGFloat = 0

    var isDebug: Bool { dTarget > 0.5 }
    var isPad: Bool { size.width >= 700 }
    var dc: CGFloat { CGFloat(clamp(d, 0, 1)) }

    var dividerX: CGFloat { lerp(size.width + 2, size.width * CGFloat(split), CGFloat(d)) }
    /// Margin from the screen edges (header buttons, and the text column in the overview).
    var edgePad: CGFloat { isPad ? 28 : 20 }
    /// On wide screens (the open iPhone Duo, iPad) the chat keeps a comfortable line length
    /// and sits centred; opening the overview slides it into the left half.
    static let readingMax: CGFloat = 680
    private var restColumn: (left: CGFloat, right: CGFloat) {
        let w = min(size.width - 2 * edgePad, Self.readingMax)
        let l = (size.width - w) / 2
        return (l, l + w)
    }
    /// True when the screen is wider than the reading column (the open iPhone Duo, iPad).
    var isColumnCapped: Bool { size.width - 2 * edgePad > Self.readingMax }
    var colLeft: CGFloat { lerp(restColumn.left, edgePad, dc) }
    var colRight: CGFloat { lerp(restColumn.right, dividerX - (isPad ? 24 : 16), dc) }
    var bodySize: CGFloat { lerp(isPad ? 18 : 17, isPad ? 16 : 14, dc) }
    var railGap: CGFloat { isPad ? 44 : 28 }
    var railX: CGFloat { dividerX + railGap }
    var cardWidth: CGFloat { min(400, max(80, size.width * (1 - CGFloat(split)) - railGap - (isPad ? 20 : 12))) }

    static let headerH: CGFloat = 52
    static let topPad: CGFloat = 72
    static let bottomPad: CGFloat = 120
    /// Where the reading position is kept while the text re-flows.
    var readingY: CGFloat { max(Self.topPad, size.height * 0.4) }

    /// The selection line. It travels down the screen as you scroll, from just under the header
    /// at the top of the conversation to just above the bottom at the end, so every citation
    /// crosses it exactly once, in order, and the first and last ones can both be reached.
    private var focusTop: CGFloat { Self.topPad + 24 }
    private var focusSpan: CGFloat { max(0, size.height - 110 - focusTop) }
    private var maxScroll: CGFloat { max(1, contentHeight - size.height) }
    var focusY: CGFloat { focusTop + focusSpan * clamp(scrollY / maxScroll, 0, 1) }

    // MARK: Layout state

    private(set) var placed: [PlacedMessage] = []
    private(set) var anchors: [String: Anchor] = [:]
    /// Bottom of the conversation text, in content coordinates.
    private var textBottom: CGFloat = 0
    /// Bottom of the lowest card on the rail, in content coordinates. Cards can stack
    /// further down than the text ends, so the overview needs room to scroll to them.
    private var railBottom: CGFloat = 0
    var contentHeight: CGFloat {
        let rail = dc > 0.01 ? railBottom + 72 : 0
        // In the overview, leave room for the last citation to scroll up to the reading line.
        let overviewPad: CGFloat = 60
        return max(textBottom + lerp(Self.bottomPad, overviewPad, dc), rail)
    }
    private(set) var cards: [Card] = []
    private(set) var activeKey: String?
    private(set) var clock: Double = CACurrentMediaTime()

    private var blockCache: [String: TextBlock] = [:]
    private var cardCache: [String: CardLayout] = [:]
    private var layoutKey = ""
    private var following = false
    private var lastProgrammaticY: CGFloat = 0
    private var pinUntil: Double = 0
    /// Set when opening the overview picks the first card; cleared when the reader scrolls.
    private var pinned = false
    private var repickWhenSettled = false

    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private let ticker = UISelectionFeedbackGenerator()
    private let thump = UIImpactFeedbackGenerator(style: .soft)

    init() {}

    static func key(_ m: Int, _ t: String) -> String { "\(m).\(t)" }

    // MARK: - Events

    func layout(_ s: CGSize) {
        guard s != size, s.width > 0 else { return }
        let first = size == .zero
        size = s
        cardCache.removeAll()
        if first { tagsY = Self.headerH / 2 }
        relayout()
        wake()
    }

    func scrolled(to y: CGFloat) {
        guard abs(y - scrollY) > 0.01 else { return }
        if following, y < lastProgrammaticY - 30 { following = false }
        scrollY = y
        wake()
    }

    /// Once the reader drags the scroll view, the selection goes back to following the reading line.
    func userBeganScrolling() {
        pinned = false
        repickWhenSettled = false
    }

    func toggleDebug() {
        setDebug(!isDebug)
    }

    func setDebug(_ on: Bool) {
        dTarget = on ? 1 : 0
        if on {
            split = clamp(split, isPad ? 0.34 : 0.42, 0.72); splitTarget = split
            // Hold the selection until the column has finished narrowing, then pick once,
            // so it never jumps from one card to another while the overview opens.
            if activeKey != nil { activate(nil) }
            pinned = true
            repickWhenSettled = true
        } else {
            pinned = false
            repickWhenSettled = false
        }
        thump.impactOccurred(intensity: 0.7)
        wake()
    }

    /// Drag on the divider (or in from the right edge). Left of ~72% sets the split;
    /// further right pulls the whole rail away, and letting go past halfway closes it.
    func dragDivider(to p: CGPoint) {
        if !draggingDivider { draggingDivider = true; ticker.prepare() }
        dragY = p.y
        let w = size.width
        let x = clamp(p.x, w * (isPad ? 0.34 : 0.42), w)
        let maxSplit: CGFloat = 0.72
        if x <= w * maxSplit {
            splitTarget = Double(x / w)
            dTarget = 1
        } else {
            splitTarget = Double(maxSplit)
            dTarget = Double((w - x) / (w * (1 - maxSplit)))
        }
        wake()
    }

    func endDividerDrag() {
        draggingDivider = false
        let open = dTarget > 0.5
        dTarget = open ? 1 : 0
        if !open { splitTarget = 0.5 }
        thump.impactOccurred(intensity: 0.6)
        wake()
    }

    func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, messages.last?.isComplete ?? true else { return }
        draft = ""
        let user = Message(id: messages.count, role: .user, text: text)
        let reply = Script.reply(to: text, id: messages.count + 1)
        reply.startedAt = CACurrentMediaTime()
        messages.append(user)
        messages.append(reply)
        messages = Self.numbered(messages)
        relayout()
        following = true
        let bottom = max(0, contentHeight - size.height)
        lastProgrammaticY = bottom
        withAnimation(.smooth(duration: 0.45)) { scrollPosition.scrollTo(y: bottom) }
        wake()
    }

    /// Taps arrive in content coordinates.
    func tap(_ p: CGPoint) {
        let s = CGPoint(x: p.x, y: p.y - scrollY)
        // The header and the input bar sit over the conversation; never let taps there fall through.
        guard s.y > Self.headerH, s.y < size.height - 76 else { return }

        // A card on the rail.
        if dc > 0.5, s.x > dividerX {
            for c in cards where c.visible {
                let h = cardLayout(c).height
                if CGRect(x: railX, y: c.y, width: cardWidth, height: h).contains(s) { focus(c.key); return }
            }
            return
        }
        // A citation marker in the text.
        for (key, a) in anchors where a.marker.insetBy(dx: -10, dy: -10).contains(p) {
            if !isDebug { setDebug(true) }
            focus(key)
            return
        }
    }

    /// Opening the overview starts on the first card whose citation is on screen.
    /// Scripted walkthrough for recording (launch with `-demo`): pause, open the overview,
    /// step through every citation and tool call in reading order, pause, close, pause.
    func runDemo() {
        Task { @MainActor in
            func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
            await wait(2)
            setDebug(true)
            await wait(1.6)
            let order = cards
                .filter(\.visible)
                .sorted { (anchorContentY($0), $0.message) < (anchorContentY($1), $1.message) }
                .map(\.key)
            for key in order where key != activeKey {
                focus(key)
                await wait(1.25)
            }
            await wait(2)
            setDebug(false)
            await wait(2)
        }
    }

    /// The topmost card on the rail that sits within the screen.
    private func selectFirstOnScreen() {
        let first = cards
            .filter { $0.visible && $0.target >= Self.topPad - 16 && $0.target < size.height - 120 }
            .min { $0.target < $1.target }
        guard let key = first?.key else { return }
        if activeKey != key { activate(key) }
        pinned = true
        lastProgrammaticY = scrollY
    }

    private func focus(_ key: String) {
        guard let c = cards.first(where: { $0.key == key }) else { return }
        if activeKey != key { activate(key) }
        pinUntil = clock + 0.9
        pinned = true
        let anchorContent = (anchors[key]?.gapY ?? placed.first { $0.index == c.message }?.metaY ?? 0)
        // Solve for the scroll offset that puts this anchor on the travelling selection line.
        var target = (anchorContent - focusTop) / (1 + focusSpan / maxScroll)
        // …but never leave the card itself hanging off the bottom of the screen.
        let cardBottom = c.target + scrollY + cardLayout(c).height
        target = max(target, cardBottom + 56 - size.height)
        target = clamp(target, 0, max(0, contentHeight - size.height))
        lastProgrammaticY = target
        withAnimation(.smooth(duration: 0.55)) { scrollPosition.scrollTo(y: target) }
        wake()
    }

    private func activate(_ key: String?) {
        activeKey = key
        if let key, let i = cards.firstIndex(where: { $0.key == key }) {
            cards[i].pulse = 0
            if dc > 0.5 { ticker.selectionChanged(); ticker.prepare() }
        }
    }

    // MARK: - Layout

    private func block(_ m: Message, _ pi: Int, visible: Int, width: CGFloat, size fs: CGFloat) -> TextBlock {
        let dq = (dc * 50).rounded() / 50
        let key = "\(m.id).\(pi)|\(visible)|\((width * 2).rounded())|\((fs * 20).rounded())|\(dq)"
        if let b = blockCache[key] { return b }
        if blockCache.count > 800 { blockCache.removeAll(keepingCapacity: true) }
        let b = TextLayout.paragraph(m.paragraphs[pi], visible: visible, width: width, size: fs, debug: dq) {
            m.trace($0)?.isTool ?? false
        }
        blockCache[key] = b
        return b
    }

    /// Re-flows the whole conversation at the current column width and type size.
    private func relayout() {
        guard size.width > 0 else { return }
        var y = Self.topPad
        var out: [PlacedMessage] = []
        var anchors: [String: Anchor] = [:]
        let left = colLeft, right = colRight, colW = right - left
        let fs = bodySize

        for (i, m) in messages.enumerated() {
            var blocks: [PlacedBlock] = []
            let top = y
            var offset = 0
            var bubble: CGRect?
            var metaY = top
            if m.role == .user {
                let ufs = fs - 1
                let maxW = colW * 0.82 - 28
                var by: CGFloat = 9
                var bw: CGFloat = 0
                var inner: [(TextBlock, CGFloat)] = []
                for pi in m.paragraphs.indices {
                    let b = block(m, pi, visible: m.paragraphs[pi].length, width: maxW, size: ufs)
                    inner.append((b, by))
                    by += b.height
                    bw = max(bw, b.width)
                }
                let rect = CGRect(x: right - bw - 28, y: top, width: bw + 28, height: by + 9)
                bubble = rect
                blocks = inner.map { PlacedBlock(block: $0.0, origin: CGPoint(x: rect.minX + 14, y: top + $0.1), fontSize: ufs) }
                y = rect.maxY + 26
            } else {
                // The meta line ("Searching the web…", or timing in the overview) only takes room when it shows.
                let metaH: CGFloat = m.isComplete ? 0 : 26
                metaY = top + metaH * 0.35
                y = top + metaH
                let gap = fs * 0.72
                for (pi, p) in m.paragraphs.enumerated() {
                    let vis = clamp(Int(m.revealed) - offset, 0, p.length)
                    offset += p.length
                    guard vis > 0 else { break }
                    let b = block(m, pi, visible: vis, width: colW, size: fs)
                    let origin = CGPoint(x: left, y: y)
                    blocks.append(PlacedBlock(block: b, origin: origin, fontSize: fs))
                    for mk in b.markers where anchors[Self.key(i, mk.id)] == nil {
                        anchors[Self.key(i, mk.id)] = Anchor(
                            marker: mk.rect.offsetBy(dx: origin.x, dy: origin.y),
                            gapY: origin.y + b.lineBottom(mk.line))
                    }
                    y += b.height + gap
                }
                y += 22
            }
            out.append(PlacedMessage(index: i, role: m.role, top: top, height: y - top,
                                     blocks: blocks, bubble: bubble, metaY: metaY))
        }
        placed = out
        self.anchors = anchors
        textBottom = y
    }

    /// The message (and how far into it) sitting under the focus line, so a re-flow can keep it there.
    private func readingPosition() -> (Int, CGFloat)? {
        // At the top of the conversation, stay at the top so the first question stays in view.
        guard scrollY > 4 else { return nil }
        let y = scrollY + readingY
        guard let pm = placed.last(where: { $0.top <= y }) ?? placed.first else { return nil }
        return (pm.index, clamp((y - pm.top) / max(1, pm.height), 0, 1))
    }

    // MARK: - Cards

    func trace(of c: Card) -> (Message, Trace)? {
        let m = messages[c.message]
        guard let t = m.trace(c.trace) else { return nil }
        return (m, t)
    }

    func toolDone(_ m: Message, _ t: Trace) -> Bool {
        guard let w = m.toolWindow(t.id) else { return true }
        return m.isComplete || clock >= w.end
    }

    func cardLayout(_ c: Card) -> CardLayout {
        guard let (m, t) = trace(of: c) else { return CardLayout(height: 0, texts: []) }
        let done = !t.isTool || toolDone(m, t)
        let w = cardWidth
        let key = "\(c.key)|\((w * 2).rounded())|\(done)"
        if let l = cardCache[key] { return l }
        let pad: CGFloat = 11
        let inner = w - pad * 2
        var texts: [(TextBlock, CGPoint)] = []
        var y: CGFloat = 30
        var rule: CGRect?
        let tf = Typeface.shared

        switch t.kind {
        case let .tool(doing, finished, detail, result):
            // Plain sentences, no code: what it did, what with, what came back.
            let title = done ? finished : doing + "…"
            let hb = TextLayout.plain(title, font: tf.font(size: 12.5, weight: 600), color: Ink.ink(0.92),
                                      width: inner - 15, lineHeight: 16, maxLines: 2)
            texts.append((hb, CGPoint(x: pad + 15, y: 8)))
            y = 8 + hb.height + 6
            let db = TextLayout.plain(detail, font: tf.font(size: 11.5, weight: 400), color: Ink.ink(0.6),
                                      width: inner, lineHeight: 15.5, maxLines: 3)
            texts.append((db, CGPoint(x: pad, y: y)))
            y += db.height + 4
            if done {
                let rb = TextLayout.plain("→ " + result, font: tf.font(size: 11.5, weight: 540), color: Ink.ink(0.78),
                                          width: inner, lineHeight: 16, maxLines: 3)
                texts.append((rb, CGPoint(x: pad, y: y)))
                y += rb.height + 2
            } else {
                y += 6
            }
        case let .source(title, domain, snippet):
            texts.append((TextLayout.plain(domain, font: tf.font(size: 10.5, weight: 480), color: Ink.ink(0.5),
                                           width: inner - 20, lineHeight: 16, maxLines: 1),
                          CGPoint(x: pad + 19, y: 8)))
            let tb = TextLayout.plain(title, font: tf.font(size: 12.5, weight: 600), color: Ink.ink(0.92),
                                      width: inner, lineHeight: 16.5, maxLines: 2)
            texts.append((tb, CGPoint(x: pad, y: y)))
            y += tb.height + 6
            let sb = TextLayout.plain(snippet, font: tf.font(size: 11.5, weight: 400), color: Ink.ink(0.6),
                                      width: inner - 10, lineHeight: 15.5, maxLines: 4)
            texts.append((sb, CGPoint(x: pad + 10, y: y)))
            rule = CGRect(x: pad, y: y + 2, width: 1.5, height: sb.height - 4)
            y += sb.height + 2
        }
        let l = CardLayout(height: y + pad - 2, texts: texts, rule: rule)
        if cardCache.count > 400 { cardCache.removeAll(keepingCapacity: true) }
        cardCache[key] = l
        return l
    }

    private func traceVisible(_ m: Message, _ t: Trace) -> Bool {
        if m.isComplete { return true }
        if t.isTool { return clock >= (m.toolWindow(t.id)?.start ?? 0) }
        return m.markerRevealed(t.id)
    }

    /// The point on the divider a trace's connector leaves from, in content coordinates.
    func anchorContentY(_ c: Card) -> CGFloat {
        if let a = anchors[c.key] { return a.gapY }
        return placed.first { $0.index == c.message }?.metaY ?? 0
    }

    private func updateCards(_ dt: Double) {
        // Make sure every trace of every reply has a card.
        var existing = Set(cards.map(\.key))
        for (i, m) in messages.enumerated() where m.role == .assistant {
            for t in m.traces where !existing.contains(Self.key(i, t.id)) {
                cards.append(Card(key: Self.key(i, t.id), message: i, trace: t.id, y: 0))
                existing.insert(Self.key(i, t.id))
            }
        }

        // Target positions: each card's header lines up with its anchor; stack downward on collision.
        var order: [Int] = []
        for i in cards.indices {
            let c = cards[i]
            guard let (m, t) = trace(of: c) else { continue }
            let vis = traceVisible(m, t)
            if vis && !cards[i].visible {
                cards[i].visible = true
                cards[i].y = anchorContentY(c) - scrollY - 15
            }
            cards[i].visible = vis
            if vis {
                cards[i].anchorY = anchorContentY(c) - scrollY
                order.append(i)
            }
        }
        order.sort { (cards[$0].anchorY, $0) < (cards[$1].anchorY, $1) }
        var floor = -CGFloat.infinity
        railBottom = 0
        var rank: [Int: Int] = [:]
        for i in order {
            let h = cardLayout(cards[i]).height
            let t = max(cards[i].anchorY - 15, floor)
            cards[i].target = t
            floor = t + h + 10
            railBottom = max(railBottom, t + scrollY + h)
            rank[cards[i].message, default: 0] += 1
            // Later cards in a reply follow a little more lazily, so a scroll ripples down the chain.
            let k = max(7.0, 15.0 - 2.0 * Double(rank[cards[i].message]! - 1))
            cards[i].y += (t - cards[i].y) * CGFloat(approach(dt, k))
            cards[i].appear += (1 - cards[i].appear) * approach(dt, 9)
        }

        // Active trace: the anchor nearest the focus line, with a little hysteresis.
        if clock > pinUntil && !pinned {
            let band = (Self.topPad - 10)...max(Self.topPad, size.height - 90)
            var best: (String, CGFloat)?
            for i in order where band.contains(cards[i].anchorY) {
                let dist = abs(cards[i].anchorY - focusY) - (cards[i].key == activeKey ? 10 : 0)
                if dist < (best?.1 ?? .infinity) { best = (cards[i].key, dist) }
            }
            if best?.0 != activeKey { activate(best?.0) }
        }

        for i in cards.indices {
            let on: Double = cards[i].key == activeKey ? 1 : 0
            cards[i].emph += (on - cards[i].emph) * approach(dt, on > 0 ? 9 : 14)
            if cards[i].pulse < 1 { cards[i].pulse = min(1, cards[i].pulse + dt / 0.7) }
        }
    }

    // MARK: - Frame loop

    private func wake() {
        guard link == nil else { return }
        let l = CADisplayLink(target: Proxy(self), selector: #selector(Proxy.step(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        l.add(to: .main, forMode: .common)
        link = l
        lastTime = 0
    }

    fileprivate func step(_ l: CADisplayLink) {
        let now = l.targetTimestamp
        let dt = lastTime == 0 ? 1.0 / 60 : min(0.05, now - lastTime)
        lastTime = now
        clock = now
        guard size.width > 0 else { return }

        // Debug progress: a spring that eases out of rest and settles with a hint of overshoot.
        let period = draggingDivider ? 0.16 : 0.52
        let omega = 2 * Double.pi / period, zeta = draggingDivider ? 1.0 : 0.8
        let steps = max(1, Int((dt * 240).rounded(.up)))
        let sub = dt / Double(steps)
        for _ in 0..<steps {
            let a = omega * omega * (dTarget - d) - 2 * zeta * omega * dVelocity
            dVelocity += a * sub
            d += dVelocity * sub
        }
        if abs(dTarget - d) < 0.0005, abs(dVelocity) < 0.01 { d = dTarget; dVelocity = 0 }
        var moving = d != dTarget

        split += (splitTarget - split) * approach(dt, draggingDivider ? 22 : 12)
        if abs(splitTarget - split) < 0.0002 { split = splitTarget }
        moving = moving || split != splitTarget

        // Stream replies.
        var busy = false
        for m in messages where m.role == .assistant && !m.isComplete {
            busy = true
            if now >= m.textStart {
                m.revealed = min(Double(m.totalLength), (now - m.textStart) * Message.charsPerSecond)
            }
        }

        // Re-flow when the column or type size changes, keeping the reading position under the focus line.
        let key = "\((colRight * 4).rounded())|\((bodySize * 40).rounded())|\((dc * 50).rounded())|\(size.width)"
        let reflow = key != layoutKey
        let reading = reflow && !following ? readingPosition() : nil
        if reflow || busy { relayout() }
        layoutKey = key
        let bottom = max(0, contentHeight - size.height)
        if following {
            if busy || reflow { setScroll(bottom) }
            if !busy && abs(scrollY - bottom) < 1 { following = false }
        } else if let (i, f) = reading, contentHeight > size.height, let pm = placed.first(where: { $0.index == i }) {
            setScroll(clamp(pm.top + f * pm.height - readingY, 0, bottom))
        }

        if repickWhenSettled, abs(d - dTarget) < 0.01, abs(dVelocity) < 0.2 {
            repickWhenSettled = false
            selectFirstOnScreen()
        }
        updateCards(dt)
        for c in cards where c.visible {
            if abs(c.target - c.y) > 0.2 || c.appear < 0.995 || abs(c.emph - (c.key == activeKey ? 1 : 0)) > 0.005 || c.pulse < 1 {
                moving = true
                break
            }
        }

        // Tags ride the divider: they follow the finger while it drags, then settle back in the header.
        let tagTarget = draggingDivider ? clamp(dragY - 20, Self.headerH / 2, size.height - 120) : Self.headerH / 2
        tagsY += (tagTarget - tagsY) * CGFloat(approach(dt, draggingDivider ? 18 : 8))
        moving = moving || abs(tagTarget - tagsY) > 0.1

        if !moving && !busy && !draggingDivider {
            link?.invalidate()
            link = nil
        }
    }

    private func setScroll(_ y: CGFloat) {
        guard abs(y - scrollY) > 0.25 else { return }
        lastProgrammaticY = y
        scrollY = y
        scrollPosition.scrollTo(y: y)
    }

    private final class Proxy: NSObject {
        weak var model: ChatModel?
        init(_ m: ChatModel) { model = m }
        @MainActor @objc func step(_ l: CADisplayLink) {
            guard let model else { l.invalidate(); return }
            model.step(l)
        }
    }
}
