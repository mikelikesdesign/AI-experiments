//
//  IterationPrototype.swift
//  content ideas
//
//  Created by Michael Lee on 4/21/26.
//

import Foundation

struct EditorSelectionContext: Equatable {
    let range: NSRange
    let text: String
    let bounds: CGRect
}

struct IterationCandidate: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let text: String
}

struct IterationPanelState: Identifiable {
    let id = UUID()
    let selection: EditorSelectionContext
    let candidates: [IterationCandidate]
}

struct ContextRippleSignal: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let subtitle: String
    let detail: String
    let angleDegrees: Double
    let radiusUnit: Double
}

struct ContextRippleState: Identifiable {
    let id = UUID()
    let selection: EditorSelectionContext
    let signals: [ContextRippleSignal]
}

struct ToneMixerState: Identifiable {
    let id = UUID()
    let selection: EditorSelectionContext
}

struct RephraseSession: Identifiable {
    let id = UUID()
    let selection: EditorSelectionContext
    let originalText: String
}

enum ToneQuadrant: String, CaseIterable, Hashable {
    case simple
    case casual
    case formal
    case advanced

    var title: String {
        rawValue.capitalized
    }
}

struct TonePreviewResult: Equatable {
    let text: String
    let primary: ToneQuadrant
    let secondary: ToneQuadrant
}

struct EditorTextCommand: Equatable {
    let id = UUID()
    let replacementRange: NSRange
    let replacementText: String
}

enum IterationPrototypeEngine {
    private static let leadIns = [
        "Sharper:",
        "Maybe this becomes:",
        "A louder pass:",
        "Try the softer version:",
        "Compressed idea:",
        "A weirder draft:"
    ]

    private static let bridges = [
        "and then pivot",
        "with less ceremony",
        "but warmer",
        "with more velocity",
        "and a cleaner edge",
        "with extra texture"
    ]

    private static let endings = [
        "for the first screen.",
        "before it goes visual.",
        "if the tone needs energy.",
        "while keeping the same point.",
        "for a faster read.",
        "without sounding final."
    ]

    static func makeCandidates(for text: String) -> [IterationCandidate] {
        let base = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return [] }

        let labels = ["Lean", "Punchy", "Warm", "Odd", "Direct", "Expanded"]
        let seed = seedValue(for: base)

        return labels.enumerated().map { index, label in
            let leadIn = leadIns[(seed + (index * 2)) % leadIns.count]
            let bridge = bridges[(seed + (index * 3)) % bridges.count]
            let ending = endings[(seed + (index * 5)) % endings.count]
            let variant = styledBase(for: base, variantIndex: index, seed: seed)

            return IterationCandidate(
                label: label,
                text: "\(leadIn) \(variant) \(bridge) \(ending)"
            )
        }
    }

    static func replacingText(in source: String, range: NSRange, with replacement: String) -> String? {
        guard let swiftRange = Range(range, in: source) else { return nil }

        var updated = source
        updated.replaceSubrange(swiftRange, with: replacement)
        return updated
    }

    private static func seedValue(for text: String) -> Int {
        text.unicodeScalars.reduce(0) { partialResult, scalar in
            ((partialResult * 31) + Int(scalar.value)) % 10_000
        }
    }

    private static func styledBase(for base: String, variantIndex: Int, seed: Int) -> String {
        switch variantIndex {
        case 0:
            return base.lowercased()
        case 1:
            return "\"\(base)\""
        case 2:
            return base.replacingOccurrences(of: " ", with: " / ")
        case 3:
            return "\(base). Again, but stranger"
        case 4:
            return base.uppercased()
        default:
            let token = ["tiny shift", "fresh angle", "second pass", "prototype energy"][(seed + variantIndex) % 4]
            return "\(base) with a \(token)"
        }
    }
}

