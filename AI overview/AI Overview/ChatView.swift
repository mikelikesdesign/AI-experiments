import SwiftUI

// MARK: - Palette (ink on paper, one spot colour, carried over from the scanner)

private enum Palette {
    static let ink = Color(Ink.ink)
    static let paper = Color(Ink.paper)
    static let spot = Color(Ink.spot)
}

private let labelFont = Font(Typeface.shared.uiFont(size: 11, weight: 500))
private let metaFont = Font(Typeface.shared.uiFont(size: 11.5, weight: 480))
private let inputFont = Font(Typeface.shared.uiFont(size: 16, weight: 420))

// MARK: - View

struct ChatView: View {
    @State private var model = ChatModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack(alignment: .topLeading) {
                ScrollView {
                    Color.clear
                        .frame(width: size.width, height: max(model.contentHeight, size.height))
                        .contentShape(Rectangle())
                        .onTapGesture(coordinateSpace: .local) { p in
                            inputFocused = false
                            model.tap(p)
                        }
                }
                .scrollPosition($model.scrollPosition)
                .onScrollGeometryChange(for: CGFloat.self) { g in
                    g.contentOffset.y + g.contentInsets.top
                } action: { _, y in
                    model.scrolled(to: y)
                }
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting { model.userBeganScrolling() }
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)

                Canvas(rendersAsynchronously: false) { ctx, size in
                    draw(&ctx, size)
                }
                .allowsHitTesting(false)
                // Draw on down through the home-indicator area, so content shows there once the input is gone.
                .ignoresSafeArea(.container, edges: .bottom)

