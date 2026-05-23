//
//  EditorTextView.swift
//  content ideas
//
//  Created by Michael Lee on 4/21/26.
//

import SwiftUI
import UIKit

struct EditorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var command: EditorTextCommand?
    var topContentInset: CGFloat = 0
    var bottomContentInset: CGFloat = 0
    var highlightedRange: NSRange?
    var onSelectionChanged: (EditorSelectionContext?) -> Void
    var onCommandHandled: (UUID, Bool) -> Void
    var onViewIterations: (EditorSelectionContext) -> Void

    func makeCoordinator() -> EditorCoordinator {
        EditorCoordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.text = text
        textView.font = .systemFont(ofSize: 20)
        textView.textColor = .label
        textView.backgroundColor = .clear
        textView.tintColor = UIColor(red: 0.34, green: 0.35, blue: 0.42, alpha: 1)
        textView.contentInsetAdjustmentBehavior = .never
        textView.textContainerInset = UIEdgeInsets(top: 20 + topContentInset, left: 18, bottom: 24 + bottomContentInset, right: 18)
        textView.textContainer.lineFragmentPadding = 0
        textView.keyboardDismissMode = .interactive
        textView.alwaysBounceVertical = true
        textView.accessibilityIdentifier = "editor-text-view"

        if #available(iOS 18.0, *) {
            textView.writingToolsBehavior = .none
        }

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self

        if !context.coordinator.isPerformingProgrammaticUpdate {
            context.coordinator.applyDisplayText(text, highlightedRange: highlightedRange, to: uiView)
        }

        let desiredInsets = UIEdgeInsets(top: 20 + topContentInset, left: 18, bottom: 24 + bottomContentInset, right: 18)
        if uiView.textContainerInset != desiredInsets {
            uiView.textContainerInset = desiredInsets
        }

        if let command {
            context.coordinator.applyIfNeeded(command, to: uiView)
        }
    }
}

final class EditorCoordinator: NSObject, UITextViewDelegate {
    var parent: EditorTextView
    var isPerformingProgrammaticUpdate = false

    private var lastAppliedCommandID: UUID?
    private var lastDisplayedText: String?
    private var lastDisplayedHighlightRange: NSRange?

    init(parent: EditorTextView) {
        self.parent = parent
    }

    func textViewDidChange(_ textView: UITextView) {
        guard !isPerformingProgrammaticUpdate else { return }
        parent.text = textView.text
        publishSelection(from: textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isPerformingProgrammaticUpdate else { return }
        publishSelection(from: textView)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        parent.onSelectionChanged(nil)
    }

    func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard let selection = selectionContext(in: textView, range: range) else {
            return nil
        }

        let copyAction = UIAction(
            title: "Copy",
            image: UIImage(systemName: "doc.on.doc")
        ) { _ in
            UIPasteboard.general.string = selection.text
        }

        let viewIterationsAction = UIAction(
            title: "Rephrase",
            image: UIImage(systemName: "wand.and.stars")
        ) { [weak self, weak textView] _ in
            guard let self, let textView else { return }
            textView.resignFirstResponder()
            parent.onSelectionChanged(nil)
            parent.onViewIterations(selection)
        }

        return UIMenu(children: [copyAction, viewIterationsAction])
    }

    func applyIfNeeded(_ command: EditorTextCommand, to textView: UITextView) {
        guard lastAppliedCommandID != command.id else { return }
        lastAppliedCommandID = command.id

        let success = apply(command, to: textView)
        DispatchQueue.main.async {
            self.parent.onCommandHandled(command.id, success)
        }
    }

    func applyDisplayText(_ text: String, highlightedRange: NSRange?, to textView: UITextView) {
        guard lastDisplayedText != text || lastDisplayedHighlightRange != highlightedRange || textView.text != text else {
            return
        }

        lastDisplayedText = text
        lastDisplayedHighlightRange = highlightedRange

        let selectedRange = textView.selectedRange
        let contentOffset = textView.contentOffset
        let attributedText = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 20),
                .foregroundColor: UIColor.label
            ]
        )

        if let highlightedRange,
           highlightedRange.location != NSNotFound,
           highlightedRange.location >= 0,
           NSMaxRange(highlightedRange) <= attributedText.length {
            attributedText.addAttributes(
                [
                    .backgroundColor: UIColor(red: 1.0, green: 0.86, blue: 0.18, alpha: 0.62),
                    .foregroundColor: UIColor.black
                ],
                range: highlightedRange
            )
        }

        isPerformingProgrammaticUpdate = true
        textView.attributedText = attributedText
        textView.font = .systemFont(ofSize: 20)
        textView.textColor = .label
        textView.selectedRange = bounded(selectedRange, in: text)
        textView.setContentOffset(contentOffset, animated: false)
        isPerformingProgrammaticUpdate = false
    }

    private func apply(_ command: EditorTextCommand, to textView: UITextView) -> Bool {
        guard let updatedText = IterationPrototypeEngine.replacingText(
            in: textView.text ?? "",
            range: command.replacementRange,
            with: command.replacementText
        ) else {
            return false
        }

        isPerformingProgrammaticUpdate = true
        textView.text = updatedText
        parent.text = updatedText
        lastDisplayedText = nil

        let insertedLength = (command.replacementText as NSString).length
        let cursorLocation = min(command.replacementRange.location + insertedLength, (updatedText as NSString).length)
        textView.selectedRange = NSRange(location: cursorLocation, length: 0)
        textView.becomeFirstResponder()
        textView.scrollRangeToVisible(textView.selectedRange)
        isPerformingProgrammaticUpdate = false

        publishSelection(from: textView)
        return true
    }

    private func bounded(_ range: NSRange, in text: String) -> NSRange {
        let length = (text as NSString).length
        guard range.location != NSNotFound else {
            return NSRange(location: length, length: 0)
        }

        let location = min(max(range.location, 0), length)
        let remainingLength = max(length - location, 0)
        let selectedLength = min(max(range.length, 0), remainingLength)
        return NSRange(location: location, length: selectedLength)
    }

    private func publishSelection(from textView: UITextView) {
        guard let selection = selectionContext(in: textView, range: textView.selectedRange) else {
            parent.onSelectionChanged(nil)
            return
        }

        parent.onSelectionChanged(selection)
    }

    private func selectionContext(in textView: UITextView, range: NSRange) -> EditorSelectionContext? {
        guard range.location != NSNotFound, range.length > 0 else { return nil }
        guard let swiftRange = Range(range, in: textView.text) else { return nil }

        let selectedText = String(textView.text[swiftRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selectedText.isEmpty else { return nil }

        return EditorSelectionContext(
            range: range,
            text: selectedText,
            bounds: selectionBounds(in: textView, range: range)
        )
    }

    private func selectionBounds(in textView: UITextView, range: NSRange) -> CGRect {
        guard let start = textView.position(from: textView.beginningOfDocument, offset: range.location),
              let end = textView.position(from: start, offset: range.length),
              let textRange = textView.textRange(from: start, to: end)
        else {
            return .zero
        }

        let rects = textView.selectionRects(for: textRange)
            .map(\.rect)
            .filter { !$0.isNull && !$0.isEmpty }

        let localBounds = rects.reduce(CGRect.null) { partialResult, rect in
            partialResult.union(rect)
        }

        guard !localBounds.isNull && !localBounds.isEmpty else {
            return textView.convert(textView.firstRect(for: textRange), to: nil)
        }

        return textView.convert(localBounds, to: nil)
    }
}
