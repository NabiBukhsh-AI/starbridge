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
    /** Where the decision and prompt lists left off. */
    var cursor = ""
    var promptCursor = ""
    var decisions: [SavedDecision] = []
    var prompts: [SavedPrompt] = []
    var runs: [SavedRun] = []
    /** Runs dismissed here, with the update they hid, until a newer one comes. */
    var dismissedRuns: [String: String] = [:]
    var outbox: [QueuedAnswer] = []
    var heads: [SavedHead] = []
    /** This iPhone's APNs subscription, dropped at sign-out. */
    var pushId: String?

    init(server: String) { self.server = server }

    /** A field a newer release added reads as its default, so an update keeps the saved state. */
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        server = try c.decode(String.self, forKey: .server)
        account = try c.decodeIfPresent(String.self, forKey: .account)
        accountExists = try c.decodeIfPresent(Bool.self, forKey: .accountExists) ?? false
        me = try c.decodeIfPresent(SavedMember.self, forKey: .me)
        pinLength = try c.decodeIfPresent(Int.self, forKey: .pinLength)
        pinHead = try c.decodeIfPresent(String.self, forKey: .pinHead)
        entries = try c.decodeIfPresent([String].self, forKey: .entries) ?? []
        joining = try c.decodeIfPresent(String.self, forKey: .joining)
        digitJoin = try c.decodeIfPresent(DigitJoin.self, forKey: .digitJoin)
        pendingGenesis = try c.decodeIfPresent(String.self, forKey: .pendingGenesis)
        recovering = try c.decodeIfPresent(SavedMember.self, forKey: .recovering)
        cursor = try c.decodeIfPresent(String.self, forKey: .cursor) ?? ""
        promptCursor = try c.decodeIfPresent(String.self, forKey: .promptCursor) ?? ""
        decisions = (try c.decodeIfPresent([Lossy<SavedDecision>].self, forKey: .decisions) ?? []).compactMap(\.value)
        prompts = (try c.decodeIfPresent([Lossy<SavedPrompt>].self, forKey: .prompts) ?? []).compactMap(\.value)
        runs = (try c.decodeIfPresent([Lossy<SavedRun>].self, forKey: .runs) ?? []).compactMap(\.value)
        dismissedRuns = try c.decodeIfPresent([String: String].self, forKey: .dismissedRuns) ?? [:]
        outbox = (try c.decodeIfPresent([Lossy<QueuedAnswer>].self, forKey: .outbox) ?? []).compactMap(\.value)
        heads = try c.decodeIfPresent([SavedHead].self, forKey: .heads) ?? []
        pushId = try c.decodeIfPresent(String.self, forKey: .pushId)
    }

    var pin: Pin? {
        get { pinLength.flatMap { length in pinHead.map { Pin(length: length, head: $0) } } }
        set {
            pinLength = newValue?.length
            pinHead = newValue?.head
        }
    }
}

/** The app group the app shares with its notification service extension. */
let APP_GROUP = "group.dev.starbridge.ios"

/**
 * [Saved] as a JSON file, out of iCloud backups: in the app group's container, which the
 * notification service extension reads, else in Application Support.
 */
struct Disk {
    let url: URL

    static let standard: Disk = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("saved.json")
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP)?.appendingPathComponent("saved.json") else {
            return Disk(url: support)
        }
        // Builds before the app group kept the file in Application Support: it moves once.
        if !FileManager.default.fileExists(atPath: group.path), FileManager.default.fileExists(atPath: support.path) {
            try? FileManager.default.moveItem(at: support, to: group)
        }
        return Disk(url: group)
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
