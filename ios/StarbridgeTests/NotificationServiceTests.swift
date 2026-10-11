import StarbridgeProtocol
import UserNotifications
import XCTest
@testable import Starbridge

/**
 * The notification service extension's work, driven here: the simulator skips service
 * extensions for `simctl push`, so this calls `Notify.rewrite` with a push as APNs delivers it,
 * against the keys and state in the shared app group and keychain group, and measures the memory
 * the work adds against the extension's 24 MB limit.
 */
final class NotificationServiceTests: XCTestCase {
    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: Disk.standard.url)
        try KeychainVault().save(Secrets())
    }

    private func deliver(_ p: JSON) async throws -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Starbridge"
        content.body = "A question needs you"
        content.categoryIdentifier = "decision"
        let object = try JSONSerialization.jsonObject(with: Data(p.text.utf8))
        content.userInfo = ["aps": ["mutable-content": 1], "p": object]
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        return await Notify.rewrite(request) ?? content
    }

    func testReplacesThePlaceholderFromTheSharedState() async throws {
        let f = try NotifyFixture()
        try Disk.standard.save(f.saved)
        try KeychainVault().save(f.secrets)
        let before = Notify.footprint()
        var shown: UNNotificationContent?
        for i in 0..<20 { shown = try await deliver(f.payload(try f.decision("d_\(i)", replies: true))) }
        let added = Double(Notify.footprint() - min(before, Notify.footprint())) / 1_048_576
        print("NSE work added \(String(format: "%.1f", added)) MB over 20 pushes; process at \(Notify.footprint() / 1_048_576) MB")
        XCTAssertLessThan(added, 8, "the extension's work must leave room under its 24 MB limit")
        XCTAssertEqual(shown?.title, "Merge the inbox PR?")
        XCTAssertEqual(shown?.subtitle, "devbox · starbridge")
        XCTAssertEqual(shown?.categoryIdentifier, "d.d_19")
        let categories = await UNUserNotificationCenter.current().notificationCategories()
        XCTAssertEqual(categories.first { $0.identifier == "d.d_19" }?.actions.map(\.title), ["Wait", "Merge", "Close", "Reply"])
    }

    func testKeepsThePlaceholderWithoutTheKeys() async throws {
        let f = try NotifyFixture()
        try Disk.standard.save(f.saved)
        let shown = try await deliver(f.payload(try f.decision("d_none")))
        XCTAssertEqual(shown.title, "Starbridge")
        XCTAssertEqual(shown.body, "A question needs you")
    }
}
