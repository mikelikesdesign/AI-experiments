#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

// Two separable Gaussian passes vary the actual sampling radius per pixel.
// A gentle fade in the lower region lets blurred letterforms recede behind the
// options. Pixels above the transition remain unchanged.
[[ stitchable ]] half4 progressiveBlur(
    float2 position, SwiftUI::Layer layer,
    float startY, float transitionHeight, float maximumRadius, float strength, float2 axis
) {
    float progress = smoothstep(0.0f, 1.0f,
        (position.y - startY) / max(transitionHeight, 1.0f));
    // Perceived blur grows roughly with the log of the radius, so a linear ramp
    // reads as a hard edge where the first pixels soften. Squaring keeps the
    // lead-in almost crisp and gathers the blur where the options sit.
    float depth = progress * progress;
    float radius = maximumRadius * depth * strength;
    if (radius < 0.01f) {
        return layer.sample(position);
    }

    float4 sum = float4(0.0f);
    float totalWeight = 0.0f;
    // Keep samples close together even at the larger radius to avoid streaks.
    for (int sample = -32; sample <= 32; ++sample) {
        float offset = float(sample) / 32.0f;
        float weight = exp(-4.5f * offset * offset);
        sum += float4(layer.sample(position + axis * offset * radius)) * weight;
        totalWeight += weight;
    }
    // Apply once, after the vertical pass, to preserve premultiplied alpha.
    // The fade trails the blur so text softens before it starts to recede.
    float visibility = axis.y > 0.5f
        ? 1.0f - 0.72f * smoothstep(0.3f, 1.0f, progress) * strength
        : 1.0f;
    return half4(sum / totalWeight * visibility);
}