                dividerBleed(size, geo.safeAreaInsets)
                dividerHandle(size)
                header(size)
                inputBar(size)
            }
            .coordinateSpace(.named("root"))
            .onAppear {
                model.layout(size)
                if ProcessInfo.processInfo.arguments.contains("-demo") { model.runDemo() }
            }
            .onChange(of: size) { _, s in model.layout(s) }
        }
        .background(Palette.paper.ignoresSafeArea())
        .preferredColorScheme(.light)
    }

    // MARK: Chrome

    private func header(_ size: CGSize) -> some View {
        HStack {
            // Placeholder menu button: no action yet.
            Button {} label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.ink.opacity(0.75))
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Palette.ink.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")
            Spacer()
            Button {
                inputFocused = false
                withAnimation(.snappy(duration: 0.3)) { model.toggleDebug() }
            } label: {
                Text("Overview")
                .font(labelFont)
                .foregroundStyle(model.isDebug ? Palette.paper : Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 28)
                .background(Capsule().fill(model.isDebug ? Palette.spot : Palette.ink.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.isDebug ? "Hide overview" : "Show overview")
        }
        .padding(.horizontal, model.edgePad)
        .frame(width: size.width, height: ChatModel.headerH)
    }

    private func inputBar(_ size: CGSize) -> some View {
        let canSend = !model.draft.trimmingCharacters(in: .whitespaces).isEmpty
        return VStack {
            Spacer()
            HStack(spacing: 8) {
                Menu {
                    Button("Photo Library", systemImage: "photo.on.rectangle") {}
                    Button("Camera", systemImage: "camera") {}
                    Button("Files", systemImage: "folder") {}
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.ink.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Palette.spot.opacity(0.08)))
                        .overlay(Circle().stroke(Palette.ink.opacity(0.1), lineWidth: 1))
                }
                .accessibilityLabel("Add attachment")
                TextField("Ask anything…", text: $model.draft)
                    .font(inputFont)
                    .foregroundStyle(Palette.ink)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit { model.send() }
                Button { model.send() } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Palette.paper)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(canSend ? Palette.ink : Palette.ink.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
            .padding(.leading, 6)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.paper)
                    .stroke(Palette.ink.opacity(0.12), lineWidth: 1)
                    .shadow(color: Palette.ink.opacity(0.06), radius: 14, y: 4))
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .onTapGesture { inputFocused = true }
            // On wide screens the input is a compact 500pt field centred under the text.
            .frame(width: inputWidth(size))
            .padding(.leading, (size.width - inputWidth(size)) / 2)
            .padding(.bottom, 10)
            // The input slides away while the overview is open, and back when it closes.
            .offset(y: 140 * model.dc)
            .opacity(Double(1 - 0.5 * model.dc))
            .allowsHitTesting(model.dc < 0.5)
        }
        .frame(width: size.width, height: size.height, alignment: .leading)
    }

    /// The canvas lives inside the safe area; these carry the divider on through the status bar
    /// so it runs the full height of the screen (the canvas already reaches the bottom edge).
    private func dividerBleed(_ size: CGSize, _ insets: EdgeInsets) -> some View {
        let w: CGFloat = model.draggingDivider ? 1.5 : 1
        let x = model.dividerX - w / 2
        let color = Palette.ink.opacity(Double(model.dc))
        return ZStack(alignment: .topLeading) {
            Rectangle().fill(color)
                .frame(width: w, height: insets.top)
                .offset(x: x, y: -insets.top)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func inputWidth(_ size: CGSize) -> CGFloat {
        let full = size.width - 2 * model.colLeft + 8
        return model.isColumnCapped ? min(500, full) : full
    }

    /// The divider is draggable, like the scanner's scan line. When debug is closed,
    /// a thin strip at the right edge lets you pull it in.
    private func dividerHandle(_ size: CGSize) -> some View {
        let open = model.dc > 0.5 || model.draggingDivider
        let x = open ? model.dividerX : size.width - 7
        let top = ChatModel.headerH
        let h = max(0, size.height - top - 80)
        return Color.clear
            .frame(width: open ? 26 : 14, height: h)
            .contentShape(Rectangle())
            .position(x: x, y: top + h / 2)
            .gesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("root"))
                    .onChanged { v in model.dragDivider(to: v.location) }
                    .onEnded { _ in model.endDividerDrag() })
            .accessibilityHidden(true)
    }

    // MARK: - Drawing

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize) {
        let m = model
        guard m.size.width > 0 else { return }
        let ink = Palette.ink, paper = Palette.paper, spot = Palette.spot
        let W = size.width, H = size.height
        let dc = m.dc
        let sy = m.scrollY
        let dx = m.dividerX
        let active = m.activeKey
        let activeEmph = CGFloat(m.cards.first { $0.key == active }?.emph ?? 0)

        // Blueprint grid on the traced side only, like the scanner's "As drawn" half.
        if dc > 0.005 {
            var g = ctx
            g.clip(to: Path(CGRect(x: dx, y: 0, width: max(0, W - dx), height: H)))
            g.opacity = Double(dc)
            grid(&g, size)
        }

        // MARK: As said: the conversation.
        let onScreen = m.placed.filter { $0.top - sy < H + 40 && $0.top + $0.height - sy > -40 }
        for pm in onScreen {
            if let b = pm.bubble {
                ctx.fill(Path(roundedRect: b.offsetBy(dx: 0, dy: -sy), cornerRadius: 18, style: .continuous),
                         with: .color(ink.opacity(0.055)))
            }
            if pm.role == .assistant { drawMeta(&ctx, pm, sy) }
            guard dc > 0.01 else { continue }
            // Cited spans: a hairline underline in debug; the active one turns spot and gets a wash.
            for pb in pm.blocks {
                for s in pb.block.spans {
                    let l = pb.block.lines[s.line]
                    let top = pb.origin.y - sy + l.top
                    let e = ChatModel.key(pm.index, s.id) == active ? activeEmph : 0
                    let x0 = pb.origin.x + s.x0, w = s.x1 - s.x0
                    let uy = pb.origin.y - sy + l.baseline + pb.fontSize * 0.24
                    if e > 0.01 {
                        ctx.fill(Path(roundedRect: CGRect(x: x0 - 2, y: top + 3, width: w + 4, height: l.height - 6), cornerRadius: 3),
                                 with: .color(spot.opacity(0.08 * Double(e * dc))))
                    }
                    ctx.fill(Path(CGRect(x: x0, y: uy, width: w, height: 1)),
                             with: .color(ink.opacity(Double(0.22 * (1 - e) * dc))))
                    ctx.fill(Path(CGRect(x: x0, y: uy - 0.25, width: w * e, height: 1.5)),
                             with: .color(spot.opacity(Double(dc))))
                }
            }
        }
        ctx.withCGContext { cg in
            for pm in onScreen {
                for pb in pm.blocks {
                    TextLayout.draw(pb.block, at: CGPoint(x: pb.origin.x, y: pb.origin.y - sy), in: cg)
                }
            }
        }
        for pm in onScreen {
            let msg = m.messages[pm.index]
            for pb in pm.blocks {
                for mk in pb.block.markers {
                    let r = mk.rect.offsetBy(dx: pb.origin.x, dy: pb.origin.y - sy)
                    let e = ChatModel.key(pm.index, mk.id) == active ? activeEmph * dc : 0
                    guard let t = msg.trace(mk.id) else { continue }
                    drawMarker(&ctx, t, center: CGPoint(x: r.midX, y: r.midY), fontSize: pb.fontSize, emph: e, debug: dc)
                }
            }
        }

        // MARK: As traced: connectors and cards.
        let cw = m.cardWidth
        var shown: [(card: Card, layout: CardLayout, P: CGPoint, C: CGPoint, x: CGFloat, alpha: CGFloat)] = []
        if dc > 0.005 {
            var candidates: [(Card, CardLayout)] = []
            for c in m.cards where c.visible {
                let l = m.cardLayout(c)
                if c.y < H + 40 && c.y + l.height > -40 { candidates.append((c, l)) }
            }
            candidates.sort { (a: (Card, CardLayout), b: (Card, CardLayout)) -> Bool in a.0.y < b.0.y }
            for (j, (c, l)) in candidates.enumerated() {
                // Cards slide in one after another as the split opens.
                let e = smooth((dc - 0.12 - 0.06 * CGFloat(j)) / 0.6)
                let x = m.railX + (1 - e) * 28
                let P = CGPoint(x: dx, y: m.anchorContentY(c) - sy)
                let C = CGPoint(x: x, y: c.y + 16)
                shown.append((c, l, P, C, x, e * CGFloat(c.appear)))
            }
        }

        // Quiet connectors first.
        for s in shown where s.card.key != active || s.card.emph < 0.999 {
            let (msg, t) = m.trace(of: s.card)!
            let running = t.isTool && !m.toolDone(msg, t)
            let path = bezier(s.P, s.C)
            var c = ctx
            c.opacity = Double(s.alpha * (1 - CGFloat(s.card.emph)))
            if running {
                c.stroke(path, with: .color(spot), style: StrokeStyle(lineWidth: 1, dash: [2, 3], dashPhase: -CGFloat(m.clock * 24)))
            } else {
                c.stroke(path, with: .color(ink.opacity(0.2)), lineWidth: 1)
            }
        }

        for s in shown { drawCard(&ctx, s.card, s.layout, x: s.x, width: cw, alpha: s.alpha, active: s.card.key == active) }

        // The active connector: a leader from the citation marker, routed through the line gap to the
        // divider, then a curve to its card, drawn with its handles like an outline in the scanner.
        if let s = shown.first(where: { $0.card.key == active }), s.card.emph > 0.001 {
            let e = CGFloat(s.card.emph)
            var pts: [CGPoint] = []
            if let a = m.anchors[s.card.key] {
                let mx = a.marker.midX, my = a.marker.midY - sy
                pts += [CGPoint(x: mx, y: my + a.marker.height * 0.42), CGPoint(x: mx, y: s.P.y)]
            }
            let (c1, c2) = handles(s.P, s.C)
            for i in 0...28 {
                let t = CGFloat(i) / 28
                pts.append(cubic(s.P, c1, c2, s.C, t))
            }
            var c = ctx
            c.opacity = Double(s.alpha)
            c.stroke(trimmed(pts, e), with: .color(spot), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
            c.opacity = Double(s.alpha * e)
            onCurve(&c, s.C, size: 6, fill: paper, stroke: ink)

            // A pulse runs along the path when a trace becomes active.
            if s.card.pulse < 1 {
                let p = point(along: pts, CGFloat(1 - pow(1 - s.card.pulse, 2.4)))
                c.opacity = Double(s.alpha) * (1 - pow(s.card.pulse, 6))
                c.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(paper))
                c.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(spot))
            }
        }

        // Paper fades under the header and the input.
        ctx.fill(Path(CGRect(x: 0, y: 0, width: W, height: ChatModel.headerH + 18)),
                 with: .linearGradient(Gradient(stops: [
                    .init(color: paper, location: 0), .init(color: paper, location: 0.62),
                    .init(color: paper.opacity(0), location: 1)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: ChatModel.headerH + 18)))
        // Only behind the input: it leaves with the input when the overview opens.
        let fadeH: CGFloat = 96 + (H - m.size.height)
        var bottom = ctx
        bottom.opacity = Double(1 - dc)
        bottom.fill(Path(CGRect(x: 0, y: H - fadeH, width: W, height: fadeH)),
                    with: .linearGradient(Gradient(stops: [
                        .init(color: paper.opacity(0), location: 0), .init(color: paper, location: 0.55)]),
                        startPoint: CGPoint(x: 0, y: H - fadeH), endPoint: CGPoint(x: 0, y: H)))

        guard dc > 0.005 else { return }

        // The divider, with on-curve points where each trace leaves the text.
        ctx.fill(Path(CGRect(x: dx - (m.draggingDivider ? 0.75 : 0.5), y: 0, width: m.draggingDivider ? 1.5 : 1, height: H)),
                 with: .color(ink.opacity(Double(dc))))
        for s in shown {
            let edge = smooth((s.P.y - ChatModel.headerH) / 24) * smooth((H - 70 - s.P.y) / 30)
            guard edge > 0.01 else { continue }
            var c = ctx
            c.opacity = Double(s.alpha * edge)
            let isActive = s.card.key == active
            let e = isActive ? CGFloat(s.card.emph) : 0
            onCurve(&c, s.P, size: 5 + e, fill: paper, stroke: ink.opacity(Double(0.45 + 0.55 * e)))
        }
    }

    // MARK: Pieces

    private func drawMeta(_ ctx: inout GraphicsContext, _ pm: PlacedMessage, _ sy: CGFloat) {
        let m = model
        let msg = m.messages[pm.index]
        let y = pm.metaY - sy
        let x = m.colLeft
        if !msg.isComplete {
            let label: String
            if let t = msg.runningTool(at: m.clock), case let .tool(doing, _, _, _) = t.kind {
                label = doing
            } else {
                label = m.clock < msg.textStart ? "Thinking" : "Writing"
            }
            let pulse = 0.55 + 0.45 * sin(m.clock * 6)
            ctx.fill(Path(ellipseIn: CGRect(x: x, y: y - 3, width: 6, height: 6)), with: .color(Palette.spot.opacity(pulse)))
            ctx.draw(Text(label).font(metaFont).foregroundStyle(Palette.ink.opacity(0.5)),
                     at: CGPoint(x: x + 13, y: y), anchor: .leading)
            return
        }
    }

    /// Sources are numbered dots; tools are on-curve squares that only appear in debug.
    private func drawMarker(_ ctx: inout GraphicsContext, _ t: Trace, center p: CGPoint,
                            fontSize fs: CGFloat, emph e: CGFloat, debug dc: CGFloat) {
        if t.isTool {
            guard dc > 0.01 else { return }
            var c = ctx
            c.opacity = Double(dc)
            let s = fs * 0.46
            let r = CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)
            c.fill(Path(r), with: .color(Palette.paper))
            c.fill(Path(r), with: .color(Palette.spot.opacity(Double(e))))
            c.stroke(Path(r), with: .color(Palette.ink), lineWidth: 1)
        } else {
            let dia = fs * 0.98
            let r = CGRect(x: p.x - dia / 2, y: p.y - dia / 2, width: dia, height: dia)
            ctx.fill(Path(ellipseIn: r), with: .color(Palette.ink.opacity(0.07)))
            ctx.fill(Path(ellipseIn: r), with: .color(Palette.spot.opacity(Double(e))))
            let font = Font(Typeface.shared.uiFont(size: (fs * 0.6 * 2).rounded() / 2, weight: 620))
            var c = ctx
            c.opacity = Double(1 - e)
            c.draw(Text("\(t.number)").font(font).foregroundStyle(Palette.ink.opacity(0.72)), at: p)
            c.opacity = Double(e)
            c.draw(Text("\(t.number)").font(font).foregroundStyle(Palette.paper), at: p)
        }
    }

    private func drawCard(_ ctx: inout GraphicsContext, _ card: Card, _ l: CardLayout,
                          x: CGFloat, width w: CGFloat, alpha: CGFloat, active: Bool) {
        guard alpha > 0.01, let (msg, t) = model.trace(of: card) else { return }
        let m = model
        let e = CGFloat(card.emph)
        let rect = CGRect(x: x, y: card.y, width: w, height: l.height)
        var c = ctx
        c.opacity = Double(alpha)
        let shape = Path(roundedRect: rect, cornerRadius: 11, style: .continuous)
        c.fill(shape, with: .color(Palette.paper))
        c.stroke(shape, with: .color(Palette.ink.opacity(Double(0.11 + 0.74 * e))), lineWidth: 1)

        c.withCGContext { cg in
            for (b, o) in l.texts {
                TextLayout.draw(b, at: CGPoint(x: rect.minX + o.x, y: rect.minY + o.y), in: cg)
            }
        }
        if let r = l.rule {
            c.fill(Path(r.offsetBy(dx: rect.minX, dy: rect.minY)),
                   with: .color(e > 0.01 ? Palette.spot.opacity(0.2 + 0.5 * Double(e)) : Palette.ink.opacity(0.14)))
        }

        let hy = rect.minY + 16
        if t.isTool {
            let s: CGFloat = 7
            let r = CGRect(x: rect.minX + 11, y: hy - s / 2, width: s, height: s)
            c.fill(Path(r), with: .color(Palette.paper))
            c.fill(Path(r), with: .color(Palette.spot.opacity(Double(e))))
            c.stroke(Path(r), with: .color(Palette.ink), lineWidth: 1)

            let done = m.toolDone(msg, t)
            let w0 = msg.toolWindow(t.id)
            if !done, let w0 {
                let f = clamp((m.clock - w0.start) / max(0.01, w0.end - w0.start), 0, 1)
                let bar = CGRect(x: rect.minX + 11, y: rect.maxY - 9, width: w - 22, height: 1.5)
                c.fill(Path(bar), with: .color(Palette.ink.opacity(0.07)))
                c.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: bar.width * CGFloat(f), height: bar.height)),
                       with: .color(Palette.spot))
            }
        } else {
            let dia: CGFloat = 13
            let r = CGRect(x: rect.minX + 11, y: hy - dia / 2, width: dia, height: dia)
            c.fill(Path(ellipseIn: r), with: .color(Palette.ink.opacity(0.07)))
            c.fill(Path(ellipseIn: r), with: .color(Palette.spot.opacity(Double(e))))
            let font = Font(Typeface.shared.uiFont(size: 8.5, weight: 650))
            c.draw(Text("\(t.number)").font(font)
                    .foregroundStyle(e > 0.5 ? Palette.paper : Palette.ink.opacity(0.72)),
                   at: CGPoint(x: r.midX, y: r.midY))
        }
    }

    private func grid(_ ctx: inout GraphicsContext, _ size: CGSize) {
        func lines(step: CGFloat, color: Color) {
            var p = Path()
            var x: CGFloat = 0
            while x <= size.width { p.addRect(CGRect(x: x, y: 0, width: 1, height: size.height)); x += step }
            var y: CGFloat = 0
            while y <= size.height { p.addRect(CGRect(x: 0, y: y, width: size.width, height: 1)); y += step }
            ctx.fill(p, with: .color(color))
        }
        lines(step: 20, color: Palette.ink.opacity(0.045))
        lines(step: 100, color: Palette.ink.opacity(0.055))
    }

    private func onCurve(_ ctx: inout GraphicsContext, _ p: CGPoint, size s: CGFloat, fill: Color, stroke: Color) {
        let r = CGRect(x: p.x - s / 2, y: p.y - s / 2, width: s, height: s)
        ctx.fill(Path(r), with: .color(fill))
        ctx.stroke(Path(r), with: .color(stroke), lineWidth: 1)
    }

    /// A label on a paper chip, like the scanner's tags.
    private func pill(_ ctx: inout GraphicsContext, _ text: Text, at p: CGPoint, anchor: UnitPoint,
                      fg: Color, bg: Color, padX: CGFloat = 6) {
        let r = ctx.resolve(text.font(labelFont).foregroundStyle(fg))
        let sz = r.measure(in: CGSize(width: 400, height: 40))
        let origin = CGPoint(x: p.x - anchor.x * sz.width, y: p.y - anchor.y * sz.height)
        let box = CGRect(origin: origin, size: sz).insetBy(dx: -padX, dy: -3)
        ctx.fill(Path(roundedRect: box, cornerRadius: 5), with: .color(bg))
        ctx.draw(r, at: p, anchor: anchor)
    }
}

