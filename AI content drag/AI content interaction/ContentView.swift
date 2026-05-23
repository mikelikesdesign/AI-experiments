//
//  ContentView.swift
//  AI content interaction
//
//  Created by Michael Lee on 11/11/24.
//

import SwiftUI
import UIKit

final class ContentViewModel: ObservableObject {
    @Published var content = """
    Prototyping helps teams test ideas early, saving time and money by catching problems before they become expensive. Teams can touch and feel the product idea, spot issues, and get real feedback instead of guessing what might work. This hands-on approach makes it much easier to identify potential problems and opportunities for improvement.

    It's great for communication because everyone can see and understand the same thing. This stops confusion and helps explain ideas better than just talking about them. When showing ideas to clients, they can actually see how things will work. This visual and interactive approach helps everyone get on the same page quickly and makes feedback more meaningful.

    Teams can quickly try different solutions and learn from real user feedback. This makes it easier to fix problems early when changes are simple and cheap. Often, watching people use a prototype shows surprising things about how they really want to use the product. These insights help teams make better decisions and create products that users actually want.

    Making prototypes encourages designers to think through all the details of how something will actually work. This careful thinking leads to better solutions that really work for users. When designers create prototypes, they naturally discover edge cases and potential issues that might be missed in simple sketches or discussions.

    Prototypes also help developers understand what they need to build. When designers and developers work together on prototypes, they create better solutions that are both user-friendly and technically possible. This collaboration early in the process helps avoid technical surprises later and ensures the final product can be built efficiently while meeting user needs.
    """
    @Published var isLoading = false
    @Published var contentChanged = false
    @Published var streamingText = ""
    @Published var isStreaming = false

    private func streamContent(finalText: String) {
        isStreaming = true
        streamingText = ""

        let characters = Array(finalText)
        var index = 0

        Timer.scheduledTimer(withTimeInterval: 0.004, repeats: true) { timer in
            if index < characters.count {
                self.streamingText += String(characters[index])
                index += 1
            } else {
                timer.invalidate()
                self.content = self.streamingText
                self.isStreaming = false
            }
        }
    }

    func simplifyContent() {
        contentChanged = true
        let simplifiedText = """
        Prototyping allows teams to test ideas early, saving time and money by identifying issues and opportunities for improvement before they become costly. It provides a tangible way to explore and refine product concepts, enhancing communication by ensuring everyone shares a clear understanding. This hands-on approach enables meaningful feedback from clients and users, uncovering insights about real-world usage and guiding better decision-making. By encouraging detailed thinking, prototyping helps designers address edge cases and refine solutions, while fostering collaboration with developers to ensure the final product is user-friendly, technically feasible, and efficient to build.
        """
        streamContent(finalText: simplifiedText)
    }

