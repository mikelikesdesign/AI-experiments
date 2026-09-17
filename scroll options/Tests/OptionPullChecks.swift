// xcrun swiftc "scroll options/OptionPullPosition.swift" Tests/OptionPullChecks.swift \
//   -o /tmp/scroll-options-pull-checks && /tmp/scroll-options-pull-checks
import Foundation

@main
struct OptionPullChecks {
    static func main() {
        let upwardDrag = CGSize(width: 2, height: -20)
        // Selection begins once the menu is well into its reveal, not the moment
        // it starts to appear.
        precondition(OptionPullPosition.canBeginSelection(
            optionsVisible: true, remainingDistance: 0, translation: upwardDrag
        ))
        precondition(OptionPullPosition.canBeginSelection(
            optionsVisible: true, remainingDistance: 160, translation: upwardDrag
        ))
        precondition(!OptionPullPosition.canBeginSelection(
            optionsVisible: true, remainingDistance: 161, translation: upwardDrag
        ), "A barely revealed menu must not freeze the scroll")
        // Short responses compress the entry along with the reveal.
        precondition(OptionPullPosition.entryDistance(forRevealDistance: 420) == 160)
        precondition(OptionPullPosition.entryDistance(forRevealDistance: 200) == 80)
        precondition(!OptionPullPosition.canBeginSelection(
            optionsVisible: true, remainingDistance: 100, translation: upwardDrag,
            entryDistance: OptionPullPosition.entryDistance(forRevealDistance: 200)
        ))
        precondition(OptionPullPosition.canBeginSelection(
            optionsVisible: true, remainingDistance: 70, translation: upwardDrag,
            entryDistance: OptionPullPosition.entryDistance(forRevealDistance: 200)
        ))
        precondition(!OptionPullPosition.canBeginSelection(
            optionsVisible: false, remainingDistance: 0, translation: upwardDrag
        ))
        precondition(!OptionPullPosition.canBeginSelection(
            optionsVisible: true, remainingDistance: 0, translation: CGSize(width: 30, height: -20)
        ))
        precondition(!OptionPullPosition.canBeginSelection(
            optionsVisible: true, remainingDistance: 0, translation: CGSize(width: 0, height: 20)
        ))

        func release(_ distance: CGFloat?, peak: CGFloat? = nil, previous: Int = 0) -> Int? {
            OptionPullPosition.releaseCandidate(
                distance: distance, peakDistance: peak ?? max(distance ?? 0, 0),
                previousIndex: previous, optionCount: 3
            )
        }
        // Reaching the end without pulling in is ordinary scrolling.
        precondition(release(nil) == nil)
        // An overshoot on the last line must not commit Simplify.
        precondition(release(0) == nil)
        precondition(release(6) == nil)
        precondition(release(11) == nil)
        precondition(release(12) == 0)
        precondition(release(30) == 0)
        // Once armed, easing back toward the anchor keeps Simplify live.
        precondition(release(5, peak: 40) == 0)
        precondition(release(-10, peak: 40) == 0)
        // Pulling back below the anchor returns the drag to scrolling.
        precondition(release(-23, peak: 40) == 0)
        precondition(release(-24, peak: 40) == nil)
        precondition(release(-300, peak: 300, previous: 2) == nil)
        precondition(release(52, previous: 1) == 1)
        precondition(release(300, previous: 2) == 2)
        // Reversals walk back through the options instead of cancelling.
        precondition(release(288, peak: 300, previous: 2) == 2)
        precondition(release(52, peak: 300, previous: 2) == 1)
        precondition(release(12, peak: 300, previous: 2) == 0)

        func candidate(_ distance: CGFloat, previous: Int = 0, peak: CGFloat? = nil) -> Int? {
            OptionPullPosition(distance: distance, optionCount: 3)
                .candidateIndex(previousIndex: previous, peakDistance: peak ?? max(distance, 0))
        }

        for distance in stride(from: CGFloat(-11), through: 11, by: 1) {
            precondition(candidate(distance) == nil, "Unarmed pulls must not highlight an option")
            precondition(!OptionPullPosition(distance: distance, optionCount: 3).cancelsSelection)
        }
        precondition(OptionPullPosition(distance: 40, optionCount: 0)
            .candidateIndex(previousIndex: 0, peakDistance: 40) == nil)
        precondition(candidate(12) == 0)
        precondition(candidate(32) == 0)
        precondition(candidate(33) == 1)
        precondition(candidate(52) == 1)
        precondition(candidate(68, previous: 1) == 1)
        precondition(candidate(69, previous: 1) == 2)
        precondition(candidate(84) == 2)
        precondition(candidate(300, previous: 2) == 2)
        precondition(candidate(10_000, previous: 0) == 2)
        // Walking back: each step needs the same detent in reverse.
        precondition(candidate(64, previous: 2) == 2)
        precondition(candidate(63, previous: 2) == 1)
        precondition(candidate(52, previous: 2) == 1)
        precondition(candidate(28, previous: 1) == 1)
        precondition(candidate(27, previous: 1) == 0)
        precondition(candidate(0, previous: 2, peak: 100) == 0)
        precondition(candidate(-20, previous: 1, peak: 100) == 0)
        // Small reversals within a detent don't chatter between options.
        precondition(candidate(30, previous: 0) == 0)
        precondition(candidate(30, previous: 1) == 1)
        for distance in stride(from: CGFloat(84), through: 10_000, by: 16) {
            precondition(OptionPullPosition(distance: distance, optionCount: 3).position == 2)
            precondition(candidate(distance, previous: 2) == 2)
        }
        // A full round trip on one drag: arm, step up to the last option, step
        // back down to the first, and finally return to scrolling.
        var previous = 0
        var peak: CGFloat = 0
        var visited: [Int] = []
        for distance in Array(stride(from: CGFloat(0), through: 140, by: 1))
            + Array(stride(from: CGFloat(139), through: -40, by: -1)) {
            let position = OptionPullPosition(distance: distance, optionCount: 3)
            if position.cancelsSelection {
                visited.append(-1)
                break
            }
            peak = max(peak, distance)
            if let index = position.candidateIndex(previousIndex: previous, peakDistance: peak),
               index != previous || visited.isEmpty {
                previous = index
                visited.append(index)
            }
        }
        precondition(visited == [0, 1, 2, 1, 0, -1], "Round trip visited \(visited)")
        print("PASS: end-of-response entry, arming, all options, reversals, last-option clamp, cancellation, and detents")
    }
}
