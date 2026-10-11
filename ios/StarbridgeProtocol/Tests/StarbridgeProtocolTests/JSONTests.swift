@testable import StarbridgeProtocol
import XCTest

// A body this package signs must be the text JSON.stringify writes for it. The expected strings
// come from JavaScript.
final class JSONTests: XCTestCase {
    func testNumbersPrintAsJavaScriptPrintsThem() {
        let cases: [(Double, String)] = [
            (1, "1"), (0.1, "0.1"), (1e21, "1e+21"), (1.5e-7, "1.5e-7"), (1.2345678901234568e20, "123456789012345680000"),
            (-0.0, "0"), (33.3, "33.3"), (-12.5, "-12.5"), (1e-6, "0.000001"), (0.000001234, "0.000001234"),
            (5e-324, "5e-324"), (1.7976931348623157e308, "1.7976931348623157e+308"), (100, "100"), (9007199254740992, "9007199254740992"),
        ]
        for (x, js) in cases { XCTAssertEqual(JSON.number(x).text, js, "\(x)") }
    }

    func testStringsEscapeOnlyWhatJSONStringifyEscapes() {
        let s = "a\u{0}\u{1F}\"\\\n\r\t\u{8}\u{C}/\u{7F}\u{2028}é😀"
        XCTAssertEqual(JSON.string(s).text, "\"a\\u0000\\u001f\\\"\\\\\\n\\r\\t\\b\\f/\u{7F}\u{2028}é😀\"")
    }

    func testObjectsKeepKeyOrderAndARepeatedKeyItsFirstPlace() throws {
        let j = try JSON.parse(#"{"b":1,"a":[true,null,"x"],"b":2}"#)
        XCTAssertEqual(j.text, #"{"b":2,"a":[true,null,"x"]}"#)
    }

    func testParseRefusesWhatJSONParseRefuses() {
        for bad in ["", "{", "[1,]", "{\"a\":1,}", "01", "1.", ".5", "+1", "'a'", "\"\u{1}\"", "nul", "{\"a\" 1}", "\u{FEFF}{}", "1 2"] {
            XCTAssertThrowsError(try JSON.parse(bad), bad)
        }
        XCTAssertEqual(try JSON.parse(" \t\n\r[1e2,-0.5,\"\\u00e9\\ud83d\\ude00\"] "), [100, -0.5, "é😀"])
    }

    /** Sealed text is parsed before its signature is checked: deep nesting fails, never overflows. */
    func testDeepNestingIsRefusedNotACrash() throws {
        let deep = String(repeating: "[", count: 100_000) + String(repeating: "]", count: 100_000)
        XCTAssertThrowsError(try JSON.parse(deep)) { XCTAssertEqual(($0 as? ProtocolError)?.code, .badSchema) }
        let ok = String(repeating: "{\"a\":", count: 255) + "1" + String(repeating: "}", count: 255)
        XCTAssertNoThrow(try JSON.parse(ok))
    }
}
