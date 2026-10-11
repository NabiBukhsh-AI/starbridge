// packages/protocol/src/permission.ts: what a device needs to show a permission prompt.

/**
 * `text` with each control or format character but newline and tab shown as its escape
 * (`\u202E`), so a permission reads in the order it runs: a bidi override cannot reorder what the
 * owner allows (#357).
 */
public func visible(_ text: String) -> String {
    var out = String.UnicodeScalarView()
    for u in text.unicodeScalars {
        let category = u.properties.generalCategory
        let hidden = (category == .control || category == .format || u == "\u{2028}" || u == "\u{2029}") && u != "\n" && u != "\t"
        guard hidden else {
            out.append(u)
            continue
        }
        let hex = String(u.value, radix: 16, uppercase: true)
        let escape = hex.count > 4 ? "\\u{\(hex)}" : "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
        out.append(contentsOf: escape.unicodeScalars)
    }
    return String(out)
}
