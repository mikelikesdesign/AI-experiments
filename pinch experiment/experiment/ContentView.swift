//
//  ContentView.swift
//  experiment
//
//  Created by Michael Lee on 2/7/26.
//

import SwiftUI
import UIKit
import SceneKit

// MARK: - App Phase

enum AppPhase: Equatable {
    case reading
    case folding
    case returning
    case loading
    case summary
}

// MARK: - Article Content

enum ArticleContent {
    struct Section: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let body: String
    }

    static let title = "SwiftUI Overview"
    static let subtitle = "Apple's modern framework for building beautiful, native user interfaces across all platforms with the power of Swift."

    static let sections: [Section] = [
        Section(
            icon: "curlybraces",
            title: "Declarative Syntax",
            body: "SwiftUI uses a declarative programming model that lets you describe what your user interface should look like for any given state, rather than writing step-by-step instructions to mutate the view hierarchy. When the underlying data changes, the framework automatically computes the minimal set of differences and applies them to the screen. This eliminates an entire category of bugs related to out-of-sync UI and forgotten update paths. You simply declare the relationship between state and view, and SwiftUI takes care of the rest, including rendering, diffing, layout, and animation, all all handled behind the scenes with no imperative code required."
        ),
        Section(
            icon: "arrow.triangle.2.circlepath",
            title: "Reactive Data Flow",
            body: "At the heart of SwiftUI lies a reactive data pipeline built on property wrappers like @State, @Binding, @StateObject, @ObservedObject, and the newer @Observable macro. These tools establish a clear ownership model: each piece of data has a single source of truth, and any view that reads that data is automatically subscribed to changes. When a value updates, whether from a user interaction, a network response, or a timer, every dependent view re-evaluates and re-renders instantly. This architecture scales naturally from a single toggle to a complex multi-screen application with deeply nested state, keeping your code predictable and easy to reason about."
        ),
        Section(
            icon: "macbook.and.iphone",
            title: "Cross-Platform",
            body: "One of SwiftUI's most compelling promises is write-once, run-anywhere within the Apple ecosystem. A single SwiftUI codebase can target iOS, iPadOS, macOS, watchOS, tvOS, and visionOS, automatically adapting to each platform's design language, interaction patterns, and screen dimensions. Navigation stacks become sidebars on iPad and macOS; buttons adopt the correct haptics on watchOS; and spatial layouts gain depth on visionOS. Platform-specific APIs are still available when you need pixel-perfect control, but the shared foundation dramatically reduces the amount of code you need to write, test, and maintain across devices."
        ),
        Section(
            icon: "eye",
            title: "Live Previews",
            body: "Xcode's canvas renders real-time previews of your SwiftUI views as you type, giving you immediate visual feedback without waiting for a full build-and-run cycle. You can create multiple preview configurations to see your view in different device sizes, color schemes, accessibility settings, and localized languages, all side by side. Previews are interactive too: you can tap buttons, scroll lists, and trigger state changes directly in the canvas. This tight feedback loop accelerates iteration and makes it practical to polish micro-interactions, spacing, and typography before ever launching the simulator."
        ),
        Section(
            icon: "wand.and.stars",
            title: "Built-in Animations",
            body: "Animation is deeply integrated into SwiftUI. Adding motion to your interface is often as simple as wrapping a state change in withAnimation or attaching an .animation modifier to a view. The framework ships with a rich library of timing curves including linear, easeIn, easeOut, spring, and interpolating spring. It handles interruption gracefully so animations blend smoothly when the user interacts mid-flight. Matched geometry effects let you create hero transitions between views, phase animators drive multi-step sequences, and keyframe animators give you fine-grained control over complex choreography. The result is fluid, polished motion that feels native to the platform with minimal code."
        ),
        Section(
            icon: "paintbrush.pointed",
            title: "Composable Modifiers",
            body: "SwiftUI's modifier pattern is one of its most elegant design decisions. Every visual property like padding, background, shadow, clip shape, rotation, and opacity is expressed as a modifier that wraps the view in a new layer. Because modifiers return new views, they can be chained in any order to build up complex appearances from simple, reusable pieces. You can extract common modifier chains into custom ViewModifier types, create conditional modifiers with extensions, and compose them freely across your app. This compositional approach keeps your code readable, testable, and customizable without the rigid structure or style sheets found in other frameworks."
        ),
    ]

    static let summaryPoints: [(icon: String, title: String, text: String)] = [
        ("curlybraces", "Declarative Syntax", "Describe your UI for any given state and SwiftUI handles rendering, diffing, and updates automatically."),
        ("arrow.triangle.2.circlepath", "Reactive Data Flow", "Property wrappers like @State and @Binding keep views synchronized with your data model."),
        ("macbook.and.iphone", "Cross-Platform", "Write once, deploy everywhere: iOS, macOS, watchOS, tvOS, and visionOS."),
        ("eye", "Live Previews", "Real-time Xcode previews across device sizes, color schemes, and accessibility settings."),
        ("wand.and.stars", "Built-in Animations", "Springs, easing curves, and transitions with a single modifier for fluid motion with minimal code."),
        ("paintbrush.pointed", "Composable Modifiers", "Chain reusable modifiers to style and transform views without layered abstractions."),
    ]
}