    func learnMoreContent() {
        contentChanged = true
        let detailedText = """
        Prototyping stands as a cornerstone of effective product development, offering a sophisticated approach to risk mitigation and innovation validation. Through early-stage prototyping, organizations can comprehensively evaluate potential solutions while minimizing resource investment. This methodical approach enables stakeholders to engage with tangible representations of concepts, facilitating detailed usability assessment and generating invaluable feedback that would be impossible to glean from theoretical models or static presentations.

        The communicative power of prototypes surpasses traditional documentation methods, establishing a robust bridge between various stakeholders in the development process. This tangible demonstration of product vision creates an unambiguous reference point that synchronizes understanding across teams, substantially reducing the likelihood of costly misinterpretations. In client presentations, interactive prototypes demonstrate functional dynamics and user journeys with a clarity that far surpasses static mockups or verbal explanations.

        Prototyping's iterative nature exemplifies the principles of agile methodology and user-centered design. This approach enables teams to systematically evaluate multiple solution pathways, gathering empirical user data to inform refinements based on actual interactions rather than theoretical projections. The accelerated feedback loop facilitates early problem identification and resolution, significantly reducing the cost and complexity of implementing changes. Prototype testing frequently unveils critical insights into user behavior patterns and preferences that might remain hidden in conceptual analysis.

        The process of prototype development leads to a comprehensive examination of user experience considerations, guiding teams to address the practical implications of design decisions. This detailed exploration encompasses user flows, interaction states, and edge cases that might escape notice in static design phases. Such thorough investigation typically yields more sophisticated and thoughtful solutions that effectively balance user requirements with business objectives.

        From an implementation standpoint, prototypes serve as valuable technical feasibility studies. By constructing functional models of complex interactions and animations, design teams can validate technical viability while fostering productive collaboration with development teams. This synergistic approach often generates innovative solutions that successfully reconcile user experience goals with technical constraints, resulting in more robust and sustainable product implementations.

        The economic implications of prototyping extend far beyond initial development costs, fundamentally transforming the risk profile of product investments. By facilitating early validation and iteration, prototyping enables organizations to allocate resources more strategically, preventing substantial investments in fundamentally flawed concepts. This proactive risk management approach not only optimizes resource utilization but also accelerates time-to-market by ensuring development efforts are focused on validated solution pathways.

        Furthermore, prototyping serves as a catalyst for organizational learning and innovation culture development. Through the systematic creation and evaluation of prototypes, teams develop a shared vocabulary for discussing design challenges and solutions, fostering more effective cross-functional collaboration. This collaborative learning process enhances the organization's collective problem-solving capabilities, establishing a foundation for continuous innovation and adaptive response to evolving market demands.
        """
        streamContent(finalText: detailedText)
    }
}

