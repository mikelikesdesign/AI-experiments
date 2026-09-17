import Foundation

/// Keeps scroll geometry, selection, and cancellation on one continuous reveal.
struct OptionMenuReveal {
    /// Scroll distance before the end of the response over which the menu
    /// reveals, when the response is long enough to allow it.
    static let maximumRevealDistance: CGFloat = 420
    /// Fraction of the reveal distance at which the menu is inserted. The gap up
    /// to the full distance is hysteresis, so bounce near the boundary cannot
    /// flicker the menu in and out.
    static let entryFraction: CGFloat = 380 / 420

    private(set) var progress: CGFloat = 0
    /// Distance over which the menu currently reveals. Short responses cannot
    /// scroll far, so the reveal compresses to the range they do have.
    private(set) var revealDistance: CGFloat = Self.maximumRevealDistance
    private var remainingDistance: CGFloat = Self.maximumRevealDistance
    private var scrollRange: CGFloat = .infinity
    private var isVisible = false
    private var pinnedDistance: CGFloat?

    mutating func update(remainingDistance: CGFloat, scrollRange: CGFloat) {
        let distance = max(remainingDistance, 0)
        self.remainingDistance = distance
        self.scrollRange = max(scrollRange, 1)
        revealDistance = min(Self.maximumRevealDistance, self.scrollRange)

        if let pinnedDistance {
            // Opening the picker can happen before the end of the response.
            // Retreat from that actual position instead of jumping back to the
            // unpinned reveal when the scroll lock is released. The exit must
            // stay reachable, so it never lies beyond the top of the scroll.
            let exitDistance = min(
                max(revealDistance, pinnedDistance + 180),
                max(self.scrollRange, pinnedDistance + 1)
            )
            progress = min(max((exitDistance - distance) / (exitDistance - pinnedDistance), 0), 1)
            if distance >= exitDistance {
                self.pinnedDistance = nil
                isVisible = false
            }
            return
        }

        // Separate entry and exit distances prevent bounce near the boundary
        // from repeatedly inserting and removing the menu.
        if !isVisible, distance <= revealDistance * Self.entryFraction {
            isVisible = true
        } else if isVisible, distance >= revealDistance {
            isVisible = false
        }
        progress = isVisible ? min(max(1 - distance / revealDistance, 0), 1) : 0
    }

    mutating func holdOpen() {
        pinnedDistance = remainingDistance
        isVisible = true
        progress = 1
    }

    mutating func reset() {
        self = Self()
    }
}