// MARK: - Reading Content View

struct ReadingContentView: View {
    var body: some View {
        Text("Apple's modern framework for building native user interfaces across all platforms with the power of Swift. SwiftUI uses a declarative programming model where you describe what your interface should look like for any given state, and the framework handles rendering, diffing, and updates automatically. Property wrappers like @State and @Binding create a reactive pipeline where data changes instantly propagate to every dependent view. A single codebase adapts to iOS, macOS, watchOS, tvOS, and visionOS, respecting each platform's conventions. Xcode renders real-time previews as you type, letting you iterate on designs effectively. Fluid animations are built right in. Add springs, easing curves, and transitions with a single modifier. The composable modifier pattern keeps code readable and customizable without rigid structure. Getting started is straightforward: create a new project, choose the SwiftUI app template, and begin composing views. The framework's depth reveals itself as you explore custom layouts, geometry readers, and the layout protocol. Community resources and sample code are abundant, making it one of the most accessible UI frameworks Apple has ever shipped. Whether you are building a simple utility or an ambitious multi-platform experience, SwiftUI provides the tools to move quickly without effecting quality. Each year at WWDC, Apple introduces new capabilities like navigation stacks, custom layout protocols, scroll view enhancements, and deeper interoperability with UIKit and AppKit, ensuring the framework stays up to date with modern app development.")
            .font(.system(size: 14))
            .foregroundStyle(Color(white: 0.3))
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
        .padding(28)
        .padding(.top, 20)
        .safeAreaPadding(.top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.white)
        .ignoresSafeArea()
    }
}

// MARK: - Summary Content View

struct SummaryContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "swift")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(.orange.gradient)

                Text(ArticleContent.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
            }

            Divider()

            // Key points
            ForEach(Array(ArticleContent.summaryPoints.enumerated()), id: \.offset) { _, point in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: point.icon)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.blue)
                        .frame(width: 26, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: 0.9, green: 0.93, blue: 1.0))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(point.title)
                            .font(.system(size: 14, weight: .semibold))
                        Text(point.text)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(white: 0.45))
                            .lineSpacing(2)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white)
    }
}

// MARK: - Pinch Zoom Background

enum SpaceAnimationMode: Equatable {
    case inactive
    case pinch
    case summarizing
    case overview
}

struct PinchZoomBackgroundView: UIViewRepresentable {
    let pinchAmount: CGFloat
    let isActive: Bool
    let mode: SpaceAnimationMode

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView(frame: .zero)
        sceneView.scene = makePinchZoomScene()
        sceneView.backgroundColor = .black
        sceneView.allowsCameraControl = false
        sceneView.isPlaying = true
        sceneView.antialiasingMode = .multisampling2X

        if let scene = sceneView.scene {
            context.coordinator.attach(to: scene)
        }

        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.update(
            mode: mode,
            pinchAmount: isActive ? pinchAmount : 0
        )
    }

    final class Coordinator: NSObject {
        private var displayLink: CADisplayLink?
        private weak var animationController: PinchZoomAnimationController?

        func attach(to scene: SCNScene) {
            scene.rootNode.enumerateChildNodes { node, _ in
                if self.animationController == nil {
                    self.animationController = node as? PinchZoomAnimationController
                }
            }

            guard displayLink == nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        func update(mode: SpaceAnimationMode, pinchAmount amount: CGFloat) {
            animationController?.setAnimationMode(mode)
            animationController?.setTargetPinchAmount(amount)
        }

        @objc private func tick() {
            animationController?.updateFrame()
        }

        deinit {
            displayLink?.invalidate()
        }
    }
}

private func makePinchZoomScene() -> SCNScene {
    let scene = SCNScene()

    let camera = SCNCamera()
    camera.fieldOfView = 95
    camera.zNear = 0.1
    camera.zFar = 220

    let cameraNode = SCNNode()
    cameraNode.camera = camera
    cameraNode.position = SCNVector3(0, 0, 0)
    scene.rootNode.addChildNode(cameraNode)

    for _ in 0..<220 {
        let star = makePinchZoomStar()
        star.position = SCNVector3(
            Float.random(in: -15...15),
            Float.random(in: -15...15),
            Float.random(in: -30...12)
        )
        scene.rootNode.addChildNode(star)
    }

    let controller = PinchZoomAnimationController(scene: scene)
    scene.rootNode.addChildNode(controller)

    return scene
}

