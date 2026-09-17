// xcrun swiftc "scroll options/OptionMenuReveal.swift" Tests/OptionMenuRevealChecks.swift \
//   -o /tmp/scroll-options-menu-checks && /tmp/scroll-options-menu-checks
import Foundation

@main
struct OptionMenuRevealChecks {
    static func main() {
        let reveal = OptionMenuReveal.maximumRevealDistance
        let entry = reveal * OptionMenuReveal.entryFraction
        precondition(reveal == 420 && entry == 380)

        var menu = OptionMenuReveal()
        for distance: CGFloat in [700, reveal + 1, reveal - 1, reveal - 10, entry + 1] {
            menu.update(remainingDistance: distance, scrollRange: 2000)
            precondition(menu.progress == 0, "Boundary jitter must not show the menu")
        }
        menu.update(remainingDistance: entry - 10, scrollRange: 2000)
        precondition(menu.progress > 0)
        precondition(menu.revealDistance == reveal)
        for distance: CGFloat in [entry + 1, reveal - 10, reveal - 1, reveal - 20] {
            menu.update(remainingDistance: distance, scrollRange: 2000)
            precondition(menu.progress > 0, "An open menu must survive small reversals")
        }
        menu.update(remainingDistance: reveal + 1, scrollRange: 2000)
        precondition(menu.progress == 0)
        menu.update(remainingDistance: reveal - 1, scrollRange: 2000)
        precondition(menu.progress == 0, "Bounce must not immediately reopen a closed menu")

        // Cancelling at any option unlocks scrolling without snapping the reveal
        // back to the pre-selection amount or requiring another finger gesture.
        for entryDistance: CGFloat in [370, 160, 50, 0] {
            menu.reset()
            menu.update(remainingDistance: entryDistance, scrollRange: 2000)
            menu.holdOpen()
            menu.update(remainingDistance: entryDistance, scrollRange: 2000)
            precondition(menu.progress == 1, "Unlocking at the same offset must not hide the menu")
            var previous = menu.progress
            let exit = max(reveal, entryDistance + 180)
            for distance in stride(from: entryDistance + 1, through: exit, by: 1) {
                menu.update(remainingDistance: distance, scrollRange: 2000)
                precondition(menu.progress <= previous)
                precondition(previous - menu.progress < 0.01, "Retreat must close the menu smoothly")
                previous = menu.progress
            }
            precondition(menu.progress == 0)
            menu.update(remainingDistance: exit - 1, scrollRange: 2000)
            precondition(menu.progress == 0)
        }
        menu.update(remainingDistance: 100, scrollRange: 2000)
        menu.holdOpen()
        menu.update(remainingDistance: 200, scrollRange: 2000)
        menu.holdOpen()
        menu.update(remainingDistance: 200, scrollRange: 2000)
        precondition(menu.progress == 1, "Re-entering selection must pin its current scroll position")
        menu.reset()
        precondition(menu.progress == 0, "A new response resets the reveal")

        // A short response compresses the reveal to the range it can scroll, so
        // the menu is hidden at the top and fully open at the bottom.
        let shortRange: CGFloat = 200
        menu.reset()
        menu.update(remainingDistance: shortRange, scrollRange: shortRange)
        precondition(menu.progress == 0, "A short response must start with the menu closed")
        precondition(menu.revealDistance == shortRange)
        menu.update(remainingDistance: shortRange * OptionMenuReveal.entryFraction - 1, scrollRange: shortRange)
        precondition(menu.progress > 0)
        menu.update(remainingDistance: 0, scrollRange: shortRange)
        precondition(menu.progress == 1)
        menu.update(remainingDistance: shortRange, scrollRange: shortRange)
        precondition(menu.progress == 0, "Scrolling a short response back to the top must close the menu")

        // Pinning inside a short range must still be able to retreat fully.
        menu.update(remainingDistance: 76, scrollRange: shortRange)
        menu.holdOpen()
        var previous = menu.progress
        for distance in stride(from: CGFloat(77), through: shortRange, by: 1) {
            menu.update(remainingDistance: distance, scrollRange: shortRange)
            precondition(menu.progress <= previous)
            previous = menu.progress
        }
        precondition(menu.progress == 0, "A pinned short menu must close by the top of the scroll")

        print("PASS: visibility hysteresis, selection unlock, smooth cancellation, bounce, short responses, and response reset")
    }
}