// MARK: - Geometry

private func handles(_ a: CGPoint, _ b: CGPoint) -> (CGPoint, CGPoint) {
    let k = (b.x - a.x) * 0.55
    return (CGPoint(x: a.x + k, y: a.y), CGPoint(x: b.x - k, y: b.y))
}

private func bezier(_ a: CGPoint, _ b: CGPoint) -> Path {
    let (c1, c2) = handles(a, b)
    var p = Path()
    p.move(to: a)
    p.addCurve(to: b, control1: c1, control2: c2)
    return p
}

private func cubic(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ t: CGFloat) -> CGPoint {
    let u = 1 - t
    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
    return CGPoint(x: a * p0.x + b * p1.x + c * p2.x + d * p3.x,
                   y: a * p0.y + b * p1.y + c * p2.y + d * p3.y)
}

private func lengths(_ pts: [CGPoint]) -> [CGFloat] {
    var out: [CGFloat] = [0]
    for i in 1..<max(1, pts.count) { out.append(out[i - 1] + hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)) }
    return out
}

private func point(along pts: [CGPoint], _ f: CGFloat) -> CGPoint {
    guard pts.count > 1 else { return pts.first ?? .zero }
    let ls = lengths(pts)
    let target = ls.last! * clamp(f, 0, 1)
    for i in 1..<pts.count where ls[i] >= target {
        let seg = max(0.0001, ls[i] - ls[i - 1])
        let t = (target - ls[i - 1]) / seg
        return CGPoint(x: lerp(pts[i - 1].x, pts[i].x, t), y: lerp(pts[i - 1].y, pts[i].y, t))
    }
    return pts.last!
}

/// The first `f` of a polyline, by length: draws the active connector out from the text.
private func trimmed(_ pts: [CGPoint], _ f: CGFloat) -> Path {
    var p = Path()
    guard pts.count > 1 else { return p }
    let ls = lengths(pts)
    let target = ls.last! * clamp(f, 0, 1)
    p.move(to: pts[0])
    for i in 1..<pts.count {
        if ls[i] <= target { p.addLine(to: pts[i]); continue }
        let t = (target - ls[i - 1]) / max(0.0001, ls[i] - ls[i - 1])
        p.addLine(to: CGPoint(x: lerp(pts[i - 1].x, pts[i].x, t), y: lerp(pts[i - 1].y, pts[i].y, t)))
        break
    }
    return p
}

#Preview {
    ChatView()
}