enum ContentAction: String, CaseIterable {
    case simplify = "Simplify"
    case learnMore = "Learn More"
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    @State private var scrollOffset: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var showOptions = false
    @State private var actionRevealProgress: CGFloat = 0
    @State private var selectedAction: ContentAction = .simplify
    @State private var scrubOffset: CGFloat = 0
    @State private var isScrubbing = false
    @State private var scrollScrubAccumulator: CGFloat = 0
    @State private var lastScrollScrubTranslation: CGFloat = 0
    @State private var didScrubDuringScrollGesture = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isStreaming {
                scrollContent(text: viewModel.streamingText)
            } else {
                scrollContent(text: viewModel.content)
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        scrollOffset = offset
                        updateOptionsVisibility()
                    }
                    .onPreferenceChange(ContentHeightPreferenceKey.self) { height in
                        contentHeight = height
                        updateOptionsVisibility()
                    }
            }

            if showOptions && !viewModel.isStreaming {
                ContentActionScrubber(
                    selectedAction: $selectedAction,
                    scrubOffset: $scrubOffset,
                    isScrubbing: $isScrubbing,
                    revealProgress: actionRevealProgress
                ) { action in
                    performAction(action)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
                .transition(.opacity)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .onChange(of: selectedAction) { _, _ in
            guard showOptions else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func scrollContent(text: String) -> some View {
        ScrollView {
            GeometryReader { geometry in
                Color.clear.preference(
                    key: ScrollOffsetPreferenceKey.self,
                    value: geometry.frame(in: .named("scroll")).minY
                )
            }
            .frame(height: 0)

            Text(text)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 40)
                .padding(.bottom, 170)
                .animation(.none, value: text)
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: ContentHeightPreferenceKey.self,
                            value: geometry.size.height
                        )
                    }
                )
        }
        .coordinateSpace(name: "scroll")
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        scrollViewHeight = geometry.size.height
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        scrollViewHeight = newSize.height
                    }
            }
        )
        .simultaneousGesture(scrollScrubGesture)
    }

    private func updateOptionsVisibility() {
        let revealDistance: CGFloat = 150
        let maxScroll = max(contentHeight - scrollViewHeight, 0)
        let currentScroll = -scrollOffset
        let revealStart = max(maxScroll - revealDistance, 0)
        let rawProgress = contentHeight > scrollViewHeight
            ? (currentScroll - revealStart) / max(revealDistance, 1)
            : 0
        let clampedProgress = min(max(rawProgress, 0), 1)
        let shouldShow = clampedProgress > 0.01 && contentHeight > scrollViewHeight

        actionRevealProgress = clampedProgress

        guard shouldShow != showOptions else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            showOptions = shouldShow
        }

        if shouldShow {
            resetSelection()
        } else {
            resetScrubState()
        }
    }

    private func performAction(_ action: ContentAction) {
        withAnimation(.easeOut(duration: 0.2)) {
            showOptions = false
        }
        resetScrubState()

        switch action {
        case .simplify:
            selectedAction = .simplify
            viewModel.simplifyContent()
        case .learnMore:
            selectedAction = .simplify
            viewModel.learnMoreContent()
        }
    }

    private func resetSelection() {
        selectedAction = .simplify
        resetScrubState()
    }

    private func resetScrubState() {
        actionRevealProgress = showOptions ? actionRevealProgress : 0
        scrubOffset = 0
        isScrubbing = false
        scrollScrubAccumulator = 0
        lastScrollScrubTranslation = 0
        didScrubDuringScrollGesture = false
    }

    private var scrollScrubGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleScrollScrubChanged(value)
            }
            .onEnded { _ in
                handleScrollScrubEnded()
            }
    }

    private func handleScrollScrubChanged(_ value: DragGesture.Value) {
        guard showOptions || actionRevealProgress > 0.01 else {
            lastScrollScrubTranslation = value.translation.width
            return
        }

        let deltaX = value.translation.width - lastScrollScrubTranslation
        lastScrollScrubTranslation = value.translation.width

        guard abs(deltaX) > 0.5 else { return }

        isScrubbing = true
        scrubOffset += deltaX
        scrollScrubAccumulator += deltaX

        if abs(value.translation.width) > 18 {
            didScrubDuringScrollGesture = true
        }

        let stepThreshold: CGFloat = 26
        while scrollScrubAccumulator > stepThreshold {
            shiftSelection(by: 1)
            scrollScrubAccumulator -= stepThreshold
            scrubOffset = scrollScrubAccumulator
        }

        while scrollScrubAccumulator < -stepThreshold {
            shiftSelection(by: -1)
            scrollScrubAccumulator += stepThreshold
            scrubOffset = scrollScrubAccumulator
        }
    }

    private func handleScrollScrubEnded() {
        guard showOptions else {
            resetScrubState()
            return
        }

        if didScrubDuringScrollGesture {
            performAction(selectedAction)
        } else {
            isScrubbing = false
            scrollScrubAccumulator = 0
            lastScrollScrubTranslation = 0
            didScrubDuringScrollGesture = false
            withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) {
                scrubOffset = 0
            }
        }
    }

    private func shiftSelection(by delta: Int) {
        guard let currentIndex = ContentAction.allCases.firstIndex(of: selectedAction) else { return }
        let newIndex = max(0, min(ContentAction.allCases.count - 1, currentIndex + delta))
        guard newIndex != currentIndex else { return }

        didScrubDuringScrollGesture = true
        withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
            selectedAction = ContentAction.allCases[newIndex]
        }
    }
}

struct ContentActionScrubber: View {
    @Binding var selectedAction: ContentAction
    @Binding var scrubOffset: CGFloat
    @Binding var isScrubbing: Bool
    var revealProgress: CGFloat
    var onActionSelected: (ContentAction) -> Void

    @State private var lastDragPosition: CGFloat = 0
    @State private var dragSelectionAnchor: CGFloat = 0
    @State private var isDragging = false
    @Namespace private var selectionNamespace

    private var elasticProgress: CGFloat {
        let deadZone: CGFloat = 10
        let effectiveOffset = max(0, abs(scrubOffset) - deadZone)

        let threshold: CGFloat = 30
        let clamped = min(effectiveOffset / threshold, 1.5)
        let base = 1 - cos(min(clamped, 1.0) * .pi * 0.5)
        let overshoot = max(0, clamped - 1.0) * 0.25
        return base + overshoot
    }

    private var scrubTranslation: CGFloat {
        let deadZone: CGFloat = 10
        let sign: CGFloat = scrubOffset >= 0 ? 1 : -1
        let effectiveOffset = max(0, abs(scrubOffset) - deadZone) * sign

        let maxTranslation: CGFloat = 20
        let threshold: CGFloat = 40
        let normalized = effectiveOffset / threshold
        return max(-1, min(1, normalized)) * maxTranslation * (elasticProgress > 0 ? 1 : 0)
    }

