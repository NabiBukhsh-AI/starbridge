// JSON as JavaScript's JSON.parse and JSON.stringify read and write it. Signed bodies travel as
// the exact text their signer wrote, so a body this package signs must be the bytes
// packages/protocol would write for the same object: keys keep their order, numbers print as
// JavaScript prints them, and strings escape only what JSON.stringify escapes.

/** A JSON value. Numbers are doubles, as in JavaScript. */
public enum JSON: Equatable, Sendable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSON])
    case object(JSONObject)

    /** Parses `text` as JSON.parse does; throws `bad-schema` when it is not JSON. */
    public static func parse(_ text: String) throws -> JSON {
        var p = JSONParser(Array(text.utf8))
        return try p.document()
    }

    /** The text JSON.stringify writes for this value. */
    public var text: String {
        var out = ""
        write(to: &out)
        return out
    }

    func write(to out: inout String) {
        switch self {
        case .null: out += "null"
        case .bool(let b): out += b ? "true" : "false"
        case .number(let n): out += jsNumber(n)
        case .string(let s): writeString(s, to: &out)
        case .array(let items):
            out += "["
            for (i, item) in items.enumerated() {
                if i > 0 { out += "," }
                item.write(to: &out)
            }
            out += "]"
        case .object(let o):
            out += "{"
            for (i, (k, v)) in o.enumerated() {
                if i > 0 { out += "," }
                writeString(k, to: &out)
                out += ":"
                v.write(to: &out)
            }
            out += "}"
        }
    }

    public var string: String? { if case .string(let s) = self { s } else { nil } }
    public var number: Double? { if case .number(let n) = self { n } else { nil } }
    public var bool: Bool? { if case .bool(let b) = self { b } else { nil } }
    public var array: [JSON]? { if case .array(let a) = self { a } else { nil } }
    public var object: JSONObject? { if case .object(let o) = self { o } else { nil } }
    public var isNull: Bool { self == .null }

    public subscript(key: String) -> JSON? { object?[key] }
}

