import CoreText
import UIKit

/// The variable typeface used throughout the app (Allo, from the `allo-font` npm package),
/// loaded straight from its woff2. Fonts are cached per size/weight because the
/// layout re-flows every frame while debug mode opens and closes.
final class Typeface {
    static let shared = Typeface()

    private let base: CTFontDescriptor
    private var cache: [String: CTFont] = [:]

    private init() {
        guard
            let url = Bundle.main.url(forResource: "AlloVariable", withExtension: "woff2"),
            let data = try? Data(contentsOf: url),
            let descs = CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor],
            let first = descs.first
        else { fatalError("AlloVariable.woff2 missing from bundle") }
        base = first
    }

    private static func tag(_ s: String) -> NSNumber {
        NSNumber(value: s.utf8.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) })
    }

    private func descriptor(wght: Double, rond: Double, opsz: Double) -> CTFontDescriptor {
        let variations: [NSNumber: NSNumber] = [
            Self.tag("wght"): NSNumber(value: wght),
            Self.tag("ROND"): NSNumber(value: rond),
            Self.tag("opsz"): NSNumber(value: opsz),
        ]
        return CTFontDescriptorCreateCopyWithAttributes(
            base, [kCTFontVariationAttribute: variations] as CFDictionary)
    }

    /// Body font for running text. Size is quantised so the cache stays small during animation.
    func font(size: CGFloat, weight: Double = 420) -> CTFont {
        let s = (size * 20).rounded() / 20
        let key = "\(s)|\(weight)"
        if let f = cache[key] { return f }
        if cache.count > 300 { cache.removeAll(keepingCapacity: true) }
        let f = CTFontCreateWithFontDescriptor(
            descriptor(wght: weight, rond: 40, opsz: Double(min(32, max(8, s)))), s, nil)
        cache[key] = f
        return f
    }

    /// UI font for labels: tabular figures, like the original scanner's tags.
    func uiFont(size: CGFloat, weight: Double = 500) -> UIFont {
        let key = "\(size)|\(weight)"
        if let f = uiCache[key] { return f }
        let f = makeUIFont(size: size, weight: weight)
        uiCache[key] = f
        return f
    }

    private var uiCache: [String: UIFont] = [:]

    private func makeUIFont(size: CGFloat, weight: Double) -> UIFont {
        let d = descriptor(wght: weight, rond: 50, opsz: Double(size)) as UIFontDescriptor
        let tabular = d.addingAttributes([
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
            ]],
        ])
        return UIFont(descriptor: tabular, size: size)
    }
}
