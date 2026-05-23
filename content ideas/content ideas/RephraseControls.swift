//
//  RephraseControls.swift
//  content ideas
//
//  Created by Codex on 4/27/26.
//

import SwiftUI

struct RephraseControls: View {
    let state: RephraseSession
    let visibility: CGFloat
    let onPreviewChanged: (String) -> Void
    let onSave: () -> Void
    let onClose: () -> Void

    @State private var mixPoint: CGPoint

    init(
        state: RephraseSession,
        visibility: CGFloat,
        onPreviewChanged: @escaping (String) -> Void,
        onSave: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.state = state
        self.visibility = visibility
        self.onPreviewChanged = onPreviewChanged
        self.onSave = onSave
        self.onClose = onClose
        _mixPoint = State(initialValue: ToneMixerPrototypeEngine.sourcePoint(for: state.selection.text))
    }

    private var preview: TonePreviewResult {
        ToneMixerPrototypeEngine.preview(
            for: state.selection.text,
            x: mixPoint.x,
            y: mixPoint.y
        )
    }

    var body: some View {
        GeometryReader { geometry in
            let controlWidth = min(max(geometry.size.width - 32, 0), 520)
            let padSize = min(controlWidth, min(340, max(230, geometry.size.height * 0.38)))

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    QuadrantTonePad(point: $mixPoint)
                        .frame(width: padSize, height: padSize)
                        .frame(maxWidth: .infinity)

                    HStack(spacing: 12) {
                        actionButton(title: "Cancel", isProminent: false, action: onClose)
                        actionButton(title: "Save", isProminent: true) {
                            onSave()
                        }
                    }
                    .frame(maxWidth: controlWidth)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, max(6, geometry.safeAreaInsets.bottom * 0.2))
                .frame(maxWidth: .infinity)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 30,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 30,
                        style: .continuous
                    )
                    .fill(Color(red: 0.82, green: 0.82, blue: 0.84))
                    .shadow(color: Color.black.opacity(0.10), radius: 26, y: -8)
                    .opacity(visibility)
                    .ignoresSafeArea(.container, edges: .bottom)
                )
                .offset(y: ((1 - visibility) * (padSize + 110)) + (geometry.safeAreaInsets.bottom * 0.45))
                .opacity(visibility)
            }
            .accessibilityIdentifier("rephrase-controls")
            .onChange(of: preview.text) { _, newValue in
                onPreviewChanged(newValue)
            }
        }
    }

    @ViewBuilder
    private func actionButton(title: String, isProminent: Bool, action: @escaping () -> Void) -> some View {
        if isProminent {
            Button(action: action) {
                actionButtonLabel(title)
                    .foregroundStyle(.white)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.09, green: 0.09, blue: 0.10))
                    )
            }
            .buttonStyle(.plain)
        } else {
            Button(action: action) {
                actionButtonLabel(title)
                    .foregroundStyle(.black)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(red: 0.96, green: 0.96, blue: 0.97))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func actionButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
    }
}

private struct QuadrantTonePad: View {
    @Binding var point: CGPoint
    @GestureState private var isDragging = false
    @State private var gridPhase: Double = 0

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let puckHorizontalInset: CGFloat = 28
            let puckTopInset: CGFloat = 28
            let puckBottomInset: CGFloat = 48
            let usableWidth = max(size - (puckHorizontalInset * 2), 1)
            let usableHeight = max(size - puckTopInset - puckBottomInset, 1)
            let clampedX = clamped(point.x, lower: 0, upper: 1)
            let clampedY = clamped(point.y, lower: 0, upper: 1)
            let puckX = puckHorizontalInset + (clampedX * usableWidth)
            let puckY = puckTopInset + (clampedY * usableHeight)
            let gridInset: CGFloat = 24
            let gridRect = CGRect(
                x: gridInset,
                y: gridInset,
                width: size - (gridInset * 2),
                height: size - (gridInset * 2)
            )
            let maxTilt: Double = 10
            let tiltAroundX = (0.5 - Double(clampedY)) * 2 * maxTilt
            let tiltAroundY = (Double(clampedX) - 0.5) * 2 * maxTilt

            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Color(red: 0.11, green: 0.11, blue: 0.13))

                Path { path in
                    path.addRoundedRect(
                        in: gridRect,
                        cornerSize: CGSize(width: 20, height: 20)
                    )
                }
                .stroke(gridLineColor(base: 0.24, swing: 0.08, phase: gridPhase), lineWidth: 1.2)

                Path { path in
                    let innerSize = gridRect.width
                    let step = innerSize / 8

                    for index in 1..<8 where index % 2 != 0 {
                        let offset = gridInset + (CGFloat(index) * step)
                        path.move(to: CGPoint(x: offset, y: gridInset))
                        path.addLine(to: CGPoint(x: offset, y: size - gridInset))
                        path.move(to: CGPoint(x: gridInset, y: offset))
                        path.addLine(to: CGPoint(x: size - gridInset, y: offset))
                    }
                }
                .stroke(gridLineColor(base: 0.12, swing: 0.10, phase: gridPhase), lineWidth: 0.8)

                Path { path in
                    let innerSize = gridRect.width
                    let step = innerSize / 8

                    for index in stride(from: 2, through: 6, by: 2) {
                        let offset = gridInset + (CGFloat(index) * step)
                        path.move(to: CGPoint(x: offset, y: gridInset))
                        path.addLine(to: CGPoint(x: offset, y: size - gridInset))
                        path.move(to: CGPoint(x: gridInset, y: offset))
                        path.addLine(to: CGPoint(x: size - gridInset, y: offset))
                    }
                }
                .stroke(gridLineColor(base: 0.18, swing: 0.10, phase: 1 - gridPhase), lineWidth: 1)

                QuadrantCornerLabel(title: "Simple")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(18)

                QuadrantCornerLabel(title: "Casual")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding(18)

                QuadrantCornerLabel(title: "Formal")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(18)

                QuadrantCornerLabel(title: "Advanced")
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(18)

                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .scaleEffect(isDragging ? 1.16 : 1)
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: 4)
                    .animation(.spring(response: 0.22, dampingFraction: 0.78), value: isDragging)
                    .position(x: puckX, y: puckY)
            }
            .rotation3DEffect(.degrees(tiltAroundX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(tiltAroundY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: clampedX)
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: clampedY)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        let localX = clamped((value.location.x - puckHorizontalInset) / usableWidth, lower: 0, upper: 1)
                        let localY = clamped((value.location.y - puckTopInset) / usableHeight, lower: 0, upper: 1)
                        point = CGPoint(x: localX, y: localY)
                    }
            )
        }
        .accessibilityIdentifier("quadrant-tone-pad")
        .onAppear {
            guard gridPhase == 0 else { return }
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                gridPhase = 1
            }
        }
    }

    private func gridLineColor(base: Double, swing: Double, phase: Double) -> Color {
        let opacity = base + (swing * phase)
        let tint = 1.0 - (0.18 * phase)
        return Color(red: tint, green: tint, blue: tint).opacity(opacity)
    }
}

private struct QuadrantCornerLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.black.opacity(0.8))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.78))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 1)
            )
    }
}

private func clamped(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
    min(max(value, lower), upper)
}
