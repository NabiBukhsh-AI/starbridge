// packages/protocol/src/heads.ts: detecting a withheld directory entry from the heads other
// members sign (PROTOCOL.md "Directory"). Devices sign theirs into answers and machines into
// every item, so each side can tell when the server serves it a shorter chain than a member it
// hears from has seen.

/**
 * The longest head each signer vouched for, keyed by the signer, by "signer/by" for a head it
 * passed on from member `by`, or by "signer/?" for one passed on from a member this chain does
 * not list yet: one such slot per signer, so storage stays bounded. Keys keep insertion order.
 */
public struct Heads: Equatable, Sendable, Sequence {
    public private(set) var keys: [String] = []
    private var heads: [String: DirectoryHead] = [:]

    public init() {}

    public subscript(key: String) -> DirectoryHead? {
        get { heads[key] }
        set {
            if let newValue {
                if heads.updateValue(newValue, forKey: key) == nil { keys.append(key) }
            } else if heads.removeValue(forKey: key) != nil {
                keys.removeAll { $0 == key }
            }
        }
    }

    public var isEmpty: Bool { keys.isEmpty }

    public func makeIterator() -> AnyIterator<(String, DirectoryHead)> {
        var i = keys.makeIterator()
        return AnyIterator { i.next().map { ($0, heads[$0]!) } }
    }

    public static func == (a: Heads, b: Heads) -> Bool { a.heads == b.heads }
}

/** The `revoke` entry that names a member: who signed it, and when. */
public struct Revocation: Equatable, Sendable {
    public let id: String
    public let by: String
    public let at: String
}

/** A kept head the chain lacks, who signed it, and the `revoke` that names a member it hangs on. */
public struct Held: Equatable, Sendable {
    public let id: String
    public let by: String?
    public let head: DirectoryHead
    public let revoked: Revocation?
}

private func signerOf(_ key: String) -> String {
    String(key.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first ?? "")
}

/** An entry's envelope and its body's `op`, `id` and `at`, when the entry is a well-formed envelope. */
private func ops(_ entries: [JSON]) -> [(signer: String, op: String?, id: String?, at: String?)?] {
    entries.map { raw in
        guard let env = try? SignedEnvelope(json: raw) else { return nil }
        let body = (try? JSON.parse(env.body))?.object
        return (env.signer, body?["op"]?.string, body?["id"]?.string, body?["at"]?.string)
    }
}

public enum HeadBook {
    /** The `revoke` entry that names member `id`, if any; a `recover` names no one. */
    public static func revocation(of id: String, in entries: [JSON]) -> Revocation? {
        for e in ops(entries) {
            if let e, e.op == "revoke", e.id == id { return Revocation(id: id, by: e.signer, at: e.at ?? "") }
        }
        return nil
    }

    /**
     * Whether a head that member `id` signed, or that names it as `by`, no longer counts: the
     * chain lists `id` as revoked, and a `recover` came after any `revoke` that names it. A
     * `revoke` alone ends nothing; a `recover`, which revokes every member, ends every earlier hold.
     */
    static func removed(_ dir: Directory, _ entries: [JSON], _ id: String) -> Bool {
        guard dir.members[id]?.active == false else { return false }
        var revokedAt = -1
        var recoveredAt = -1
        for (i, e) in ops(entries).enumerated() {
            guard let e else { continue }
            if e.op == "revoke", e.id == id { revokedAt = i }
            if e.op == "recover" { recoveredAt = i }
        }
        return recoveredAt > revokedAt
    }

    /**
     * Records the head `signer` signed into an item. A shorter head never replaces a longer one
     * the chain `entries` lacks, so replaying an older item cannot lift a hold. With `dir`, a `by`
     * that chain does not list goes in the signer's one unknown slot, and a head passed on from a
     * `by` it lists as revoked is not kept. True when it changed.
     */
    @discardableResult
    public static func note(_ heads: inout Heads, signer: String, head: DirectoryHead?, entries: [JSON], dir: Directory?) -> Bool {
        guard let head else { return false }
        let by = head.by.flatMap { $0 != signer ? $0 : nil }
        if let by, dir?.members[by]?.active == false { return false }
        let key: String
        if let by {
            key = dir.map { $0.members[by] == nil } == true ? "\(signer)/?" : "\(signer)/\(by)"
        } else {
            key = signer
        }
        let known = heads[key]
        // A head passed on from a member a `recover` removed counts no more: any head replaces
        // it, or a forged long one would keep a real shorter one out of its slot for good.
        let dropped = known?.by.map { knownBy in dir.map { removed($0, entries, knownBy) } ?? false } ?? false
        let replace = known.map { known in
            dropped || head.length > known.length
                || (Directories.holds(entries, known.pin) && !Directories.holds(entries, head.pin))
        } ?? true
        if replace { heads[key] = head }
        return replace
    }

    /**
     * A kept head the chain `entries` lacks: the server is holding back entries it has, or
     * serving the member that signed it another chain. It counts while its signer is listed in
     * `dir` and neither it nor its `by` was removed by a `recover`. A head whose signer or `by`
     * the chain lists as revoked says so in `revoked`; a head without one is returned first.
     */
    public static func withheld(_ heads: Heads, dir: Directory, entries: [JSON]) -> Held? {
        var fork: Held?
        for (key, head) in heads {
            let id = signerOf(key)
            let by = head.by.flatMap { $0 != id ? $0 : nil }
            if dir.members[id] == nil || removed(dir, entries, id) { continue }
            if let by, removed(dir, entries, by) { continue }
            if Directories.holds(entries, head.pin) { continue }
            let revoked = (dir.members[id]?.active == true ? nil : revocation(of: id, in: entries))
                ?? (by.flatMap { dir.members[$0]?.active == false ? revocation(of: $0, in: entries) : nil })
            guard let revoked else { return Held(id: id, by: by, head: head, revoked: nil) }
            if fork == nil { fork = Held(id: id, by: by, head: head, revoked: revoked) }
        }
        return fork
    }

    /**
     * Drops every kept head member `id` signed or that names it as `by`: the owner's way out after
     * revoking a member that signed a false long head. True when any went.
     */
    @discardableResult
    public static func forget(_ heads: inout Heads, id: String) -> Bool {
        var changed = false
        for (key, head) in heads where signerOf(key) == id || head.by == id {
            heads[key] = nil
            changed = true
        }
        return changed
    }
}
