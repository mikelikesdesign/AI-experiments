//
//  ScrollActionSelector.swift
//  scroll options
//

import SwiftUI

/// A typographic selector: the pull controls the light, focus, and tension together.
/// It deliberately has no touch targets; gestures pass through to the response.
struct ScrollActionSelector: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var optionFontSize: CGFloat = 24
    /// Option titles in pull order; the first is live after the arm distance.
    let options: [String]
    let selectedIndex: Int
    let selectionPosition: CGFloat
    let isScrubbing: Bool
    let revealProgress: CGFloat
    let committedIndex: Int?
    /// The committed option lifts out of view before the next flow begins.
    let isDismissing: Bool
    let rowHeight: CGFloat

    private var selectedTitle: String {
        options.indices.contains(selectedIndex) ? options[selectedIndex] : ""
    }

    // Ease near each stop, but keep the transition between stops tied to the finger.
    private var magneticPosition: CGFloat {
        if committedIndex != nil || reduceMotion {
            return CGFloat(selectedIndex)
        }
        let base = floor(selectionPosition)
        let fraction = selectionPosition - base
        return base + fraction * fraction * (3 - 2 * fraction)
    }

    private var reveal: CGFloat {
        1 - pow(1 - min(max(revealProgress, 0), 1), 3)
    }

    /// Until the pull arms, no option is live, so none is shown as selected.
    /// What looks chosen is then always what a release will perform.
    private var isEngaged: Bool {
        isScrubbing || committedIndex != nil
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SelectionFilament(
                position: CGFloat(selectedIndex),
                optionCount: options.count,
                rowHeight: rowHeight,
                reveal: isDismissing ? 0 : reveal,
                isEngaged: isEngaged,
                isCommitted: committedIndex != nil,
                reduceMotion: reduceMotion
            )
            .frame(width: 28, height: rowHeight * CGFloat(max(options.count, 1)))
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selectedIndex)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, title in
                    optionLabel(title, index: index)
                }
            }
            .padding(.leading, 42)
        }
        .frame(maxWidth: 360)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: selectionPosition)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: isScrubbing)
        // The reveal steps when the pull catches the scroll and pins it open.
        // A short retargeting spring turns that into a settle instead of a snap.
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: revealProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scroll options")
        .accessibilityValue(selectedTitle)
        .accessibilityHint("Keep pulling past the end to highlight an option, then release to use it. Pull back to cancel.")
        .accessibilityHidden(revealProgress < 0.2)
    }

    private func optionLabel(_ title: String, index: Int) -> some View {
        let distance = CGFloat(index) - magneticPosition
        let proximity = isEngaged ? max(0, 1 - abs(distance)) : 0
        let entrance = min(max((revealProgress - CGFloat(index) * 0.055) / 0.72, 0), 1)
        let unfolded = 1 - pow(1 - entrance, 3)
        let isChosen = committedIndex == index
        let isLeaving = committedIndex != nil && !isChosen
        let departs = isDismissing && isChosen
        // The selection comes forward while its neighbours recede: they shrink,
        // dim, and soften slightly, but nothing moves sideways.
        let recession = 1 - proximity

        return Text(title)
            .font(.system(size: optionFontSize, weight: .medium))
            .tracking(-0.65)
            .foregroundStyle(.white.opacity(0.24 + 0.76 * proximity))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: rowHeight)
            .scaleEffect(
                reduceMotion ? 1 : 1 - recession * 0.12 + (isChosen ? (departs ? 0.08 : 0.035) : 0),
                anchor: .leading
            )
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : Double(distance * -4 + (1 - unfolded) * 24)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.25
            )
            .blur(radius: reduceMotion ? 0 : (1 - unfolded) * 5 + recession * 0.6 + (departs ? 6 : 0))
            // The choice dissolves where it sits rather than travelling anywhere.
            .opacity(isLeaving || departs ? 0 : unfolded)
            .zIndex(Double(proximity))
    }
}

private struct SelectionFilament: View {
    let position: CGFloat
    let optionCount: Int
    let rowHeight: CGFloat
    let reveal: CGFloat
    let isEngaged: Bool
    let isCommitted: Bool
    let reduceMotion: Bool

    private var beadY: CGFloat { rowHeight * (0.5 + position) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            FilamentPath(rowHeight: rowHeight, optionCount: optionCount)
                .stroke(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, lineCap: .round))

            ForEach(0..<max(optionCount, 1), id: \.self) { index in
                Circle()
                    .fill(.white.opacity(0.22))
                    .frame(width: 3, height: 3)
                    .position(x: 12, y: rowHeight * (CGFloat(index) + 0.5))
            }

            // The bead only appears once an option is live to be released on.
            Circle()
                .fill(.white)
                .frame(width: 5, height: 5)
                .scaleEffect(!reduceMotion && isCommitted ? 1.7 : (isEngaged ? 1 : 0.4))
                .opacity(isEngaged ? 1 : 0)
                .position(x: 12, y: beadY)

            Circle()
                .stroke(.white.opacity(isCommitted || !isEngaged ? 0 : 0.2), lineWidth: 1)
                .frame(width: 16, height: 16)
                .scaleEffect(!reduceMotion && isCommitted ? 2.8 : (isEngaged ? 1 : 0.6))
                .position(x: 12, y: beadY)
        }
        // Fade the guide as a whole so the reveal never cuts through a dot or ring.
        .opacity(reveal)
    }
}

/// The guide stays straight while the selection indicator travels along it.
private struct FilamentPath: Shape {
    var rowHeight: CGFloat
    var optionCount: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 12, y: rowHeight * 0.5))
        path.addLine(to: CGPoint(x: 12, y: rowHeight * (CGFloat(max(optionCount, 1)) - 0.5)))
        return path
    }
}
