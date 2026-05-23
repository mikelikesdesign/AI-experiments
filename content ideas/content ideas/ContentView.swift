//
//  ContentView.swift
//  content ideas
//
//  Created by Michael Lee on 4/21/26.
//

import SwiftUI

struct ContentView: View {
    private let focusPresentAnimation = Animation.spring(response: 0.46, dampingFraction: 0.86, blendDuration: 0.12)
    private let focusDismissAnimation = Animation.spring(response: 0.36, dampingFraction: 0.94, blendDuration: 0.08)
    private let focusDismissDuration: TimeInterval = 0.38

    @State private var editorText = """
    Prototyping is a great way to build something people can interact with so you can get feedback.

    A prototype shows people how the app works, details around the layout, the interaction design and details around the animations. It shows people how your ideas work from interacting with it which is easier to understand than just hearing about your ideas.

    Prototyping is also fun. Putting something interactive in front of people to let them play with it, to give feedback, and to see what they think makes building interesting. The feedback and insights will help improve the product.

    Ship better work by prototyping more of it. Every interaction you can feel before writing production code is a decision your team gets to make with feedback and suggestions of improvements.
    """
    @State private var rephraseState: RephraseSession?
    @State private var focusVisibility: CGFloat = 0
    @State private var pendingCommand: EditorTextCommand?

    private var focusPresented: Bool {
        rephraseState != nil
    }

    private var activeHighlightRange: NSRange? {
        guard let rephraseState else { return nil }

        let currentLength = (editorText as NSString).length
        let originalLength = (rephraseState.originalText as NSString).length
        let selectionRange = rephraseState.selection.range
        let replacementLength = currentLength - originalLength + selectionRange.length
        guard replacementLength > 0 else { return nil }
        guard selectionRange.location + replacementLength <= currentLength else { return nil }

        return NSRange(location: selectionRange.location, length: replacementLength)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.white
                        .ignoresSafeArea()

                    editingCanvas(in: geometry)
                }
                .toolbar(.hidden, for: .navigationBar)
                .onTapGesture {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil,
                        from: nil,
                        for: nil
                    )
                }
            }
        }
        .environment(\.colorScheme, .light)
    }

    private func editingCanvas(in geometry: GeometryProxy) -> some View {
        let zoom = editorZoom(in: geometry.size, safeAreaTop: geometry.safeAreaInsets.top)

        return ZStack {
            editorSurface(topSafeArea: geometry.safeAreaInsets.top)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea(.container, edges: .top)
                .allowsHitTesting(rephraseState == nil)
                .scaleEffect(zoom.scale, anchor: .topLeading)
                .offset(zoom.offset)

            bottomToolbar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 6)
                .opacity(1 - focusVisibility)
                .allowsHitTesting(rephraseState == nil)

            if let rephraseState {
                RephraseControls(
                    state: rephraseState,
                    visibility: focusVisibility,
                    onPreviewChanged: updateDraftPreview,
                    onSave: saveDraftPreview,
                    onClose: dismissIterations
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.identity)
                .allowsHitTesting(focusVisibility > 0.01)
            }
        }
    }

    private func editorZoom(in size: CGSize, safeAreaTop: CGFloat) -> (scale: CGFloat, offset: CGSize) {
        guard let rephraseState else {
            return (1, .zero)
        }

        let sourceBounds = rephraseState.selection.bounds
        guard sourceBounds.width > 0, sourceBounds.height > 0 else {
            return (1, .zero)
        }

        let finalScale: CGFloat = size.width > 700 ? 1.44 : 1.68
        let scale = 1 + ((finalScale - 1) * focusVisibility)
        let targetX: CGFloat = size.width > 700 ? 64 : 24
        let targetY = safeAreaTop + 54
        let finalOffsetX = targetX - (sourceBounds.minX * finalScale)
        let finalOffsetY = targetY - (sourceBounds.minY * finalScale)

        return (
            scale,
            CGSize(
                width: finalOffsetX * focusVisibility,
                height: finalOffsetY * focusVisibility
            )
        )
    }

    private var bottomToolbar: some View {
        HStack(spacing: 8) {
            toolbarButton(systemName: "textformat")
            toolbarButton(systemName: "photo")
            toolbarButton(systemName: "paintpalette")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 100, style: .continuous)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.13))
        )
        .shadow(color: Color.black.opacity(0.18), radius: 14, y: 6)
    }

    private func toolbarButton(systemName: String) -> some View {
        Button(action: {}) {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func editorSurface(topSafeArea: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            EditorTextView(
                text: $editorText,
                command: $pendingCommand,
                topContentInset: topSafeArea,
                highlightedRange: activeHighlightRange,
                onSelectionChanged: { _ in },
                onCommandHandled: { commandID, _ in
                    guard pendingCommand?.id == commandID else { return }
                    pendingCommand = nil
                },
                onViewIterations: { selection in
                    presentIterations(for: selection)
                }
            )

            if editorText.isEmpty {
                Text("Start writing")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 22)
                    .padding(.top, topSafeArea + 20)
                    .allowsHitTesting(false)
            }
        }
        .background(Color.white)
    }

    private func presentIterations(for selection: EditorSelectionContext) {
        rephraseState = RephraseSession(selection: selection, originalText: editorText)
        focusVisibility = 0

        withAnimation(focusPresentAnimation) {
            focusVisibility = 1
        }
    }

    private func dismissIterations() {
        let stateID = rephraseState?.id

        withAnimation(focusDismissAnimation) {
            focusVisibility = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + focusDismissDuration) {
            guard focusVisibility <= 0.001 else { return }
            guard rephraseState?.id == stateID else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                if let rephraseState {
                    editorText = rephraseState.originalText
                }
                rephraseState = nil
            }
        }
    }

    private func updateDraftPreview(_ previewText: String) {
        guard let rephraseState else { return }
        guard let updatedText = IterationPrototypeEngine.replacingText(
            in: rephraseState.originalText,
            range: rephraseState.selection.range,
            with: previewText
        ) else {
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            editorText = updatedText
        }
    }

    private func saveDraftPreview() {
        guard let rephraseState else { return }
        let stateID = rephraseState.id

        withAnimation(focusDismissAnimation) {
            focusVisibility = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + focusDismissDuration) {
            guard self.rephraseState?.id == stateID else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                self.rephraseState = nil
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
