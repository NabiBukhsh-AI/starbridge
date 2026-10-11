import Foundation
@testable import StarbridgeProtocol
import XCTest

// Where Swift's defaults differ from JavaScript's in the schemas, beyond what the vectors hold.
final class SchemaTests: XCTestCase {
    private func validDecision() throws -> JSONObject {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../../../../packages/protocol/vectors/schemas.json").standardizedFileURL
        let v = try JSON.parse(String(decoding: Data(contentsOf: url), as: UTF8.self))
        return v["decision"]!.array!.first { $0["name"] == "valid" }!["body"]!.object!
    }

    /** JavaScript compares strings by code units; Swift's == equates canonically equivalent ones. */
    func testOptionsThatOnlyLookAlikeAreDistinct() throws {
        var body = try validDecision()
        body["options"] = ["\u{E9}", "e\u{301}"]
        body["recommended"] = "e\u{301}"
        XCTAssertNoThrow(try parseStrict("decision", .object(body)))
        // A recommendation equal to an option only canonically names none of them.
        body["options"] = ["\u{E9}", "x"]
        XCTAssertThrowsError(try parseStrict("decision", .object(body)))
    }

    /** JSON.parse reads 1e309 as Infinity, which zod's number refuses. */
    func testInfinityIsNotANumber() throws {
        let text = #"{"v":1,"id":"q_1","to":["phone"],"takenAt":"2026-10-04T12:00:00Z","providers":[{"provider":"zai","windows":[{"id":"primary","label":"5h","usedPercent":1e309,"windowMinutes":300,"resetsAt":null,"pace":null}]}],"alerts":[]}"#
        XCTAssertEqual((try? parseBody("quota", text)) == nil, true)
        XCTAssertNotNil(try? parseBody("quota", text.replacingOccurrences(of: "1e309", with: "20")))
    }
}
