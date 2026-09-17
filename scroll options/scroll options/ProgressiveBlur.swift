import SwiftUI

/// Blurs the response in viewport coordinates so the transition stays above the
/// options while the text scrolls beneath it. Apply before UIKit-backed probes.
///
/// `strength` is animatable so scroll thresholds, hold-open pinning, and option
/// visibility never step the blur; wrap changes in `.animation(_:value:)`.
struct ProgressiveBlur: ViewModifier, Animatable {
    let viewportHeight: CGFloat
    let height: CGFloat
    var strength: CGFloat

    var animatableData: CGFloat {
        get { strength }
        set { strength = newValue }
    }

    private let radius: CGFloat = 64
    /// How far the band sits below its resting place while the options are still
    /// revealing, as a fraction of its length. It climbs into place as they open.
    private let lift: CGFloat = 0.4

    func body(content: Content) -> some View {
        // Ease in and out so the first blurred pixels are imperceptible and the
        // final settle does not rush.
        let clamped = min(max(strength, 0), 1)
        let eased = clamped * clamped * (3 - 2 * clamped)

        return content.visualEffect { effect, geometry in
            let contentTop = geometry.frame(in: .named("chatViewport")).minY
            let length = min(height, viewportHeight)
            let restingStart = max(viewportHeight - height, 0) - contentTop
            let start = restingStart + (1 - eased) * length * lift

            return effect
                .layerEffect(
                    ShaderLibrary.progressiveBlur(
                        .float(start), .float(length), .float(radius), .float(eased),
                        .float2(1, 0)
                    ),
                    maxSampleOffset: CGSize(width: radius, height: 0),
                    isEnabled: eased > 0.001
                )
                .layerEffect(
                    ShaderLibrary.progressiveBlur(
                        .float(start), .float(length), .float(radius), .float(eased),
                        .float2(0, 1)
                    ),
                    maxSampleOffset: CGSize(width: 0, height: radius),
                    isEnabled: eased > 0.001
                )
        }
    }
}
