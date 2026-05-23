//
//  content_ideasTests.swift
//  content ideasTests
//
//  Created by Michael Lee on 4/21/26.
//

import Foundation
import Testing
@testable import content_ideas

struct content_ideasTests {

    @MainActor
    @Test func mockIterationsReturnStableFilledResults() async throws {
        let candidates = IterationPrototypeEngine.makeCandidates(for: "Prototype the interaction before the AI is real.")

        #expect(candidates.count == 6)
        #expect(candidates.allSatisfy { !$0.text.isEmpty })
        #expect(Set(candidates.map { $0.text }).count == candidates.count)
    }

    @MainActor
    @Test func replacementUsesTheExactSelectedRange() async throws {
        let source = "Alpha Beta Gamma"
        let range = (source as NSString).range(of: "Beta")

        let updated = IterationPrototypeEngine.replacingText(
            in: source,
            range: range,
            with: "Delta"
        )

        #expect(updated == "Alpha Delta Gamma")
    }

    @MainActor
    @Test func replacementRejectsInvalidRanges() async throws {
        let updated = IterationPrototypeEngine.replacingText(
            in: "Short text",
            range: NSRange(location: 40, length: 4),
            with: "Nope"
        )

        #expect(updated == nil)
    }

    @MainActor
    @Test func toneMixerFollowsQuadrantsAndChangesPreview() async throws {
        let source = "Launch energy fades unless the opening idea keeps pulling the reader forward"

        let playful = ToneMixerPrototypeEngine.preview(for: source, x: 0.1, y: 0.1)
        let bold = ToneMixerPrototypeEngine.preview(for: source, x: 0.9, y: 0.1)
        let poetic = ToneMixerPrototypeEngine.preview(for: source, x: 0.1, y: 0.9)
        let professional = ToneMixerPrototypeEngine.preview(for: source, x: 0.9, y: 0.9)

        #expect(playful.primary == .playful)
        #expect(bold.primary == .bold)
        #expect(poetic.primary == .poetic)
        #expect(professional.primary == .professional)
        #expect(Set([playful.text, bold.text, poetic.text, professional.text]).count == 4)
    }

    @MainActor
    @Test func toneMixerAddsNoticeableHorizontalVariation() async throws {
        let source = "Motion should teach the interaction before the interface explains it"

        let left = ToneMixerPrototypeEngine.preview(for: source, x: 0.08, y: 0.22)
        let center = ToneMixerPrototypeEngine.preview(for: source, x: 0.48, y: 0.22)
        let right = ToneMixerPrototypeEngine.preview(for: source, x: 0.88, y: 0.22)

        #expect(Set([left.text, center.text, right.text]).count == 3)
    }
}
