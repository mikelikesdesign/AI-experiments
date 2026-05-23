//
//  ContentView.swift
//  video interaction
//
//  Created by Michael Lee on 11/22/25.
//

import SwiftUI

struct VideoInteractionView: View {
    @Environment(\.dismiss) private var dismiss

    let selectedModel: AIModelOption
    let onModelSelected: (AIModelOption) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging: Bool = false
    @State private var dragLocation: CGPoint = .zero
    @State private var startLocation: CGPoint = .zero
    @State private var shouldAnimateToCircle: Bool = false
    @State private var isPortalActive: Bool = false
    @State private var isClosing: Bool = false
    @State private var carouselOffset: CGFloat = 0
    @State private var selectedTapeIndex: Int? = nil
    @State private var isTapeIntroFinished = false

    init(
        selectedModel: AIModelOption = AIModelOption.defaultModel,
        onModelSelected: @escaping (AIModelOption) -> Void = { _ in }
    ) {
        self.selectedModel = selectedModel
        self.onModelSelected = onModelSelected
    }

    var body: some View {
        GeometryReader { geometry in
            let circleCenter = portalCenter(geometry: geometry)

            ZStack {
                // Background
                Color.white.edgesIgnoringSafeArea(.all)

                // Animated Portal Effect (behind tape)
                let maxDiameter: CGFloat = 290
                let currentDiameter = isClosing ? 0 : (shouldAnimateToCircle ? maxDiameter : circleDiameter(geometry: geometry))

                PortalView()
                    .frame(width: currentDiameter, height: currentDiameter)
                    .position(circleCenter)
                    .allowsHitTesting(false)

                // SceneKit view with tape carousel (on top of circle)
                let hideScene = isPortalActive && shouldAnimateToCircle
                VHSTapeSceneView(
                    selectedModel: selectedModel,
                    dragOffset: $dragOffset,
                    isDragging: $isDragging,
                    shouldAnimateToCircle: $shouldAnimateToCircle,
                    dragLocation: $dragLocation,
                    startLocation: $startLocation,
                    carouselOffset: $carouselOffset,
                    selectedTapeIndex: $selectedTapeIndex
                )
                .opacity(hideScene ? 0 : 1)
                .allowsHitTesting(!hideScene && isTapeIntroFinished)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let movement = sqrt(value.translation.width * value.translation.width + value.translation.height * value.translation.height)

                            // Only auto-select tape if dragging vertically/diagonally (not horizontal scrolling)
                            if selectedTapeIndex == nil && movement > 5 {
                                let isVerticalDrag = abs(value.translation.height) >= abs(value.translation.width)

                                if isVerticalDrag {
                                    // Detect which tape is being dragged based on start location
                                    let startX = value.startLocation.x
                                    let screenWidth = geometry.size.width
                                    let centerX = screenWidth / 2
                                    let relativeX = startX - centerX

                                    // Convert screen position to carousel index
                                    let sceneUnitsPerPixel: CGFloat = 0.01
                                    let sceneX = relativeX * sceneUnitsPerPixel
                                    let spacing = VHSTapeSceneMetrics.carouselSpacing
                                    let startX_scene: Float = -Float(VHSTapeSceneMetrics.carouselCount - 1) * spacing / 2.0

                                    // Find which tape index corresponds to this X position
                                    var closestIndex = 0
                                    var minDistance = Float.infinity

                                    for i in 0..<VHSTapeSceneMetrics.carouselCount {
                                        let tapeX = startX_scene + Float(i) * spacing
                                        let distance = abs(Float(sceneX) - tapeX)
                                        if distance < minDistance {
                                            minDistance = distance
                                            closestIndex = i
                                        }
                                    }

                                    if closestIndex >= 0 && closestIndex < VHSTapeSceneMetrics.carouselCount {
                                        selectedTapeIndex = closestIndex
                                    }
                                } else {
                                    // Horizontal scrolling - update carousel offset
                                    carouselOffset = value.translation.width
                                }
                            }

                            // If a tape is selected, allow dragging
                            if selectedTapeIndex != nil {
                                // Drag selected tape
                                if !isDragging {
                                    isDragging = true
                                    startLocation = value.startLocation
                                    isClosing = false
                                    withAnimation {
                                        isPortalActive = true
                                    }
                                }
                                dragOffset = value.translation
                                dragLocation = value.location
                            } else if movement > 5 {
                                // No tape selected - continue horizontal carousel scrolling
                                carouselOffset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            if selectedTapeIndex == nil {
                                // Handle carousel scrolling
                                carouselOffset = 0
                                dragLocation = .zero
                            } else {
                                // Check if tape is touching the circle at release
                                let distance = tapeDistanceFromCircleCenter(geometry: geometry)
                                let circleRadius = circleDiameter(geometry: geometry) / 2.0

                                if distance <= circleRadius {
                                    startPortalSequence()
                                } else {
                                    // Animate tape back to carousel position
                                    // The return animation will be handled by VHSTapeSceneView
                                    // Reset dragging state but keep selectedTapeIndex temporarily
                                    isDragging = false
                                    dragOffset = .zero
                                    dragLocation = .zero
                                    shouldAnimateToCircle = false
                                    withAnimation {
                                        isPortalActive = false
                                    }

                                    // Reset selection after a delay to allow return animation
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        selectedTapeIndex = nil
                                    }
                                }
                            }
                        }
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Color.black))
                            .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back to chat")
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom - 32, 0))
                }
                .zIndex(4)
            }
            .onAppear {
                isTapeIntroFinished = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) {
                    isTapeIntroFinished = true
                }
            }
        }
    }

    // Calculate the distance of the tape from the circle center in screen space
    private func tapeDistanceFromCircleCenter(geometry: GeometryProxy) -> CGFloat {
        // Calculate distance from finger's screen position to screen center
        let circleCenter = portalCenter(geometry: geometry)
        let dx = dragLocation.x - circleCenter.x
        let dy = dragLocation.y - circleCenter.y
        let distance = sqrt(dx * dx + dy * dy)
        return distance
    }

    private func portalCenter(geometry: GeometryProxy) -> CGPoint {
        CGPoint(x: geometry.size.width / 2, y: geometry.size.height * 0.44)
    }

    // Calculate the diameter of the circle based on tape's proximity to the center
    private func circleDiameter(geometry: GeometryProxy) -> CGFloat {
        let minDiameter: CGFloat = 44
        let maxDiameter: CGFloat = 290

        guard isDragging && selectedTapeIndex != nil else {
            return minDiameter
        }

        // Use geometry dimensions to determine max distance
        // Circle should be smallest at screen edges
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        let maxDistance = sqrt(screenWidth * screenWidth + screenHeight * screenHeight) / 2.0

        let distance = tapeDistanceFromCircleCenter(geometry: geometry)

        // Circle is largest when tape is at center (distance = 0)
        // Circle gets smaller as tape moves away from center
        if distance >= maxDistance {
            return minDiameter
        }

        // Normalize distance: 0 = at center, 1 = at maxDistance
        let normalizedDistance = distance / maxDistance
        // Invert so 0 = largest, 1 = smallest
        let sizeFactor = 1.0 - normalizedDistance
        let diameter = minDiameter + (maxDiameter - minDiameter) * sizeFactor
        return diameter
    }

    private func startPortalSequence() {
        if let model = selectedModelForCurrentTape() {
            onModelSelected(model)
        }

        isPortalActive = true
        isClosing = false

        withAnimation(.easeOut(duration: 0.35)) {
            shouldAnimateToCircle = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            dismiss()
        }
    }

    private func selectedModelForCurrentTape() -> AIModelOption? {
        guard let selectedTapeIndex, !AIModelOption.all.isEmpty else { return nil }
        return AIModelOption.all[selectedTapeIndex % AIModelOption.all.count]
    }
}

struct VideoInteractionView_Previews: PreviewProvider {
    static var previews: some View {
        VideoInteractionView(selectedModel: AIModelOption.defaultModel)
    }
}