private func makePinchZoomStar() -> SCNNode {
    let star = SCNSphere(radius: 0.05)
    let material = SCNMaterial()
    material.emission.contents = UIColor.white
    material.diffuse.contents = UIColor.white
    material.lightingModel = .constant
    material.isDoubleSided = true
    star.materials = [material]

    let node = SCNNode(geometry: star)
    node.name = "pinch_star"
    return node
}

final class PinchZoomAnimationController: SCNNode {
    private weak var targetScene: SCNScene?
    private var targetPinchAmount: CGFloat = 0
    private var smoothedPinchAmount: CGFloat = 0
    private var animationMode: SpaceAnimationMode = .inactive

    init(scene: SCNScene) {
        self.targetScene = scene
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setTargetPinchAmount(_ amount: CGFloat) {
        targetPinchAmount = min(1.0, max(0, amount))
    }

    func setAnimationMode(_ mode: SpaceAnimationMode) {
        animationMode = mode

        if mode == .overview {
            // Force quick settle to slow dots when the summary card is visible.
            smoothedPinchAmount = min(smoothedPinchAmount, 0.16)
            targetPinchAmount = min(targetPinchAmount, 0.16)
        } else if mode == .inactive {
            targetPinchAmount = 0
        }
    }

    func updateFrame() {
        guard let scene = targetScene else { return }

        let time = CACurrentMediaTime()
        let targetIntensity: CGFloat

        switch animationMode {
        case .inactive:
            targetIntensity = 0
        case .pinch:
            targetIntensity = targetPinchAmount
        case .summarizing:
            let pulse = 0.72 + sin(time * 1.6) * 0.08
            targetIntensity = CGFloat(max(0.55, min(0.9, pulse)))
        case .overview:
            targetIntensity = 0.12
        }

        let smoothing: CGFloat = animationMode == .overview ? 0.34 : 0.18
        smoothedPinchAmount += (targetIntensity - smoothedPinchAmount) * smoothing

        let intensity = max(0.0, min(1.0, Double(smoothedPinchAmount)))
        let speedRamp: Double
        let speed: Double
        let stretchFactor: Double

        switch animationMode {
        case .overview:
            speedRamp = 0
            speed = 0.12 // Slow ambient dots behind the overview card.
            stretchFactor = 1.25
        case .summarizing:
            speedRamp = pow(intensity, 1.8)
            speed = 0.18 + speedRamp * 2.9
            stretchFactor = 1.6 + speedRamp * 20.0
        case .pinch:
            speedRamp = pow(intensity, 2.25)
            speed = 0.04 + speedRamp * 3.4
            stretchFactor = 1.0 + speedRamp * 26.0
        case .inactive:
            speedRamp = 0
            speed = 0.05
            stretchFactor = 1.0
        }

        scene.rootNode.enumerateChildNodes { node, _ in
            guard node.name == "pinch_star" else { return }

            node.position.z += Float(speed)
            if node.position.z > 16 {
                node.position = SCNVector3(
                    Float.random(in: -15...15),
                    Float.random(in: -15...15),
                    Float.random(in: -30...(-18))
                )
            }

            let zScale = Float(stretchFactor)
            let xyScale = max(0.22, 1.0 / Float(pow(stretchFactor, 0.28)))
            node.scale = SCNVector3(xyScale, xyScale, zScale)

            let depthAlpha = max(0.0, min(1.0, Double((node.position.z + 30) / 34)))
            let speedFade = max(0.12, 1.0 - speedRamp * 0.6)
            let alpha = CGFloat(depthAlpha * speedFade)

            guard let material = node.geometry?.firstMaterial else { return }
            material.transparency = alpha

            let allowColorLines = animationMode == .summarizing
            if allowColorLines && speedRamp > 0.35 {
                let hue = CGFloat(fmod(time * 0.6 + Double(node.position.x) * 0.02, 1.0))
                let color = UIColor(hue: hue, saturation: 0.95, brightness: 1.0, alpha: alpha)
                material.emission.contents = color
                material.diffuse.contents = color
            } else {
                let tint = UIColor(white: 1.0, alpha: alpha)
                material.emission.contents = tint
                material.diffuse.contents = tint
            }
        }

    }
}

// MARK: - Pinch Gesture Overlay

struct PinchGestureOverlay: UIViewRepresentable {
    let onPinchChanged: (CGFloat) -> Void
    let onPinchEnded: () -> Void
    let onPanChanged: (CGSize) -> Void
    let onPanEnded: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPinchChanged: onPinchChanged, onPinchEnded: onPinchEnded,
                    onPanChanged: onPanChanged, onPanEnded: onPanEnded)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        pinch.delegate = context.coordinator
        view.addGestureRecognizer(pinch)

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPinchChanged = onPinchChanged
        context.coordinator.onPinchEnded = onPinchEnded
        context.coordinator.onPanChanged = onPanChanged
        context.coordinator.onPanEnded = onPanEnded
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPinchChanged: (CGFloat) -> Void
        var onPinchEnded: () -> Void
        var onPanChanged: (CGSize) -> Void
        var onPanEnded: () -> Void

