// packages/protocol/src/keys.ts: member keys and the recovery key.

/** A device's or machine's keys. The secret halves never leave it. */
public struct MemberKeys: Sendable {
    public let box: KeyPair
    public let sign: KeyPair

    public init(box: KeyPair, sign: KeyPair) {
        self.box = box
        self.sign = sign
    }

    public static func generate() -> MemberKeys { MemberKeys(box: Sodium.boxKeyPair(), sign: Sodium.signKeyPair()) }

    public var boxPk: String { toB64(box.publicKey) }
    public var signPk: String { toB64(sign.publicKey) }
}

/** What is wrong with a typed recovery key; `index` counts characters from 0, separators aside. */
public enum RecoveryKeyProblem: Equatable, Sendable {
    case badCharacter(index: Int, char: Character)
    case length(count: Int)
    case checksum
}

public struct RecoveryKeyReading: Equatable, Sendable {
    /** Characters of the key, separators aside. */
    public let count: Int
    public let problem: RecoveryKeyProblem?
}

public struct RecoveryKeyError: Error, Equatable {
    public let reading: RecoveryKeyReading
}

/**
 * The recovery key people write down: a 16-byte seed and its 12-bit check, 140 bits, as 28
 * Crockford base32 characters in seven groups of four ("7KQ2-M9XD-…"). Its seed, stretched,
 * is the Ed25519 key that signs recovery entries.
 */
public enum RecoveryKeys {
    static let chars = 28

    /** A fresh recovery seed: 16 bytes, shown once as a recovery key. */
    public static func generateSeed() -> SecretKey { SecretKey(Sodium.randomBytes(16)) }

    /** The 12-bit check: the first 12 bits of BLAKE2b-256 of "starbridge/v1/recovery-check", NUL, the seed. */
    private static func check(_ seed: [UInt8]) -> [UInt8] {
        let h = Sodium.hash(label("recovery-check") + seed)
        return [h[0], h[1] & 0xF0]
    }

    public static func encode(_ seed: SecretKey) -> String {
        precondition(seed.count == 16, "a recovery key holds a 16-byte seed")
        var bytes = seed.bytes
        bytes += check(bytes)
        defer { wipe(&bytes) }
        let chars = Array(Crockford.encode(bytes).prefix(Self.chars))
        return stride(from: 0, to: chars.count, by: 4).map { String(chars[$0..<min($0 + 4, chars.count)]) }.joined(separator: "-")
    }

    /** Any case, with or without dashes and spaces; Crockford's look-alikes (O for 0, I and L for 1). */
    static func keyChars(_ text: String) -> [Character] { Crockford.normalize(text) }

    /**
     * Reads typed text as a recovery key. With `typing`, only a character no key holds counts:
     * more typing fixes a short key.
     */
    public static func read(_ text: String, typing: Bool = false) -> RecoveryKeyReading {
        let chars = keyChars(text)
        let problem: RecoveryKeyProblem?
        if let i = chars.firstIndex(where: { !Crockford.alphabet.contains($0) }) {
            problem = .badCharacter(index: i, char: chars[i])
        } else if typing {
            problem = nil
        } else if chars.count != Self.chars {
            problem = .length(count: chars.count)
        } else {
            problem = checks(chars) ? nil : .checksum
        }
        return RecoveryKeyReading(count: chars.count, problem: problem)
    }

    /** 28 characters are 140 bits: one padding character brings the check's last 4 bits into byte 17. */
    private static func keyBytes(_ chars: [Character]) -> [UInt8] { try! Crockford.decode(chars + ["0"]) }

    private static func checks(_ chars: [Character]) -> Bool {
        var bytes = keyBytes(chars)
        defer { wipe(&bytes) }
        let c = check(Array(bytes[0..<16]))
        return bytes[16] == c[0] && bytes[17] & 0xF0 == c[1]
    }

    /** The seed behind a typed recovery key. */
    public static func seed(_ text: String) throws(RecoveryKeyError) -> SecretKey {
        let reading = read(text)
        if reading.problem != nil { throw RecoveryKeyError(reading: reading) }
        var bytes = keyBytes(keyChars(text))
        defer { wipe(&bytes) }
        return SecretKey(Array(bytes[0..<16]))
    }

    /**
     * The recovery signing key pair: the 16-byte seed stretched to the 32 bytes Ed25519 takes
     * with BLAKE2b-256 of "starbridge/v1/recovery-seed", NUL, the seed.
     */
    public static func keyPair(_ seed: SecretKey) -> KeyPair {
        precondition(seed.count == 16, "a recovery seed is 16 bytes")
        return Sodium.signKeyPair(seed: Sodium.secretHash(prefix: label("recovery-seed"), seed))
    }
}