enum ContextRipplePrototypeEngine {
    private struct SignalTemplate {
        let title: String
        let subtitle: (String) -> String
        let detail: (String, String) -> String
        let angleDegrees: Double
        let radiusUnit: Double
    }

    private static let templates: [SignalTemplate] = [
        SignalTemplate(
            title: "Dependency",
            subtitle: { token in "Needs \(token) loaded first" },
            detail: { token, selection in
                "\"\(selection)\" lands harder if the reader already understands \(token)."
            },
            angleDegrees: -112,
            radiusUnit: 0.36
        ),
        SignalTemplate(
            title: "Echo",
            subtitle: { token in "\(token) is humming nearby" },
            detail: { token, selection in
                "The draft is likely circling \(token) elsewhere, which makes this line feel like an echo rather than a new beat."
            },
            angleDegrees: -34,
            radiusUnit: 0.56
        ),
        SignalTemplate(
            title: "Question",
            subtitle: { token in "Reader asks why \(token)" },
            detail: { token, selection in
                "A curious reader will probably stop at \"\(selection)\" and ask what proves or explains \(token)."
            },
            angleDegrees: 16,
            radiusUnit: 0.43
        ),
        SignalTemplate(
            title: "Consequence",
            subtitle: { token in "\(token) changes what follows" },
            detail: { token, selection in
                "If this sentence is true, the next paragraphs need to show the consequence of \(token), not just restate it."
            },
            angleDegrees: 76,
            radiusUnit: 0.68
        ),
        SignalTemplate(
            title: "Term Anchor",
            subtitle: { token in "\(token) wants definition" },
            detail: { token, selection in
                "\"\(selection)\" introduces \(token) like a stable concept, but the draft probably has not anchored it yet."
            },
            angleDegrees: 144,
            radiusUnit: 0.5
        ),
        SignalTemplate(
            title: "Tension",
            subtitle: { token in "\(token) could push back" },
            detail: { token, selection in
                "This sentence has energy because \(token) may resist it. Surfacing that tension would make the idea feel earned."
            },
            angleDegrees: 222,
            radiusUnit: 0.74
        )
    ]

    static func makeSignals(for text: String) -> [ContextRippleSignal] {
        let base = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else { return [] }

        let seed = seedValue(for: base)
        let tokens = conceptTokens(from: base)

        return templates.enumerated().map { index, template in
            let token = tokens[(seed + (index * 3)) % tokens.count]
            let angleOffset = Double(((seed / max(index + 1, 1)) % 9) - 4)

            return ContextRippleSignal(
                title: template.title,
                subtitle: template.subtitle(token),
                detail: template.detail(token, base),
                angleDegrees: template.angleDegrees + angleOffset,
                radiusUnit: min(max(template.radiusUnit + (Double((seed + index) % 5) * 0.01) - 0.02, 0.28), 0.82)
            )
        }
    }

    private static func conceptTokens(from text: String) -> [String] {
        let stopWords: Set<String> = [
            "about", "after", "again", "because", "before", "being", "from",
            "have", "into", "just", "more", "really", "that", "their", "there",
            "these", "this", "those", "through", "very", "with", "would"
        ]

        let words = text
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { String($0) }

        var unique: [String] = []
        for word in words {
            let lowercased = word.lowercased()
            guard lowercased.count > 3 else { continue }
            guard !stopWords.contains(lowercased) else { continue }
            guard !unique.contains(where: { $0.caseInsensitiveCompare(word) == .orderedSame }) else { continue }
            unique.append(word)
        }

        if unique.isEmpty {
            let fallback = text
                .split(separator: " ")
                .prefix(2)
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return [fallback.isEmpty ? "this idea" : fallback]
        }

        return unique
    }

    private static func seedValue(for text: String) -> Int {
        text.unicodeScalars.reduce(0) { partialResult, scalar in
            ((partialResult * 31) + Int(scalar.value)) % 10_000
        }
    }
}