        init(onPinchChanged: @escaping (CGFloat) -> Void, onPinchEnded: @escaping () -> Void,
             onPanChanged: @escaping (CGSize) -> Void, onPanEnded: @escaping () -> Void) {
            self.onPinchChanged = onPinchChanged
            self.onPinchEnded = onPinchEnded
            self.onPanChanged = onPanChanged
            self.onPanEnded = onPanEnded
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began, .changed:
                onPinchChanged(gesture.scale)
            case .ended, .cancelled, .failed:
                onPinchEnded()
            default:
                break
            }
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began, .changed:
                let translation = gesture.translation(in: gesture.view)
                onPanChanged(CGSize(width: translation.x, height: translation.y))
            case .ended, .cancelled, .failed:
                onPanEnded()
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

// MARK: - Bouncing Document View

struct BouncingDocumentView: View {
    @State private var isBouncing = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Document card
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                        .frame(width: 170, height: 220)

                    VStack(alignment: .leading, spacing: 8) {
                        // Title line
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.7, green: 0.78, blue: 1.0))
                            .frame(width: 100, height: 10)

                        // Content lines
                        ForEach(0..<9, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(white: 0.9))
                                .frame(width: CGFloat(120 - (i % 4) * 12), height: 9)
                        }

                        Spacer()
                    }
                    .padding(20)
                    .frame(width: 170, height: 220)
                }
                .offset(y: isBouncing ? -30 : 8)
                .rotationEffect(.degrees(isBouncing ? -3 : 3))
                .scaleEffect(isBouncing ? 1.05 : 0.95)
            }
            .offset(y: -60)

            // Label
            HStack(spacing: 8) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.0)
                Text("Summarizing...")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            withAnimation(
                .spring(response: 0.6, dampingFraction: 0.35)
                .repeatForever(autoreverses: true)
            ) {
                isBouncing = true
            }
        }
    }
}

// MARK: - Content View

struct ContentView: View {
    @State private var phase: AppPhase = .reading
    @State private var foldProgress: CGFloat = 0
    @State private var dragOffset: CGSize = .zero
    @State private var isReturningToReading = false
    @State private var pinchAmount: CGFloat = 0
    @State private var showPinchZoomEffect = false

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            PinchZoomBackgroundView(
                pinchAmount: pinchAmount,
                isActive: shouldShowPinchZoomBackground,
                mode: spaceAnimationMode
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            Color.white
                .ignoresSafeArea()
                .opacity(phase == .reading && foldProgress <= 0.001 && !showPinchZoomEffect ? 1 : 0)

            // Keep the fold view mounted so return is a true unfold, not a re-insert fade.
            readingPhaseView
                .opacity(phase == .loading || phase == .summary ? 0 : 1)
                .allowsHitTesting(phase == .reading || phase == .folding)
                .transaction { transaction in
                    // Never crossfade this layer; show/hide instantly by phase.
                    transaction.animation = nil
                }

            if phase == .loading {
                BouncingDocumentView()
                    .transition(.opacity)
                    .task {
                        do {
                            try await Task.sleep(for: .seconds(2.5))
                        } catch {
                            return
                        }
                        guard !Task.isCancelled else { return }
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            phase = .summary
                        }
                    }
            }

