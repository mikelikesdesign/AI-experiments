//
//  VHSTapeSceneView.swift
//  video interaction
//
//  Created by Michael Lee on 11/22/25.
//

import SwiftUI
import SceneKit

enum VHSTapeSceneMetrics {
    static var carouselCount: Int { AIModelOption.all.count }
    static let carouselY: Float = -5.95
    static let carouselZ: Float = 0.0
    static let carouselSpacing: Float = 1.7
    static let carouselScale: Float = 2.38
    static let selectedTapeY: Float = -3.9
    static let selectedTapeScale: Float = 2.88
    static let cameraPosition = SCNVector3(0, 0.5, 12)
    static let introCameraPosition = SCNVector3(0, 2.8, 180)
    static let cameraFieldOfView: CGFloat = 90
    static let introCameraFieldOfView: CGFloat = 100
}

struct VHSTapeSceneView: UIViewRepresentable {
    let selectedModel: AIModelOption

    @Binding var dragOffset: CGSize
    @Binding var isDragging: Bool
    @Binding var shouldAnimateToCircle: Bool
    @Binding var dragLocation: CGPoint
    @Binding var startLocation: CGPoint
    @Binding var carouselOffset: CGFloat
    @Binding var selectedTapeIndex: Int?

    func makeUIView(context: Context) -> SCNView {
        let scnView = SCNView()
        scnView.scene = context.coordinator.scene
        scnView.allowsCameraControl = false
        scnView.autoenablesDefaultLighting = false
        scnView.backgroundColor = UIColor.clear // Make background transparent so circle shows through
        scnView.antialiasingMode = .multisampling4X
        scnView.isPlaying = true

        // Store reference to SCNView in coordinator for unprojectPoint
        context.coordinator.scnView = scnView
        context.coordinator.startIntroZoom()

        return scnView
    }

