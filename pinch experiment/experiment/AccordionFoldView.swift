import SwiftUI
import UIKit

struct AccordionFoldView<Content: View>: UIViewRepresentable {
    let progress: CGFloat
    @ViewBuilder var content: () -> Content

    init(progress: CGFloat, @ViewBuilder content: @escaping () -> Content) {
        self.progress = progress
        self.content = content
    }

    func makeUIView(context: Context) -> HalfFoldContainerView {
        let view = HalfFoldContainerView()
        view.setContent(AnyView(content()))
        return view
    }

    func updateUIView(_ uiView: HalfFoldContainerView, context: Context) {
        uiView.setContent(AnyView(content()))
        uiView.update(progress: progress)
    }
}

final class HalfFoldContainerView: UIView {
    private var topHostingController: UIHostingController<AnyView>?
    private var bottomHostingController: UIHostingController<AnyView>?
    private let topContainer = UIView()
    private let bottomContainer = UIView()
    private let topShadow = CAGradientLayer()
    private let bottomShadow = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.sublayerTransform.m34 = -1.0 / 800.0
        configureContainers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        layer.sublayerTransform.m34 = -1.0 / 800.0
        configureContainers()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let halfHeight = bounds.height / 2
        topContainer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: halfHeight)
        bottomContainer.frame = CGRect(x: 0, y: halfHeight, width: bounds.width, height: halfHeight)

        topHostingController?.view.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        bottomHostingController?.view.frame = CGRect(x: 0, y: -halfHeight, width: bounds.width, height: bounds.height)

        topShadow.frame = topContainer.bounds
        bottomShadow.frame = bottomContainer.bounds
    }

    func setContent(_ content: AnyView) {
        if let topHostingController {
            topHostingController.rootView = content
        } else {
            let topHostingController = UIHostingController(rootView: content)
            topHostingController.view.backgroundColor = .clear
            topContainer.addSubview(topHostingController.view)
            self.topHostingController = topHostingController
        }

        if let bottomHostingController {
            bottomHostingController.rootView = content
        } else {
            let bottomHostingController = UIHostingController(rootView: content)
            bottomHostingController.view.backgroundColor = .clear
            bottomContainer.addSubview(bottomHostingController.view)
            self.bottomHostingController = bottomHostingController
        }
    }

    func update(progress: CGFloat) {
        applyTransforms(progress: progress)
    }

    private func applyTransforms(progress: CGFloat) {
        let t = max(0, min(1, progress))
        let eased = t * t * (3 - 2 * t)
        let maxAngle: CGFloat = 86
        let angle = eased * maxAngle * .pi / 180

        if t == 0 {
            // Flat: show top container full-size, hide bottom to avoid seam
            topContainer.clipsToBounds = false
            topContainer.frame = bounds
            topContainer.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            topContainer.layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
            topContainer.layer.transform = CATransform3DIdentity
            topHostingController?.view.frame = bounds
            bottomContainer.isHidden = true
            topShadow.opacity = 0
            bottomShadow.opacity = 0
            return
        }

        bottomContainer.isHidden = false
        topContainer.clipsToBounds = true

        let halfHeight = bounds.height / 2
        topContainer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: halfHeight)
        bottomContainer.frame = CGRect(x: 0, y: halfHeight, width: bounds.width, height: halfHeight)
        topHostingController?.view.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        bottomHostingController?.view.frame = CGRect(x: 0, y: -halfHeight, width: bounds.width, height: bounds.height)

        topContainer.layer.anchorPoint = CGPoint(x: 0.5, y: 1.0)
        bottomContainer.layer.anchorPoint = CGPoint(x: 0.5, y: 0.0)

        let topPosition = CGPoint(x: bounds.midX, y: bounds.height / 2)
        let bottomPosition = CGPoint(x: bounds.midX, y: bounds.height / 2)
        topContainer.layer.position = topPosition
        bottomContainer.layer.position = bottomPosition

        topContainer.layer.transform = CATransform3DMakeRotation(angle, 1, 0, 0)
        bottomContainer.layer.transform = CATransform3DMakeRotation(-angle, 1, 0, 0)

        topShadow.opacity = Float(eased) * 0.6
        bottomShadow.opacity = Float(eased) * 0.6
    }

    private func configureContainers() {
        topContainer.backgroundColor = .clear
        bottomContainer.backgroundColor = .clear
        topContainer.clipsToBounds = true
        bottomContainer.clipsToBounds = true

        addSubview(topContainer)
        addSubview(bottomContainer)

        topShadow.colors = [
            UIColor.black.withAlphaComponent(0.25).cgColor,
            UIColor.black.withAlphaComponent(0.0).cgColor
        ]
        topShadow.startPoint = CGPoint(x: 0.5, y: 1.0)
        topShadow.endPoint = CGPoint(x: 0.5, y: 0.0)
        topShadow.opacity = 0.0
        topContainer.layer.addSublayer(topShadow)

        bottomShadow.colors = [
            UIColor.black.withAlphaComponent(0.25).cgColor,
            UIColor.black.withAlphaComponent(0.0).cgColor
        ]
        bottomShadow.startPoint = CGPoint(x: 0.5, y: 0.0)
        bottomShadow.endPoint = CGPoint(x: 0.5, y: 1.0)
        bottomShadow.opacity = 0.0
        bottomContainer.layer.addSublayer(bottomShadow)
    }
}
