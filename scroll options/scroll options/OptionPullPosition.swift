import Foundation

/// Maps an engaged selection drag to a candidate. The caller commits only on release.
///
/// Selection is a continuation of the scroll: it begins when the response reaches
/// its end and the finger keeps pulling. Pulling further steps through the
/// options, pulling back steps through them in reverse, and pulling back below
/// the anchor hands the same drag back to scrolling.
struct OptionPullPosition {
    let distance: CGFloat
    let optionCount: Int

    /// Pull needed past the end of the response before Simplify is live, so an
    /// overshoot on the last line never commits an action on release.
    static let armDistance: CGFloat = 12
    /// Pulling back this far below the anchor returns the drag to scrolling.
    static let cancelDistance: CGFloat = 24
    /// Remaining scroll distance within which a continued upward drag becomes a
    /// pull. The menu is well over half revealed by here, so the catch reads as
    /// the options taking the gesture rather than the scroll stalling early.
    static let entryDistance: CGFloat = 160
    /// Pull between adjacent options. Short enough that all three sit within a
    /// comfortable thumb travel past the end of the response.
    private let step: CGFloat = 36

    private var rawPosition: CGFloat { (distance - Self.armDistance) / step }

    /// Distance at which the pull can begin for a menu that reveals over
    /// `revealDistance`; short responses compress it along with the reveal.
    static func entryDistance(forRevealDistance revealDistance: CGFloat) -> CGFloat {
        min(entryDistance, revealDistance * 0.4)
    }

    static func canBeginSelection(
        optionsVisible: Bool,
        remainingDistance: CGFloat,
        translation: CGSize,
        entryDistance: CGFloat = OptionPullPosition.entryDistance
    ) -> Bool {
        optionsVisible && remainingDistance <= entryDistance
            && translation.height < -abs(translation.width)
    }

    static func releaseCandidate(
        distance: CGFloat?,
        peakDistance: CGFloat,
        previousIndex: Int,
        optionCount: Int
    ) -> Int? {
        // Reaching the end of the response is ordinary scrolling until the finger
        // pulls into selection, so a release without an anchor does nothing.
        guard let distance else { return nil }
        let position = Self(distance: distance, optionCount: optionCount)
        guard !position.cancelsSelection else { return nil }
        return position.candidateIndex(previousIndex: previousIndex, peakDistance: peakDistance)
    }

    var position: CGFloat {
        min(max(rawPosition, 0), CGFloat(max(optionCount - 1, 0)))
    }

    var cancelsSelection: Bool {
        distance <= -Self.cancelDistance
    }

    /// Arming is sticky for the rest of the drag: easing back toward the anchor
    /// keeps Simplify live rather than silently disarming it.
    func isArmed(afterPeakDistance peakDistance: CGFloat) -> Bool {
        max(distance, peakDistance) >= Self.armDistance
    }

    func candidateIndex(previousIndex: Int, peakDistance: CGFloat) -> Int? {
        guard optionCount > 0, isArmed(afterPeakDistance: peakDistance) else { return nil }
        let previous = min(max(previousIndex, 0), optionCount - 1)
        // A detent in both directions avoids flicker and repeated haptics at a
        // boundary while still letting the drag walk back through the options.
        return abs(position - CGFloat(previous)) > 0.58 ? Int(position.rounded()) : previous
    }
}