extension JSON: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByBooleanLiteral,
    ExpressibleByArrayLiteral, ExpressibleByDictionaryLiteral, ExpressibleByFloatLiteral
{
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .number(Double(value)) }
    public init(floatLiteral value: Double) { self = .number(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
    public init(arrayLiteral elements: JSON...) { self = .array(elements) }
    public init(dictionaryLiteral elements: (String, JSON)...) { self = .object(JSONObject(elements)) }
}

/**
 * A JSON object that keeps its keys in insertion order, as JavaScript objects do for the keys
 * the protocol uses. Equality ignores order, as the vectors compare objects.
 */
public struct JSONObject: Equatable, Sendable, Sequence {
    public private(set) var keys: [String] = []
    private var values: [String: JSON] = [:]

    public init() {}

    public init(_ pairs: [(String, JSON)]) {
        for (k, v) in pairs { self[k] = v }
    }

    public var count: Int { keys.count }

    /** Setting a key that exists keeps its place; setting nil removes it. */
    public subscript(key: String) -> JSON? {
        get { values[key] }
        set {
            if let newValue {
                if values.updateValue(newValue, forKey: key) == nil { keys.append(key) }
            } else if values.removeValue(forKey: key) != nil {
                keys.removeAll { $0 == key }
            }
        }
    }

    public func makeIterator() -> AnyIterator<(String, JSON)> {
        var i = keys.makeIterator()
        return AnyIterator { i.next().map { ($0, values[$0]!) } }
    }

    public static func == (a: JSONObject, b: JSONObject) -> Bool { a.values == b.values }
}

// --- Writing ---------------------------------------------------------------

private func writeString(_ s: String, to out: inout String) {
    out += "\""
    for u in s.unicodeScalars {
        switch u {
        case "\"": out += "\\\""
        case "\\": out += "\\\\"
        case "\u{08}": out += "\\b"
        case "\u{0C}": out += "\\f"
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        case _ where u.value < 0x20:
            let hex = String(u.value, radix: 16)
            out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
        default: out.unicodeScalars.append(u)
        }
    }
    out += "\""
}

/** Number::toString from ECMA-262: the shortest digits that round-trip, placed as JavaScript does. */
func jsNumber(_ x: Double) -> String {
    if x.isNaN || x.isInfinite { return "null" }
    if x == 0 { return "0" }
    if x < 0 { return "-" + jsNumber(-x) }
    // Swift prints the same shortest round-trip digits; only where the point goes differs.
    var text = "\(x)"
    var exp = 0
    if let e = text.firstIndex(where: { $0 == "e" || $0 == "E" }) {
        exp = Int(text[text.index(after: e)...])!
        text = String(text[..<e])
    }
    var intPart = text
    var frac = ""
    if let dot = text.firstIndex(of: ".") {
        intPart = String(text[..<dot])
        frac = String(text[text.index(after: dot)...])
    }
    var digits = intPart + frac
    var n = intPart.count + exp // the point sits after n digits
    while digits.hasPrefix("0") && digits.count > 1 {
        digits.removeFirst()
        n -= 1
    }
    while digits.hasSuffix("0") && digits.count > 1 { digits.removeLast() }
    let k = digits.count
    if k <= n && n <= 21 { return digits + String(repeating: "0", count: n - k) }
    if 0 < n && n <= 21 {
        return String(digits.prefix(n)) + "." + String(digits.dropFirst(n))
    }
    if -6 < n && n <= 0 { return "0." + String(repeating: "0", count: -n) + digits }
    let e = n - 1
    let sign = e < 0 ? "-" : "+"
    let mantissa = k == 1 ? digits : String(digits.prefix(1)) + "." + String(digits.dropFirst())
    return mantissa + "e" + sign + String(abs(e))
}

// --- Reading ---------------------------------------------------------------

private struct JSONParser {
    /**
     * Arrays and objects nest at most this deep. Sealed text is parsed before its signature is
     * checked, and anyone can seal to a public key: without a cap, deep nesting would overflow the
     * stack, where JavaScript's JSON.parse throws. Real bodies nest a few levels.
     */
    static let maxDepth = 256

    let b: [UInt8]
    var i = 0
    var depth = 0

    init(_ bytes: [UInt8]) { b = bytes }

    func fail() -> ProtocolError { ProtocolError(.badSchema, "not JSON") }

    mutating func document() throws -> JSON {
        let v = try value()
        skip()
        if i != b.count { throw fail() }
        return v
    }

    mutating func skip() {
        while i < b.count, b[i] == 0x20 || b[i] == 0x09 || b[i] == 0x0A || b[i] == 0x0D { i += 1 }
    }

    mutating func value() throws -> JSON {
        skip()
        guard i < b.count else { throw fail() }
        switch b[i] {
        case UInt8(ascii: "{"): return try object()
        case UInt8(ascii: "["): return try array()
        case UInt8(ascii: "\""): return .string(try string())
        case UInt8(ascii: "t"): try literal("true"); return .bool(true)
        case UInt8(ascii: "f"): try literal("false"); return .bool(false)
        case UInt8(ascii: "n"): try literal("null"); return .null
        default: return .number(try number())
        }
    }

    mutating func literal(_ word: String) throws {
        let w = Array(word.utf8)
        guard i + w.count <= b.count, Array(b[i..<i + w.count]) == w else { throw fail() }
        i += w.count
    }

    mutating func enter() throws {
        depth += 1
        if depth > Self.maxDepth { throw ProtocolError(.badSchema, "JSON nests too deep") }
    }

    mutating func object() throws -> JSON {
        try enter()
        defer { depth -= 1 }
        i += 1
        var o = JSONObject()
        skip()
        if i < b.count, b[i] == UInt8(ascii: "}") {
            i += 1
            return .object(o)
        }
        while true {
            skip()
            guard i < b.count, b[i] == UInt8(ascii: "\"") else { throw fail() }
            let k = try string()
            skip()
            guard i < b.count, b[i] == UInt8(ascii: ":") else { throw fail() }
            i += 1
            o[k] = try value() // a repeated key keeps its first place and its last value
            skip()
            guard i < b.count else { throw fail() }
            if b[i] == UInt8(ascii: ",") { i += 1; continue }
            if b[i] == UInt8(ascii: "}") { i += 1; return .object(o) }
            throw fail()
        }
    }

    mutating func array() throws -> JSON {
        try enter()
        defer { depth -= 1 }
        i += 1
        var items: [JSON] = []
        skip()
        if i < b.count, b[i] == UInt8(ascii: "]") {
            i += 1
            return .array(items)
        }
        while true {
            items.append(try value())
            skip()
            guard i < b.count else { throw fail() }
            if b[i] == UInt8(ascii: ",") { i += 1; continue }
            if b[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
            throw fail()
        }
    }

    mutating func hex4() throws -> UInt32 {
        guard i + 4 <= b.count else { throw fail() }
        var v: UInt32 = 0
        for _ in 0..<4 {
            let c = b[i]
            let d: UInt8
            switch c {
            case 0x30...0x39: d = c - 0x30
            case 0x41...0x46: d = c - 0x41 + 10
            case 0x61...0x66: d = c - 0x61 + 10
            default: throw fail()
            }
            v = v << 4 | UInt32(d)
            i += 1
        }
        return v
    }

    mutating func string() throws -> String {
        i += 1
        var bytes: [UInt8] = []
        while true {
            guard i < b.count else { throw fail() }
            let c = b[i]
            if c == UInt8(ascii: "\"") { i += 1; break }
            if c < 0x20 { throw fail() }
            if c != UInt8(ascii: "\\") {
                bytes.append(c)
                i += 1
                continue
            }
            i += 1
            guard i < b.count else { throw fail() }
            let e = b[i]
            i += 1
            switch e {
            case UInt8(ascii: "\""): bytes.append(0x22)
            case UInt8(ascii: "\\"): bytes.append(0x5C)
            case UInt8(ascii: "/"): bytes.append(0x2F)
            case UInt8(ascii: "b"): bytes.append(0x08)
            case UInt8(ascii: "f"): bytes.append(0x0C)
            case UInt8(ascii: "n"): bytes.append(0x0A)
            case UInt8(ascii: "r"): bytes.append(0x0D)
            case UInt8(ascii: "t"): bytes.append(0x09)
            case UInt8(ascii: "u"):
                var u = try hex4()
                if (0xD800..<0xDC00).contains(u), i + 6 <= b.count, b[i] == 0x5C, b[i + 1] == UInt8(ascii: "u") {
                    let save = i
                    i += 2
                    let low = try hex4()
                    if (0xDC00..<0xE000).contains(low) {
                        u = 0x10000 + ((u - 0xD800) << 10) + (low - 0xDC00)
                    } else {
                        i = save
                    }
                }
                // A lone surrogate, which a JavaScript string can hold and a Swift one cannot: the
                // protocol refuses it, so no port reads other text than was signed (#1090).
                guard let scalar = Unicode.Scalar(u) else { throw ProtocolError(.badSchema, "lone surrogate") }
                bytes.append(contentsOf: Array(String(Character(scalar)).utf8))
            default: throw fail()
            }
        }
        // The input was a Swift String, so its bytes are UTF-8.
        return String(decoding: bytes, as: UTF8.self)
    }

    mutating func number() throws -> Double {
        let start = i
        if i < b.count, b[i] == UInt8(ascii: "-") { i += 1 }
        guard i < b.count else { throw fail() }
        if b[i] == UInt8(ascii: "0") {
            i += 1
        } else if (0x31...0x39).contains(b[i]) {
            while i < b.count, (0x30...0x39).contains(b[i]) { i += 1 }
        } else {
            throw fail()
        }
        if i < b.count, b[i] == UInt8(ascii: ".") {
            i += 1
            let s = i
            while i < b.count, (0x30...0x39).contains(b[i]) { i += 1 }
            if i == s { throw fail() }
        }
        if i < b.count, b[i] == UInt8(ascii: "e") || b[i] == UInt8(ascii: "E") {
            i += 1
            if i < b.count, b[i] == UInt8(ascii: "+") || b[i] == UInt8(ascii: "-") { i += 1 }
            let s = i
            while i < b.count, (0x30...0x39).contains(b[i]) { i += 1 }
            if i == s { throw fail() }
        }
        guard let d = Double(String(decoding: b[start..<i], as: UTF8.self)) else { throw fail() }
        return d
    }
}
