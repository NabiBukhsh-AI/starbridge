import XCTest
@testable import Starbridge

final class VaultTests: XCTestCase {
    private let vault = KeychainVault(service: "dev.starbridge.ios.tests", account: "vault-tests")

    override func tearDownWithError() throws { try vault.save(Secrets()) }

    func testSecretsRoundTripThroughTheKeychain() throws {
        XCTAssertEqual(try vault.load(), Secrets())
        var secrets = Secrets(session: "sb_1")
        secrets.signSk = "key"
        try vault.save(secrets)
        XCTAssertEqual(try vault.load(), secrets)
        // A second save replaces the item rather than adding one.
        secrets.session = "sb_2"
        try vault.save(secrets)
        XCTAssertEqual(try vault.load(), secrets)
        try vault.save(Secrets())
        XCTAssertEqual(try vault.load(), Secrets())
    }
}