enum ToneMixerPrototypeEngine {
    static func sourcePoint(for text: String) -> CGPoint {
        switch text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "prototyping":
            return CGPoint(x: 0.11, y: 0.21)
        default:
            return CGPoint(x: 0.58, y: 0.58)
        }
    }

    static func preview(for text: String, x: Double, y: Double) -> TonePreviewResult {
        let base = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty else {
            return TonePreviewResult(text: "", primary: .advanced, secondary: .advanced)
        }

        let clampedX = min(max(x, 0), 1)
        let clampedY = min(max(y, 0), 1)
        let weights = quadrantWeights(x: clampedX, y: clampedY)
        let sorted = weights.sorted { lhs, rhs in
            if lhs.value == rhs.value {
                return lhs.key.title < rhs.key.title
            }
            return lhs.value > rhs.value
        }

        let primary = sorted.first?.key ?? .advanced
        let secondary = sorted.dropFirst().first?.key ?? primary
        let primaryWeight = sorted.first?.value ?? 1
        let secondaryWeight = sorted.dropFirst().first?.value ?? 0

        let intensityBucket = min(max(Int(primaryWeight * 3), 0), 2)
        let primaryPhrase = primaryPhrases[primary]?[intensityBucket] ?? "with a new tone"
        let secondaryPhrase = secondaryPhrases[secondary]?[min(max(Int(secondaryWeight * 2), 0), 1)] ?? "a touch of contrast"
        let columnBucket = min(Int(clampedX * 4), 3)
        let rowBucket = min(Int(clampedY * 3), 2)
        let motionPhrase = motionPhrases[rowBucket][columnBucket]
        let finishPhrase = finishPhrases[rowBucket]

        if let replacement = singleTokenReplacement(for: base, primary: primary, weights: weights) {
            return TonePreviewResult(
                text: replacement,
                primary: primary,
                secondary: secondary
            )
        }

        return TonePreviewResult(
            text: "\(base), \(primaryPhrase). \(motionPhrase). \(secondaryPhrase). \(finishPhrase).",
            primary: primary,
            secondary: secondary
        )
    }

    private static let primaryPhrases: [ToneQuadrant: [String]] = [
        .simple: [
            "in simpler words",
            "cleaner and easier to scan",
            "more direct, lighter, and easier to understand"
        ],
        .casual: [
            "with a more casual feel",
            "looser and more conversational",
            "warmer, quicker, and more natural"
        ],
        .formal: [
            "with more formal structure",
            "more polished and controlled",
            "more measured, precise, and composed"
        ],
        .advanced: [
            "with more advanced phrasing",
            "more nuanced and technically precise",
            "denser, more sophisticated, and more expert"
        ]
    ]

    private static let secondaryPhrases: [ToneQuadrant: [String]] = [
        .simple: [
            "Keep the idea easy to follow",
            "Leave the sentence clear at a glance"
        ],
        .casual: [
            "Keep a conversational edge",
            "Let it still feel natural in the mouth"
        ],
        .formal: [
            "Keep the phrasing tidy and composed",
            "Hold onto a polished finish"
        ],
        .advanced: [
            "Keep some sophistication in the wording",
            "Hold onto the more expert texture"
        ]
    ]

    private static let motionPhrases: [[String]] = [
        [
            "Open the wording up and let it feel lighter on its feet",
            "Keep the idea breezy but a little more intentional",
            "Tighten the read without losing the air in it",
            "Push the line forward with a cleaner hit"
        ],
        [
            "Let the sentence breathe while staying close to the original point",
            "Hold the center and smooth the rhythm out",
            "Sharpen the structure while keeping the tone controlled",
            "Give the delivery more grip and momentum"
        ],
        [
            "Soften the edge and give the line more room to settle",
            "Lower the energy slightly and make it feel steadier",
            "Bring the wording into a more grounded cadence",
            "Land the point with more weight and authority"
        ]
    ]

    private static let finishPhrases = [
        "The read stays quick",
        "The balance stays close to the source",
        "The finish feels more anchored"
    ]

    private struct WordAlternative {
        let replacement: String
        let toneWeights: [ToneQuadrant: Double]
    }

    private static let singleTokenAlternatives: [String: [WordAlternative]] = [
        "prototype": [
            WordAlternative(replacement: "draft", toneWeights: [.simple: 0.9, .casual: 0.55, .formal: 0.25, .advanced: 0.2]),
            WordAlternative(replacement: "mockup", toneWeights: [.simple: 0.65, .casual: 0.75, .formal: 0.35, .advanced: 0.55]),
            WordAlternative(replacement: "concept", toneWeights: [.simple: 0.35, .casual: 0.35, .formal: 0.75, .advanced: 0.7]),
            WordAlternative(replacement: "prototype", toneWeights: [.simple: 0.25, .casual: 0.35, .formal: 0.65, .advanced: 0.95]),
            WordAlternative(replacement: "model", toneWeights: [.simple: 0.1, .casual: 0.2, .formal: 0.65, .advanced: 1.05])
        ],
        "prototypes": [
            WordAlternative(replacement: "drafts", toneWeights: [.simple: 0.9, .casual: 0.55, .formal: 0.25, .advanced: 0.2]),
            WordAlternative(replacement: "mockups", toneWeights: [.simple: 0.65, .casual: 0.75, .formal: 0.35, .advanced: 0.55]),
            WordAlternative(replacement: "concepts", toneWeights: [.simple: 0.35, .casual: 0.35, .formal: 0.75, .advanced: 0.7]),
            WordAlternative(replacement: "prototypes", toneWeights: [.simple: 0.25, .casual: 0.35, .formal: 0.65, .advanced: 0.95]),
            WordAlternative(replacement: "models", toneWeights: [.simple: 0.1, .casual: 0.2, .formal: 0.65, .advanced: 1.05])
        ]
    ]

    private static let fixedQuadrantAlternatives: [String: [ToneQuadrant: String]] = [
        "prototyping": [
            .simple: "prototyping",
            .casual: "building mockups",
            .formal: "exploring ideas",
            .advanced: "experimenting with ideas"
        ]
    ]

    private static func singleTokenReplacement(
        for base: String,
        primary: ToneQuadrant,
        weights: [ToneQuadrant: Double]
    ) -> String? {
        guard isSingleToken(base) else { return nil }
        let normalizedBase = base.lowercased()

        if let replacement = fixedQuadrantAlternatives[normalizedBase]?[primary] {
            return applyingCasing(from: base, to: replacement)
        }

        guard let candidates = singleTokenAlternatives[normalizedBase] else { return nil }

        let best = candidates.max { lhs, rhs in
            score(lhs, with: weights) < score(rhs, with: weights)
        }

        guard let replacement = best?.replacement else { return nil }
        return applyingCasing(from: base, to: replacement)
    }

    private static func isSingleToken(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let tokenCount = trimmed
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" })
            .count

        return tokenCount == 1 && !trimmed.contains(where: \.isWhitespace)
    }

    private static func score(_ candidate: WordAlternative, with weights: [ToneQuadrant: Double]) -> Double {
        ToneQuadrant.allCases.reduce(0) { partialResult, quadrant in
            partialResult + (weights[quadrant] ?? 0) * (candidate.toneWeights[quadrant] ?? 0)
        }
    }

    private static func applyingCasing(from source: String, to replacement: String) -> String {
        if source == source.uppercased() {
            return replacement.uppercased()
        }

        if source == source.lowercased().capitalized {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }

        return replacement
    }

    private static func quadrantWeights(x: Double, y: Double) -> [ToneQuadrant: Double] {
        return [
            .simple: (1 - x) * (1 - y),
            .casual: x * (1 - y),
            .formal: (1 - x) * y,
            .advanced: x * y
        ]
    }
}
