import CoreText
import UIKit

/// Hand-rolled CoreText layout, so we know exactly where every cited span and
/// citation marker sits. That is what lets the connectors start from the words.
struct LaidLine {
    let line: CTLine
    /// Top of the line box, relative to the block.
    let top: CGFloat
    let baseline: CGFloat
    let height: CGFloat
    let width: CGFloat
}

struct MarkerBox {
    let id: String
    let rect: CGRect      // relative to the block
    let line: Int
}

struct SpanRun {
    let id: String
    let x0: CGFloat, x1: CGFloat
    let line: Int
}

struct TextBlock {
    var lines: [LaidLine] = []
    var markers: [MarkerBox] = []
    var spans: [SpanRun] = []
    var height: CGFloat = 0
    var width: CGFloat = 0

    func lineBottom(_ i: Int) -> CGFloat { lines[i].top + lines[i].height }
}

enum Ink {
    // Blue tones throughout: a deep navy ink (its tints give the bubbles, grid and rules a blue cast),
    // a cool paper, and a bright blue spot for anything active or live.
    static let ink = UIColor(red: 0x0E / 255, green: 0x1A / 255, blue: 0x33 / 255, alpha: 1)
    static let paper = UIColor(red: 0xF8 / 255, green: 0xFA / 255, blue: 0xFD / 255, alpha: 1)
    static let spot = UIColor(displayP3Red: 0.13, green: 0.42, blue: 0.98, alpha: 1)
    static func ink(_ a: CGFloat) -> CGColor { ink.withAlphaComponent(a).cgColor }
    static func spot(_ a: CGFloat) -> CGColor { spot.withAlphaComponent(a).cgColor }
}

enum TextLayout {
    private static let fontKey = NSAttributedString.Key(kCTFontAttributeName as String)
    private static let colorKey = NSAttributedString.Key(kCTForegroundColorAttributeName as String)
    private static let kernKey = NSAttributedString.Key(kCTKernAttributeName as String)
    private static let delegateKey = NSAttributedString.Key(kCTRunDelegateAttributeName as String)

    /// A zero-height placeholder of a given width, for inline citation markers.
    private static func spacer(width: CGFloat) -> CTRunDelegate? {
        var cb = CTRunDelegateCallbacks(
            version: kCTRunDelegateVersion1,
            dealloc: { $0.assumingMemoryBound(to: CGFloat.self).deallocate() },
            getAscent: { _ in 0 },
            getDescent: { _ in 0 },
            getWidth: { $0.assumingMemoryBound(to: CGFloat.self).pointee })
        let p = UnsafeMutablePointer<CGFloat>.allocate(capacity: 1)
        p.pointee = width
        return CTRunDelegateCreate(&cb, p)
    }

    static func sourceMarkerWidth(_ size: CGFloat) -> CGFloat { size * 1.2 }
    static func toolMarkerWidth(_ size: CGFloat) -> CGFloat { size * 0.95 }

    /// Lay out the first `visible` UTF-16 units of a paragraph.
    /// `debug` (0…1) opens room for tool markers.
    static func paragraph(_ p: Paragraph, visible: Int, width: CGFloat, size: CGFloat,
                          debug: CGFloat, isTool: (String) -> Bool) -> TextBlock {
        let n = max(0, min(visible, p.length))
        let font = Typeface.shared.font(size: size)
        let s = NSMutableAttributedString(string: p.text.substring(to: n), attributes: [
            fontKey: font,
            colorKey: Ink.ink(1),
            kernKey: -0.004 * size,
        ])
        for span in p.spans {
            let r = NSIntersectionRange(span.range, NSRange(location: 0, length: n))
            if r.length > 0 { s.addAttribute(colorKey, value: Ink.ink(1), range: r) }
        }
        for m in p.markers where m.index < n {
            let w = isTool(m.id) ? toolMarkerWidth(size) * debug : sourceMarkerWidth(size)
            if let d = spacer(width: w) {
                s.addAttribute(delegateKey, value: d, range: NSRange(location: m.index, length: 1))
            }
        }
        var block = lay(s, width: width, lineHeight: size * 1.55, font: font)

        for (li, l) in block.lines.enumerated() {
            let r = CTLineGetStringRange(l.line)
            let lo = r.location, hi = r.location + r.length
            for m in p.markers where m.index >= lo && m.index < hi && m.index < n {
                let x = CTLineGetOffsetForStringIndex(l.line, m.index, nil)
                let w = isTool(m.id) ? toolMarkerWidth(size) : sourceMarkerWidth(size)
                let cy = l.baseline - size * 0.34
                block.markers.append(MarkerBox(
                    id: m.id, rect: CGRect(x: x + 0.12 * size, y: cy - w / 2, width: w - 0.12 * size, height: w),
                    line: li))
            }
            for span in p.spans {
                let a = max(lo, span.range.location), b = min(hi, span.range.location + span.range.length, n)
                guard b > a else { continue }
                let x0 = CTLineGetOffsetForStringIndex(l.line, a, nil)
                var x1 = CTLineGetOffsetForStringIndex(l.line, b, nil)
                if b == hi { x1 = min(x1, l.width) }
                if x1 - x0 > 1 { block.spans.append(SpanRun(id: span.id, x0: x0, x1: x1, line: li)) }
            }
        }
        return block
    }

    /// Plain text at a given font, colour and line height, optionally capped with an ellipsis.
    static func plain(_ text: String, font: CTFont, color: CGColor, width: CGFloat,
                      lineHeight: CGFloat, maxLines: Int = .max, kern: CGFloat = 0) -> TextBlock {
        let s = NSAttributedString(string: text, attributes: [fontKey: font, colorKey: color, kernKey: kern])
        return lay(s, width: width, lineHeight: lineHeight, font: font, maxLines: maxLines)
    }

    private static func lay(_ s: NSAttributedString, width: CGFloat, lineHeight: CGFloat,
                            font: CTFont, maxLines: Int = .max) -> TextBlock {
        var block = TextBlock()
        guard s.length > 0, width > 4 else { return block }
        let ts = CTTypesetterCreateWithAttributedString(s)
        let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
        var start = 0
        var y: CGFloat = 0
        while start < s.length {
            var count = CTTypesetterSuggestLineBreak(ts, start, Double(width))
            if count <= 0 { count = 1 }
            var line = CTTypesetterCreateLine(ts, CFRange(location: start, length: count))
            let last = block.lines.count == maxLines - 1 && start + count < s.length
            if last {
                let rest = CTTypesetterCreateLine(ts, CFRange(location: start, length: s.length - start))
                let dots = CTLineCreateWithAttributedString(NSAttributedString(
                    string: "…", attributes: s.attributes(at: start, effectiveRange: nil)))
                line = CTLineCreateTruncatedLine(rest, Double(width), .end, dots) ?? line
            }
            let w = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil) - CTLineGetTrailingWhitespaceWidth(line))
            let baseline = y + (lineHeight - (ascent + descent)) / 2 + ascent
            block.lines.append(LaidLine(line: line, top: y, baseline: baseline, height: lineHeight, width: w))
            block.width = max(block.width, w)
            y += lineHeight
            start += count
            if last { break }
        }
        block.height = y
        return block
    }

    /// Draw a block's lines with its top-left at `origin`, in a y-down context.
    static func draw(_ block: TextBlock, at origin: CGPoint, in cg: CGContext) {
        cg.saveGState()
        cg.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        for l in block.lines {
            cg.textPosition = CGPoint(x: origin.x, y: origin.y + l.baseline)
            CTLineDraw(l.line, cg)
        }
        cg.restoreGState()
    }
}