            if phase == .summary {
                summaryPhaseView
                    .transition(isReturningToReading ? .identity : .opacity)
            }
        }
        .animation(phase == .returning ? nil : .spring(response: 0.5, dampingFraction: 0.8), value: phase)
        .sensoryFeedback(.impact(weight: .medium), trigger: phase) { oldPhase, newPhase in
            newPhase == .loading || newPhase == .summary
        }
    }

    private var shouldShowPinchZoomBackground: Bool {
        showPinchZoomEffect
    }

    private var spaceAnimationMode: SpaceAnimationMode {
        guard showPinchZoomEffect else { return .inactive }

        switch phase {
        case .loading:
            return .summarizing
        case .summary:
            return .overview
        case .reading, .folding, .returning:
            return .pinch
        }
    }

    // MARK: - Reading Phase

    private var readingPhaseView: some View {
        AccordionFoldView(progress: foldProgress) {
            ReadingContentView()
        }
        .clipShape(RoundedRectangle(cornerRadius: foldProgress * 16))
        .scaleEffect(documentScaleForCurrentPhase)
        .shadow(color: .black.opacity(Double(foldProgress) * 0.18), radius: 14 * foldProgress, y: 8 * foldProgress)
        .offset(dragOffset)
        .overlay(
            PinchGestureOverlay(
                onPinchChanged: handlePinchChanged(_:),
                onPinchEnded: handlePinchEnded,
                onPanChanged: handlePanChanged(_:),
                onPanEnded: handlePanEnded
            )
        )
    }

    private var documentScaleForCurrentPhase: CGFloat {
        if phase == .returning {
            return 1.0
        }
        return 1 - foldProgress * 0.45
    }

    // MARK: - Summary Phase

    @State private var showBackButton = false

    private var summaryPhaseView: some View {
        ZStack {
            VStack(spacing: 16) {
                SummaryContentView()
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
    
                // Invisible placeholder so layout doesn't shift
                Button(action: resetToReading) {
                    Label("Back to details", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(.blue.gradient)
                        )
                }
                .disabled(isReturningToReading)
                .opacity(showBackButton ? 1 : 0)
                .scaleEffect(showBackButton ? 1 : 0.7)
            }
        }
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showBackButton)
        .task {
            do {
                try await Task.sleep(for: .seconds(0.5))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            showBackButton = true
        }
    }

    // MARK: - Pinch Gesture

    private func handlePinchChanged(_ scale: CGFloat) {
        guard !isReturningToReading, phase != .returning else {
            return
        }

        // Turn on the space background immediately on pinch begin/changed.
        showPinchZoomEffect = true

        let normalizedPinchAmount = min(1.0, max(0, (1.0 - scale) / 0.55))
        pinchAmount = normalizedPinchAmount

        if scale < 1.0 {
            // Map pinch-in (scale 1.0 → 0.45) to fold progress (0 → 1)
            let progress = normalizedPinchAmount
            foldProgress = progress
            if phase == .reading && progress > 0 {
                phase = .folding
            }
        }
    }

    private func handlePinchEnded() {
        guard !isReturningToReading, phase != .returning else {
            return
        }

        if foldProgress > 0.5 {
            // Go straight to loading — no delay
            foldProgress = 1.0
            showPinchZoomEffect = true
            pinchAmount = max(pinchAmount, 0.85)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                phase = .loading
                dragOffset = .zero
            }
        } else {
            // Cancel — spring back to flat
            withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
                foldProgress = 0
                phase = .reading
                dragOffset = .zero
                pinchAmount = 0
                showPinchZoomEffect = false
            }
        }
    }

    private func handlePanChanged(_ translation: CGSize) {
        if !isReturningToReading && (phase == .reading || phase == .folding) {
            dragOffset = translation
        }
    }

    private func handlePanEnded() {
        guard !isReturningToReading else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            dragOffset = .zero
        }
    }

    // MARK: - Reset

    private func resetToReading() {
        guard !isReturningToReading else { return }

        isReturningToReading = true
        showBackButton = false
        dragOffset = .zero
        var noAnimation = Transaction()
        noAnimation.animation = nil
        withTransaction(noAnimation) {
            phase = .returning
            foldProgress = 0.55
            pinchAmount = 0.75
            showPinchZoomEffect = true
        }

        Task { @MainActor in
            let duration: TimeInterval = 0.34
            let start = CACurrentMediaTime()
            let startFold = foldProgress
            let startPinch = pinchAmount

            while true {
                guard !Task.isCancelled else { return }

                let elapsed = CACurrentMediaTime() - start
                let t = min(1.0, elapsed / duration)
                let eased = 1.0 - pow(1.0 - t, 2.25)
                let remaining = CGFloat(1.0 - eased)
                let reverseFold = startFold * remaining
                let reversePinch = startPinch * remaining

                foldProgress = reverseFold
                pinchAmount = reversePinch

                if t >= 1.0 {
                    break
                }

                do {
                    try await Task.sleep(for: .milliseconds(16))
                } catch {
                    return
                }
            }

            foldProgress = 0
            pinchAmount = 0
            showPinchZoomEffect = false
            phase = .reading
            isReturningToReading = false
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