    func updateUIView(_ scnView: SCNView, context: Context) {
        // Update carousel offset for scrolling only when no tape is selected
        if selectedTapeIndex == nil {
            context.coordinator.updateCarouselOffset(carouselOffset)
        }

        // Handle tape selection
        if let selectedIndex = selectedTapeIndex, selectedIndex != context.coordinator.selectedIndex {
            context.coordinator.selectTape(at: selectedIndex, isDragging: isDragging)
        }

        // Handle deselection (return to carousel)
        if selectedTapeIndex == nil && context.coordinator.selectedIndex != nil {
            context.coordinator.resetCarousel()
        }

        // Handle circle animation trigger FIRST - before any other updates
        if shouldAnimateToCircle {
            // Only animate if not already animating
            if !context.coordinator.isAnimatingToCircle {
                context.coordinator.animateToCircleCenter(
                    onTapeGone: {
                        // This runs when the tape has fully disappeared into the distance
                        DispatchQueue.main.async {
                            shouldAnimateToCircle = false
                            dragOffset = .zero
                            isDragging = false
                            selectedTapeIndex = nil
                        }
                    },
                    completion: {
                        // Animation sequence fully complete
                    }
                )
            }
            // CRITICAL: Return early to prevent return animation
            return
        }

        // Only update transform if NOT animating to circle and a tape is selected
        // This ensures return animation only happens when shouldAnimateToCircle is false
        if !context.coordinator.isAnimatingToCircle && selectedTapeIndex != nil {
            context.coordinator.updateTransform(
                dragOffset: dragOffset,
                isDragging: isDragging,
                dragLocation: dragLocation,
                startLocation: startLocation,
                scnView: scnView
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedModel: selectedModel)
    }

    class Coordinator {
        let selectedModel: AIModelOption
        let scene: SCNScene
        let tapeNode: SCNNode
        let tapeNode2: SCNNode
        let cameraNode: SCNNode
        let lightNode: SCNNode

        // Carousel tapes
        var carouselTapes: [SCNNode] = []
        let carouselCount = VHSTapeSceneMetrics.carouselCount // Number of tapes in carousel
        var selectedIndex: Int? = nil // Currently selected tape index
        var carouselScrollOffset: Float = 0 // Current scroll offset

        // Reference to SCNView for coordinate conversion
        weak var scnView: SCNView?

        // Original positions for return animation
        let originalCameraPosition: SCNVector3
        let originalCameraRotation: SCNVector4
        let originalTapePosition: SCNVector3
        let originalTapeRotation: SCNVector4

        // Track if we've animated to flat position
        var hasAnimatedToFlat: Bool = false
        var isAnimatingToCircle: Bool = false
        var hasStartedIntroZoom: Bool = false

        // Track which tape is currently active (the one being dragged)
        var activeTape: SCNNode
        init(selectedModel: AIModelOption) {
            self.selectedModel = selectedModel
            scene = SCNScene()

            // Create placeholder active tape (will be replaced by carousel selection)
            tapeNode = VHSTapeModel.createTape(label: AIModelOption.defaultModel.tapeLabel)
            tapeNode.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
            tapeNode.position = SCNVector3(0, -1.0, 0)
            tapeNode.opacity = 0.0 // Hidden initially
            scene.rootNode.addChildNode(tapeNode)

            // Create second VHS tape model (backup)
            tapeNode2 = VHSTapeModel.createTape(label: AIModelOption.defaultModel.tapeLabel)
            tapeNode2.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
            tapeNode2.position = SCNVector3(0, -10, 0)
            tapeNode2.opacity = 0.0
            scene.rootNode.addChildNode(tapeNode2)

            // Set first tape as active (temporary)
            activeTape = tapeNode

            // Setup camera for shelf view (looking at tape from front, slightly elevated)
            cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.camera?.fieldOfView = VHSTapeSceneMetrics.cameraFieldOfView
            originalCameraPosition = VHSTapeSceneMetrics.cameraPosition
            originalCameraRotation = SCNVector4(0, 0, 0, 0)
            cameraNode.position = VHSTapeSceneMetrics.introCameraPosition
            cameraNode.rotation = originalCameraRotation
            scene.rootNode.addChildNode(cameraNode)

            // Setup lighting
            lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light?.type = .omni
            lightNode.position = SCNVector3(0, 10, 10)
            lightNode.light?.intensity = 1000
            scene.rootNode.addChildNode(lightNode)

            // Add ambient light
            let ambientLight = SCNNode()
            ambientLight.light = SCNLight()
            ambientLight.light?.type = .ambient
            ambientLight.light?.intensity = 500
            scene.rootNode.addChildNode(ambientLight)

            // Store original tape transform (shelf view - standing upright, at bottom)
            originalTapePosition = SCNVector3(0, VHSTapeSceneMetrics.carouselY, VHSTapeSceneMetrics.carouselZ)
            originalTapeRotation = SCNVector4(0, 1, 0, Float.pi / 2)

            // Create horizontal carousel of tapes (after all properties are initialized)
            setupCarousel()
        }

        func setupCarousel() {
            // Create horizontal carousel of tapes
            let carouselY = VHSTapeSceneMetrics.carouselY
            let carouselZ = VHSTapeSceneMetrics.carouselZ
            let spacing = VHSTapeSceneMetrics.carouselSpacing
            let startX: Float = -Float(carouselCount - 1) * spacing / 2.0 // Center the carousel

            for i in 0..<carouselCount {
                let model = AIModelOption.all[i % AIModelOption.all.count]
                let tape = VHSTapeModel.createTape(
                    label: model.tapeLabel,
                    isSelected: model == selectedModel
                )
                tape.eulerAngles = SCNVector3(0, Float.pi / 2, 0)

                // Position tapes horizontally
                let x = startX + Float(i) * spacing
                tape.position = SCNVector3(x, carouselY, carouselZ)

                // All tapes face forward
                tape.eulerAngles.y = Float.pi / 2.0

                // Scale for carousel visibility - larger size
                let scale = VHSTapeSceneMetrics.carouselScale
                tape.scale = SCNVector3(scale, scale, scale)
                tape.opacity = 1.0

                scene.rootNode.addChildNode(tape)
                carouselTapes.append(tape)
            }
        }

        func startIntroZoom() {
            guard !hasStartedIntroZoom else { return }
            hasStartedIntroZoom = true

            cameraNode.position = VHSTapeSceneMetrics.introCameraPosition
            cameraNode.camera?.fieldOfView = VHSTapeSceneMetrics.introCameraFieldOfView
            carouselTapes.forEach { $0.opacity = 1.0 }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 1.7
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.12, 0.0, 0.08, 1.0)

                self.cameraNode.position = self.originalCameraPosition
                self.cameraNode.rotation = self.originalCameraRotation
                self.cameraNode.camera?.fieldOfView = VHSTapeSceneMetrics.cameraFieldOfView
                self.carouselTapes.forEach { $0.opacity = 1.0 }

                SCNTransaction.commit()
            }
        }