    private var revealCurve: CGFloat {
        let clamped = min(max(revealProgress, 0), 1)
        return clamped * clamped * (3 - (2 * clamped))
    }

    private var pillRevealScale: CGFloat {
        0.32 + (revealCurve * 0.68)
    }

    private var textRevealOpacity: CGFloat {
        0.2 + (revealCurve * 0.8)
    }

    private var basePillColor: Color {
        Color.white.opacity(0.12)
    }

    private var selectedPillColor: Color {
        Color(red: 0.22, green: 0.54, blue: 1.0)
    }

    var body: some View {
        GeometryReader { geometry in
            let scrubberWidth = min(max(geometry.size.width - 36, 0), 292)
            let selectionStepThreshold = max((scrubberWidth / CGFloat(ContentAction.allCases.count)) * 0.18, 28)

            HStack(spacing: 18) {
                ForEach(ContentAction.allCases, id: \.self) { action in
                    let isSelected = selectedAction == action
                    let extraScale: CGFloat = isSelected && isScrubbing ? 0.12 * elasticProgress : 0
                    let pillScaleX = 1 + extraScale
                    let pillScaleY = 1 - (extraScale * 0.18)

                    ZStack {
                        Capsule()
                            .fill(basePillColor)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )

                        if isSelected {
                            Capsule()
                                .fill(selectedPillColor)
                                .matchedGeometryEffect(id: "selectedPill", in: selectionNamespace)
                                .scaleEffect(x: pillScaleX, y: pillScaleY)
                                .offset(x: scrubTranslation)
                                .shadow(color: selectedPillColor.opacity(0.35), radius: 18, y: 8)
                                .animation(.spring(response: 0.5, dampingFraction: 0.65), value: isScrubbing)
                        }

                        Text(action.rawValue)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(isSelected ? 1 : 0.86))
                            .lineLimit(1)
                            .minimumScaleFactor(0.9)
                            .padding(.horizontal, 15)
                            .opacity(textRevealOpacity)
                            .scaleEffect(0.86 + (revealCurve * 0.14))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .scaleEffect(pillRevealScale)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75), value: selectedAction)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isDragging else { return }
                        selectedAction = action
                        onActionSelected(action)
                    }
                }
            }
            .frame(width: scrubberWidth)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .opacity(0.2 + (revealCurve * 0.8))
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        isDragging = true
                        isScrubbing = true
                        let dragDelta = value.translation.width - lastDragPosition
                        let thresholdDelta = value.translation.width - dragSelectionAnchor
                        var nextScrubOffset = scrubOffset + dragDelta
                        let currentIndex = ContentAction.allCases.firstIndex(of: selectedAction) ?? 0

                        var newIndex = currentIndex
                        var overshoot = nextScrubOffset
                        if thresholdDelta > selectionStepThreshold && currentIndex < ContentAction.allCases.count - 1 {
                            newIndex = currentIndex + 1
                            dragSelectionAnchor = value.translation.width
                            overshoot = thresholdDelta - selectionStepThreshold
                        } else if thresholdDelta < -selectionStepThreshold && currentIndex > 0 {
                            newIndex = currentIndex - 1
                            dragSelectionAnchor = value.translation.width
                            overshoot = thresholdDelta + selectionStepThreshold
                        }

                        if newIndex != currentIndex {
                            withAnimation(.spring(response: 0.15, dampingFraction: 0.7)) {
                                selectedAction = ContentAction.allCases[newIndex]
                            }
                            nextScrubOffset = overshoot
                        }

                        lastDragPosition = value.translation.width
                        scrubOffset = nextScrubOffset
                    }
                    .onEnded { _ in
                        onActionSelected(selectedAction)
                        isDragging = false
                        isScrubbing = false
                        lastDragPosition = 0
                        dragSelectionAnchor = 0
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.45)) {
                            scrubOffset = 0
                        }
                    }
            )
        }
        .frame(height: 96)
    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
