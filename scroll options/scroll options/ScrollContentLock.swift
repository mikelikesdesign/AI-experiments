import SwiftUI
import UIKit

struct ScrollPanEvent {
    enum Phase { case began, changed, ended, cancelled }
    let phase: Phase
    let translation: CGSize
    /// Scrollable distance left below the viewport at the time of the event.
    let remainingDistance: CGFloat
}

/// Holds the response still without disabling its pan recognizer. The same
/// uninterrupted finger gesture can therefore continue through all the options.
@MainActor
final class ScrollContentLock: NSObject {
    var onPanChange: ((ScrollPanEvent) -> Void)?
    private weak var scrollView: UIScrollView?
    private var observation: NSKeyValueObservation?
    private var lockedOffset: CGPoint?
    private var lockedBase: CGPoint?
    private var isRestoringOffset = false

    func attach(to scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }
        detach()
        self.scrollView = scrollView
        scrollView.panGestureRecognizer.addTarget(self, action: #selector(panChanged(_:)))
        observation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
            // UIKit scroll offsets are updated on the main thread.
            MainActor.assumeIsolated {
                self?.restoreOffset(in: scrollView)
            }
        }
    }

    func lock() {
        guard lockedOffset == nil, let scrollView else { return }
        // Hold the response exactly at its end. Locking mid rubber-band would
        // otherwise freeze the overshoot for the rest of the selection.
        var offset = scrollView.contentOffset
        offset.y = min(offset.y, Self.maximumOffsetY(in: scrollView))
        lockedBase = offset
        lockedOffset = offset
        if scrollView.contentOffset != offset {
            scrollView.setContentOffset(offset, animated: false)
        }
    }

    /// Lets the held response give a little under the pull, so the stop feels
    /// like tension rather than a wall. `give` is in points, downward positive.
    func setPullGive(_ give: CGFloat) {
        guard let base = lockedBase, let scrollView else { return }
        var offset = base
        offset.y = min(base.y + max(give, 0), Self.maximumOffsetY(in: scrollView))
        guard lockedOffset != offset else { return }
        lockedOffset = offset
        scrollView.setContentOffset(offset, animated: false)
    }

    func unlock() {
        guard let offset = lockedOffset else { return }
        lockedOffset = nil
        lockedBase = nil
        // End any residual momentum before returning control to normal scrolling.
        scrollView?.setContentOffset(offset, animated: false)
    }

    func detach() {
        unlock()
        scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(panChanged(_:)))
        observation?.invalidate()
        observation = nil
        scrollView = nil
    }

    @objc private func panChanged(_ recognizer: UIPanGestureRecognizer) {
        let phase: ScrollPanEvent.Phase
        switch recognizer.state {
        case .began: phase = .began
        case .changed: phase = .changed
        case .ended: phase = .ended
        case .cancelled, .failed: phase = .cancelled
        default: return
        }
        // Window-space translation is independent of the content offset we hold.
        let translation = recognizer.translation(in: scrollView?.window)
        // The scroll view's own target runs first, so this reflects the offset
        // produced by the same touch rather than the previous one.
        let remainingDistance = scrollView.map(Self.remainingDistance(in:)) ?? .infinity
        onPanChange?(ScrollPanEvent(
            phase: phase,
            translation: CGSize(width: translation.x, height: translation.y),
            remainingDistance: remainingDistance
        ))
    }

    private static func maximumOffsetY(in scrollView: UIScrollView) -> CGFloat {
        let inset = scrollView.adjustedContentInset
        return max(
            scrollView.contentSize.height + inset.bottom - scrollView.bounds.height,
            -inset.top
        )
    }

    private static func remainingDistance(in scrollView: UIScrollView) -> CGFloat {
        max(maximumOffsetY(in: scrollView) - scrollView.contentOffset.y, 0)
    }

    private func restoreOffset(in scrollView: UIScrollView) {
        guard !isRestoringOffset, let offset = lockedOffset,
              scrollView.contentOffset != offset else { return }
        isRestoringOffset = true
        scrollView.setContentOffset(offset, animated: false)
        isRestoringOffset = false
    }
}

/// Placed inside the scroll content, so only this response's scroll view is found.
struct ScrollContentLockReader: UIViewRepresentable {
    let controller: ScrollContentLock
    let onPanChange: (ScrollPanEvent) -> Void

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.controller = controller
        controller.onPanChange = onPanChange
        return view
    }

    func updateUIView(_ uiView: Probe, context: Context) {
        controller.onPanChange = onPanChange
        uiView.resolveScrollView()
    }

    static func dismantleUIView(_ uiView: Probe, coordinator: ()) {
        uiView.controller?.onPanChange = nil
        uiView.controller?.detach()
    }

    final class Probe: UIView {
        weak var controller: ScrollContentLock?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resolveScrollView()
        }

        override func didMoveToSuperview() {
            super.didMoveToSuperview()
            resolveScrollView()
        }

        func resolveScrollView() {
            var ancestor = superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    controller?.attach(to: scrollView)
                    return
                }
                ancestor = view.superview
            }
        }
    }
}