        func updateCarouselOffset(_ offset: CGFloat) {
            // Update carousel scroll position
            let spacing = VHSTapeSceneMetrics.carouselSpacing
            let scrollOffset = Float(offset) * 0.01 // Convert screen pixels to scene units

            for (i, tape) in carouselTapes.enumerated() {
                let startX: Float = -Float(carouselCount - 1) * spacing / 2.0
                let baseX = startX + Float(i) * spacing
                tape.position.x = baseX + scrollOffset
            }
        }

        func selectTape(at index: Int, isDragging: Bool = false) {
            guard index >= 0 && index < carouselTapes.count else { return }

            selectedIndex = index
            let selectedTape = carouselTapes[index]
            let carouselY = VHSTapeSceneMetrics.carouselY
            let selectedY = VHSTapeSceneMetrics.selectedTapeY

            // Only animate selected tape to center if NOT dragging
            // When dragging, updateTransform will handle the selected tape position
            if !isDragging {
                SCNTransaction.begin()
                SCNTransaction.animationDuration = 0.5
                SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)

                selectedTape.position = SCNVector3(0, selectedY, 0) // Center X, higher Y position
                let selectedScale = VHSTapeSceneMetrics.selectedTapeScale
                selectedTape.scale = SCNVector3(selectedScale, selectedScale, selectedScale)
                selectedTape.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
                selectedTape.opacity = 1.0

                SCNTransaction.commit()
            }

