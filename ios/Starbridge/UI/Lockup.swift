import SwiftUI

/**
 * The mark drawn in the theme's colours: DESIGN.md's shapes, cropped to the visible 72 of the
 * 108-unit canvas (18 to 90), as Android's and the web's `Mark`. The climber is the only amber.
 */
struct Mark: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, canvas in
            let k = canvas.width / 72
            func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
                CGRect(x: (x - 18) * k, y: (y - 18) * k, width: w * k, height: h * k)
            }
            let fg = Tokens.Colors.fg.color
            context.fill(Path(ellipseIn: rect(54 - 80, 148 - 80, 160, 160)), with: .color(fg))
            context.fill(Path(rect(51.75, 18, 4.5, 52)), with: .color(fg))
            context.fill(Path(roundedRect: rect(48.5, 34, 11, 20), cornerRadius: 5.5 * k), with: .color(Tokens.Colors.accent.color))
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityHidden(true)
    }
}

/** The mark and the name as one sign, with the web's gap of 0.4 of the mark between them. */
struct Lockup: View {
    var mark: CGFloat = 56

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: (mark * 0.4).rounded()) {
            Mark(size: mark).alignmentGuide(.lastTextBaseline) { $0[.bottom] }
            Text("Starbridge").type(Tokens.Typography.title).lineLimit(1).minimumScaleFactor(0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Starbridge")
    }
}
