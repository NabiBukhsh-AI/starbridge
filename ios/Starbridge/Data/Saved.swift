import Foundation
import StarbridgeProtocol

/** This iPhone as a directory member. */
struct SavedMember: Codable, Equatable {
    let id: String
    let name: String
    let boxPk: String
    let signPk: String

    var member: Member { Member(id: id, role: .device, name: name, boxPk: boxPk, signPk: signPk) }
}

/** A join by digits in progress (PROTOCOL.md, "Joining by digits"). */
struct DigitJoin: Codable, Equatable {
    let id: String
    let request: String
    var approverKey: String?
    var digits: String?
    /** The owner saw the same digits on both screens. */
    var matched = false
}

/** What the app keeps between launches that is not secret. */
struct Saved: Codable, Equatable {
    var server: String
    var account: String?
    /** The account already has a device, which this iPhone joins through. */
    var accountExists = false
    var me: SavedMember?
    var pinLength: Int?
    var pinHead: String?
    /** The directory as verified, each entry's JSON text. */
    var entries: [String] = []
    /** The pairing code of a join by a scanned QR code. */
    var joining: String?
    var digitJoin: DigitJoin?
    /**
     * The account's first entry, signed and kept until the owner confirms the recovery key, when
     * it goes to the server (#370). A lost reply is retried with the same entry.
     */
    var pendingGenesis: String?
    /** While recovering: the member whose keys this iPhone made, until the chain holds it. */
    var recovering: SavedMember?

    init(server: String) { self.server = server }

    var pin: Pin? {
        get { pinLength.flatMap { length in pinHead.map { Pin(length: length, head: $0) } } }
        set {
            pinLength = newValue?.length
            pinHead = newValue?.head
        }
    }
}

/** [Saved] as a JSON file in Application Support, out of iCloud backups. */
struct Disk {
    let url: URL

    static let standard: Disk = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return Disk(url: dir.appendingPathComponent("saved.json"))
    }()

    func load() -> Saved? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Saved.self, from: data)
    }

    func save(_ saved: Saved) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(saved).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var target = url
        try target.setResourceValues(values)
    }
}
