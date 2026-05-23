#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

[[ stitchable ]] half4 portalShader(float2 position, half4 color, float2 size, float time) {
    // Normalized pixel coordinates
    float2 uv = position / size;

    // 1. Chunky Noise (Low Resolution feel)
    float noiseScale = 60.0;
    float2 blockUV = floor(uv * noiseScale);

    // Animate noise
    float2 noiseInput = blockUV + float2(time * 50.0, time * 30.0);

    // Generate separate noise for R, G, B channels for colorful static
    float3 noiseColor;
    noiseColor.r = fract(sin(dot(noiseInput, float2(12.9898, 78.233))) * 43758.5453);
    noiseColor.g = fract(sin(dot(noiseInput, float2(39.346, 11.135))) * 43758.5453);
    noiseColor.b = fract(sin(dot(noiseInput, float2(73.156, 52.235))) * 43758.5453);

    // 2. Scanlines
    float scanlineCount = 40.0;
    float scanline = sin(uv.y * scanlineCount - time * 8.0);
    // Keep scanline contrast subtle to avoid dark banding in full screen
    scanline = 0.95 + 0.05 * scanline;

    // 3. Rolling Bar
    float rollingBar = sin(uv.y * 2.5 + time * 2.0);
    rollingBar = smoothstep(-0.2, 0.2, rollingBar);
    rollingBar = 0.8 + 0.2 * rollingBar;

    // 4. Circular mask setup
    float2 center = float2(0.5, 0.5);
    float dist = distance(uv, center);

    // Combine effects
    float3 finalColor = noiseColor * scanline * rollingBar;

    // Boost brightness/contrast
    finalColor = smoothstep(0.2, 0.8, finalColor);

    // Apply circular mask
    float alpha = 1.0 - smoothstep(0.48, 0.5, dist);


    return half4(half3(finalColor), alpha * color.a);
}

[[ stitchable ]] float4 glitchShader(float2 position, SwiftUI::Layer layer, float time, float intensity) {
    float2 uv = position;

    // 0. Early exit if no intensity
    if (intensity <= 0.01) {
        return float4(layer.sample(position));
    }

    // 1. Horizontal Jitter (Scanline displacement)
    float jitterBlockSize = 20.0;
    float jitterTime = floor(time * 20.0);
    float blockY = floor(uv.y / jitterBlockSize);

    float blockNoise = fract(sin(dot(float2(blockY, jitterTime), float2(12.9898, 78.233))) * 43758.5453);

    float jitterOffset = 0.0;
    if (blockNoise < intensity * 0.8) {
        jitterOffset = (blockNoise - 0.5) * 50.0 * intensity;
    }

    // 2. Wave Distortion
    float wave = sin(uv.y * 0.05 + time * 20.0) * 5.0 * intensity;

    float2 distortedPos = position + float2(jitterOffset + wave, 0.0);

    // 3. RGB Split
    float splitAmount = 15.0 * intensity;

    float4 colorR = float4(layer.sample(distortedPos + float2(splitAmount, 0.0)));
    float4 colorG = float4(layer.sample(distortedPos));
    float4 colorB = float4(layer.sample(distortedPos - float2(splitAmount, 0.0)));

    // 4. White Noise / Static
    float2 noiseUV = position * 0.5;
    float staticNoise = fract(sin(dot(noiseUV + float2(time * 100.0, time * 50.0), float2(12.9898, 78.233))) * 43758.5453);

    float3 finalColor = float3(colorR.r, colorG.g, colorB.b);

    if (staticNoise < intensity * 0.3) {
        finalColor += float3(0.3, 0.3, 0.3);
    }

    float scanlineNoise = fract(sin(uv.y * 0.1 + time * 10.0) * 43758.5453);
    if (scanlineNoise < intensity * 0.1) {
        finalColor *= 0.5;
    }

    return float4(finalColor, 1.0);
}

[[ stitchable ]] half4 prismShader(float2 position, half4 color, float2 size, float time) {
    float2 uv = position / size;

    // Caustic water/glass effect
    float2 p = uv * 8.0 - float2(20.0);
    float2 i = p;
    float c = 1.0;
    float inten = 0.05;

    for (int n = 0; n < 4; n++) {
        float t = time * (1.0 - (3.0 / float(n+1)));
        i = p + float2(cos(t - i.x) + sin(t + i.y), sin(t - i.y) + cos(t + i.x));
        c += 1.0 / length(float2(p.x / (sin(i.x+t)/inten), p.y / (cos(i.y+t)/inten)));
    }

    c /= 4.0;
    c = 1.5 - sqrt(c);

    // Prismatic colors
    float3 col = float3(c*c*c*c);
    col.r *= 0.8 + 0.2 * sin(time * 0.5);
    col.g *= 0.8 + 0.2 * sin(time * 0.5 + 2.0);
    col.b *= 0.8 + 0.2 * sin(time * 0.5 + 4.0);

    // Soften and brighten
    col = smoothstep(0.0, 0.8, col) + 0.1;

    // Mix with white background
    return half4(half3(col), 1.0);
}
