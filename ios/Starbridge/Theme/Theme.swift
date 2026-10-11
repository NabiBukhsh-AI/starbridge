import SwiftUI
import UIKit

/** A colour from DESIGN.md: 0xRRGGBB and its alpha. */
struct Hex: Sendable {
    let rgb: UInt32
    let alpha: CGFloat

    init(_ rgb: UInt32, _ alpha: CGFloat) {
        self.rgb = rgb
        self.alpha = alpha
    }

    var uiColor: UIColor {
        UIColor(
            red: CGFloat(rgb >> 16 & 0xFF) / 255,
            green: CGFloat(rgb >> 8 & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/** A token's light and dark values; as a `Color`, it follows the scheme. */
struct Pair: Sendable {
    let light: Hex
    let dark: Hex

    var color: Color {
        let light = light.uiColor
        let dark = dark.uiColor
        return Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}

/** A typography role from DESIGN.md, set in SF Pro (SF Mono for `mono`). */
struct TypeRole: Sendable {
    let size: CGFloat
    let weight: Int
    let lineHeight: CGFloat
    let letterSpacing: CGFloat
    let mono: Bool
    let tabular: Bool

    var fontWeight: Font.Weight {
        switch weight {
        case ..<350: .light
        case ..<450: .regular
        case ..<550: .medium
        case ..<650: .semibold
        default: .bold
        }
    }
}

/** Sets a role's size, scaled with Dynamic Type, its line height and its tracking. */
private struct TypeStyle: ViewModifier {
    let role: TypeRole
    @ScaledMetric private var size: CGFloat
    @ScaledMetric private var lineHeight: CGFloat

    init(role: TypeRole) {
        self.role = role
        _size = ScaledMetric(wrappedValue: role.size, relativeTo: .body)
        _lineHeight = ScaledMetric(wrappedValue: role.lineHeight, relativeTo: .body)
    }

    func body(content: Content) -> some View {
        var font = Font.system(size: size, weight: role.fontWeight, design: role.mono ? .monospaced : .default)
        if role.tabular { font = font.monospacedDigit() }
        // SwiftUI sets line spacing between lines, on top of the font's own height.
        let natural = UIFont.systemFont(ofSize: size).lineHeight
        return content
            .font(font)
            .tracking(role.letterSpacing * size)
            .lineSpacing(max(0, lineHeight - natural))
    }
}

extension View {
    func type(_ role: TypeRole) -> some View { modifier(TypeStyle(role: role)) }
}