            // Always animate other tapes off screen (left or right)
            for (i, tape) in carouselTapes.enumerated() {
                if i != index {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.4
                    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeIn)

                    // Slide tapes off screen - left for tapes before, right for tapes after
                    let direction: Float = Float(i) < Float(index) ? -20.0 : 20.0
                    tape.position = SCNVector3(direction, carouselY, 0)
                    // Keep opacity at 1.0 - slide off instead of fade

                    SCNTransaction.commit()
                }
            }

            // Set selected tape as active
            activeTape = selectedTape
        }

        func animateTapeToCarousel(at index: Int) {
            guard index >= 0 && index < carouselTapes.count else { return }

            let tape = carouselTapes[index]
            let carouselY = VHSTapeSceneMetrics.carouselY
            let carouselZ = VHSTapeSceneMetrics.carouselZ
            let spacing = VHSTapeSceneMetrics.carouselSpacing
            let startX: Float = -Float(carouselCount - 1) * spacing / 2.0
            let x = startX + Float(index) * spacing

            // Animate tape back to its carousel position
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.6
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)

            tape.position = SCNVector3(x, carouselY, carouselZ)
            let carouselScale = VHSTapeSceneMetrics.carouselScale
            tape.scale = SCNVector3(carouselScale, carouselScale, carouselScale)
            tape.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
            tape.opacity = 1.0

            SCNTransaction.commit()

            // Bring other tapes back into view
            for (i, otherTape) in carouselTapes.enumerated() {
                if i != index {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.6
                    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)

                    let otherX = startX + Float(i) * spacing
                    otherTape.position = SCNVector3(otherX, carouselY, carouselZ)
                    otherTape.scale = SCNVector3(carouselScale, carouselScale, carouselScale)
                    otherTape.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
                    otherTape.opacity = 1.0

                    SCNTransaction.commit()
                }
            }
        }

        func resetCarousel() {
            // Reset all tapes back to carousel positions
            let carouselY = VHSTapeSceneMetrics.carouselY
            let carouselZ = VHSTapeSceneMetrics.carouselZ
            let spacing = VHSTapeSceneMetrics.carouselSpacing
            let startX: Float = -Float(carouselCount - 1) * spacing / 2.0

            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.6
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)

            for (i, tape) in carouselTapes.enumerated() {
                let x = startX + Float(i) * spacing
                tape.position = SCNVector3(x, carouselY, carouselZ)
                let carouselScale = VHSTapeSceneMetrics.carouselScale
                tape.scale = SCNVector3(carouselScale, carouselScale, carouselScale)
                tape.eulerAngles = SCNVector3(0, Float.pi / 2, 0)
                tape.opacity = 1.0
            }

            SCNTransaction.commit()

            selectedIndex = nil
        }

        func updateTransform(dragOffset: CGSize, isDragging: Bool, dragLocation: CGPoint, startLocation: CGPoint, scnView: SCNView) {
            if isDragging {
                // Transform tape: follow finger and rotate sideways at fixed angle
                // Start from shelf position (90 degrees on Y) and rotate sideways consistently
                let baseRotationY = Float.pi / 2
                let rotationY = baseRotationY // Keep Y rotation

                // Fixed sideways rotation - rotate to make it completely flat (horizontal)
                let rotationZ: Float = Float.pi / 2 // Rotate +90 degrees to lay on left side
                let rotationX: Float = 0.0 // No tilt

                // Animate rotation smoothly when first starting to drag
                if !hasAnimatedToFlat {
                    SCNTransaction.begin()
                    SCNTransaction.animationDuration = 0.3
                    SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)

                    activeTape.eulerAngles = SCNVector3(
                        rotationX,
                        rotationY,
                        rotationZ
                    )

                    SCNTransaction.commit()
                    hasAnimatedToFlat = true
                } else {
                    // After initial animation, update rotation directly for smooth following
                    activeTape.eulerAngles = SCNVector3(
                        rotationX,
                        rotationY,
                        rotationZ
                    )
                }

                // Convert dragLocation to view coordinates (accounting for view's coordinate system)
                let viewX = Float(dragLocation.x)
                let viewY = Float(dragLocation.y)

                // Unproject at near and far planes to get a ray
                let nearPoint = SCNVector3(viewX, viewY, 0.0) // Near plane (z=0)
                let farPoint = SCNVector3(viewX, viewY, 1.0) // Far plane (z=1)

                // Convert to world coordinates
                let worldNear = scnView.unprojectPoint(nearPoint)
                let worldFar = scnView.unprojectPoint(farPoint)

                // Calculate the world position at the tape's Z depth
                let direction = SCNVector3(
                    worldFar.x - worldNear.x,
                    worldFar.y - worldNear.y,
                    worldFar.z - worldNear.z
                )

                // Avoid division by zero
                guard abs(direction.z) > 0.0001 else {
                    // If direction is parallel to Z plane, use current position
                    return
                }

                // Find intersection with plane at tape's Z position
                let t = (originalTapePosition.z - worldNear.z) / direction.z
                let worldPosition = SCNVector3(
                    worldNear.x + direction.x * t,
                    worldNear.y + direction.y * t, // Allow full Y movement for visual feedback
                    originalTapePosition.z
                )

                // Update position immediately without transaction for smooth live dragging
                activeTape.position = worldPosition

                // Keep camera stable so tape stays in view
                cameraNode.rotation = originalCameraRotation
                cameraNode.position = originalCameraPosition
            } else if !isAnimatingToCircle {
                // Reset flag for next drag
                hasAnimatedToFlat = false

                // When dragging ends away from portal, return tape to carousel position
                // Only if a tape is selected
                if selectedIndex != nil {
                    // Return the active tape to its carousel position
                    animateTapeToCarousel(at: selectedIndex!)
                    cameraNode.position = originalCameraPosition
                    cameraNode.rotation = originalCameraRotation
                }
            }
        }

        func animateToCircleCenter(onTapeGone: @escaping () -> Void, completion: @escaping () -> Void) {
            // Prevent multiple animations
            guard !isAnimatingToCircle else { return }
            isAnimatingToCircle = true

            let currentTape = activeTape

            // Animate tape forward into deep space like a spaceship
            let currentPosition = currentTape.position
            // Move much further away into deep space for dramatic effect
            let deepSpacePosition = SCNVector3(currentPosition.x, currentPosition.y, -150)

            // Use a longer, more dramatic animation with easeIn for acceleration effect
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 4.0 // Much slower, more dramatic journey into space
            // Custom timing function: starts slow, accelerates into the distance (like a spaceship)
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(controlPoints: 0.1, 0.0, 0.3, 1.0)

            currentTape.position = deepSpacePosition
            // Shrink dramatically as it goes into the distance (but not completely to 0 for perspective)
            currentTape.scale = SCNVector3(0.05, 0.05, 0.05) // Very small but still visible for depth
            // Fade out gradually as it disappears into the void
            currentTape.opacity = 0.0

            SCNTransaction.commit()

            // Trigger portal close after tape has traveled into space (4.0s)
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                onTapeGone()

                // Reset carousel and selection after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.resetCarousel()
                    self.isAnimatingToCircle = false
                    self.hasAnimatedToFlat = false
                    completion()
                }
            }
        }

    }
}
