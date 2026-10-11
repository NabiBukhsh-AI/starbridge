import Clibsodium

// The libsodium calls the protocol makes, as packages/protocol/src/sodium.ts and Android's
// Sodium.kt make them. libsodium does the cryptography; this file sizes buffers, keeps secret
// keys in memory it wipes, and maps failures to the protocol's error codes.

/**
 * Error codes are part of the protocol: packages/protocol's test vectors name them, and every
 * client reports the same ones.
 */
public struct ProtocolError: Error, Equatable, CustomStringConvertible {
    public enum Code: String, Sendable {
        case badEncoding = "bad-encoding"
        case badSchema = "bad-schema"
        case badSignature = "bad-signature"
        case badMac = "bad-mac"
        case badCommitment = "bad-commitment"
        case badKey = "bad-key"
        case cannotOpen = "cannot-open"
        case wrongKind = "wrong-kind"
        case wrongRecipient = "wrong-recipient"
        case idMismatch = "id-mismatch"
        case unknownSigner = "unknown-signer"
        case revokedSigner = "revoked-signer"
        case signerNotAllowed = "signer-not-allowed"
        case badGenesis = "bad-genesis"
        case badChain = "bad-chain"
        case badRecovery = "bad-recovery"
        case wrongRecoveryKey = "wrong-recovery-key"
        case duplicateMember = "duplicate-member"
        case unknownMember = "unknown-member"
        case wrongAccount = "wrong-account"
        case rollback = "rollback"
        case wrongInput = "wrong-input"
        case scopeNotOffered = "scope-not-offered"
        case expired = "expired"
    }

    public let code: Code
    public let detail: String?

    public init(_ code: Code, _ detail: String? = nil) {
        self.code = code
        self.detail = detail
    }

    public var description: String { detail.map { "\(code.rawValue): \($0)" } ?? code.rawValue }
}

/** A caller's mistake, such as sealing to recipients the body does not name; never a peer's. */
public struct UsageError: Error, CustomStringConvertible {
    public let description: String
    init(_ description: String) { self.description = description }
}

private let sodiumReady: Bool = sodium_init() >= 0

@inline(__always) func ready() {
    precondition(sodiumReady, "libsodium failed to initialize")
}

/**
 * A secret key in memory this package allocates and wipes when the last reference goes. Swift
 * arrays copy on write and leave copies behind, so keys never live in one longer than it takes to
 * build this.
 */
public final class SecretKey: @unchecked Sendable {
    private let buffer: UnsafeMutableRawBufferPointer

    public var count: Int { buffer.count }

    init(count: Int, fill: (UnsafeMutableRawBufferPointer) -> Void) {
        precondition(count > 0)
        buffer = .allocate(byteCount: count, alignment: 16)
        buffer.initializeMemory(as: UInt8.self, repeating: 0)
        fill(buffer)
    }

    /** Copies `bytes`; the caller wipes its own copy. */
    public convenience init(_ bytes: [UInt8]) {
        self.init(count: bytes.count) { $0.copyBytes(from: bytes) }
    }

    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(buffer))
    }

    /** A copy as an array, for storage that takes bytes, such as the keychain. */
    public var bytes: [UInt8] { Array(buffer) }

    deinit {
        sodium_memzero(buffer.baseAddress, buffer.count)
        buffer.deallocate()
    }
}

public struct KeyPair: Sendable {
    public let publicKey: [UInt8]
    public let secretKey: SecretKey

    public init(publicKey: [UInt8], secretKey: SecretKey) {
        self.publicKey = publicKey
        self.secretKey = secretKey
    }
}

/** Overwrites `bytes` with zeros, for derived secrets held in arrays only briefly. */
func wipe(_ bytes: inout [UInt8]) {
    bytes.withUnsafeMutableBytes { sodium_memzero($0.baseAddress, $0.count) }
}

/** Equal in time that depends only on the length, for MACs, hashes and commitments. */
public func constantTimeEqual(_ a: [UInt8], _ b: [UInt8]) -> Bool {
    ready()
    guard a.count == b.count else { return false }
    if a.isEmpty { return true }
    return a.withUnsafeBytes { pa in b.withUnsafeBytes { pb in sodium_memcmp(pa.baseAddress, pb.baseAddress, a.count) == 0 } }
}

/** Base64url without padding, the only binary encoding on the wire. */
public func toB64(_ bytes: [UInt8]) -> String {
    ready()
    let variant = sodium_base64_VARIANT_URLSAFE_NO_PADDING
    let size = sodium_base64_encoded_len(bytes.count, variant)
    var out = [CChar](repeating: 0, count: size)
    _ = bytes.withUnsafeBytes { src in
        sodium_bin2base64(&out, size, src.bindMemory(to: UInt8.self).baseAddress, bytes.count, variant)
    }
    return String(decoding: out.prefix(size - 1).map { UInt8(bitPattern: $0) }, as: UTF8.self)
}

/** Decodes base64url without padding as libsodium does: leftover bits must be zero. */
public func fromB64(_ text: String) throws -> [UInt8] {
    ready()
    let chars = Array(text.utf8)
    let ok = chars.allSatisfy { c in
        (0x41...0x5A).contains(c) || (0x61...0x7A).contains(c) || (0x30...0x39).contains(c) || c == 0x2D || c == 0x5F
    }
    guard ok else { throw ProtocolError(.badEncoding, "not base64url without padding") }
    if chars.isEmpty { return [] }
    var out = [UInt8](repeating: 0, count: chars.count * 3 / 4 + 1)
    var len = 0
    let whole = chars.withUnsafeBufferPointer { src in
        src.withMemoryRebound(to: CChar.self) { s in
            var end: UnsafePointer<CChar>? = nil
            let rc = sodium_base642bin(&out, out.count, s.baseAddress, s.count, nil, &len, &end, sodium_base64_VARIANT_URLSAFE_NO_PADDING)
            return rc == 0 && end == UnsafePointer(s.baseAddress! + s.count)
        }
    }
    guard whole else { throw ProtocolError(.badEncoding, "not base64url without padding") }
    return Array(out.prefix(len))
}

public func utf8(_ text: String) -> [UInt8] { Array(text.utf8) }

func concat(_ parts: [UInt8]...) -> [UInt8] { parts.flatMap { $0 } }

/** "starbridge/v1/<name>", NUL: every domain-separation label. */
func label(_ name: String) -> [UInt8] { utf8("starbridge/v1/\(name)") + [0] }

/** The libsodium calls, one per primitive the protocol names. */
public enum Sodium {
    public static func randomBytes(_ n: Int) -> [UInt8] {
        ready()
        var out = [UInt8](repeating: 0, count: n)
        randombytes_buf(&out, n)
        return out
    }

    /** X25519 keys for sealed boxes. */
    public static func boxKeyPair() -> KeyPair {
        ready()
        var pk = [UInt8](repeating: 0, count: Int(crypto_box_PUBLICKEYBYTES))
        let sk = SecretKey(count: Int(crypto_box_SECRETKEYBYTES)) { buf in
            _ = crypto_box_keypair(&pk, buf.u8)
        }
        return KeyPair(publicKey: pk, secretKey: sk)
    }

    /** X25519 keys from a 32-byte seed, as crypto_box_seed_keypair. */
    public static func boxKeyPair(seed: [UInt8]) -> KeyPair {
        ready()
        precondition(seed.count == Int(crypto_box_SEEDBYTES), "a box seed is 32 bytes")
        var pk = [UInt8](repeating: 0, count: Int(crypto_box_PUBLICKEYBYTES))
        let sk = SecretKey(count: Int(crypto_box_SECRETKEYBYTES)) { buf in
            _ = crypto_box_seed_keypair(&pk, buf.u8, seed)
        }
        return KeyPair(publicKey: pk, secretKey: sk)
    }

    /** Ed25519 keys for signatures. */
    public static func signKeyPair() -> KeyPair {
        ready()
        var pk = [UInt8](repeating: 0, count: Int(crypto_sign_PUBLICKEYBYTES))
        let sk = SecretKey(count: Int(crypto_sign_SECRETKEYBYTES)) { buf in
            _ = crypto_sign_keypair(&pk, buf.u8)
        }
        return KeyPair(publicKey: pk, secretKey: sk)
    }

    /** Ed25519 keys from a 32-byte seed. */
    public static func signKeyPair(seed: SecretKey) -> KeyPair {
        ready()
        precondition(seed.count == Int(crypto_sign_SEEDBYTES), "a signing seed is 32 bytes")
        var pk = [UInt8](repeating: 0, count: Int(crypto_sign_PUBLICKEYBYTES))
        let sk = SecretKey(count: Int(crypto_sign_SECRETKEYBYTES)) { buf in
            seed.withUnsafeBytes { s in
                _ = crypto_sign_seed_keypair(&pk, buf.u8, s.u8)
            }
        }
        return KeyPair(publicKey: pk, secretKey: sk)
    }

    /** X25519; nil when libsodium refuses the result (all zeros: a low-order point). */
    static func scalarMult(_ secret: SecretKey, _ peer: [UInt8]) -> SecretKey? {
        ready()
        guard secret.count == Int(crypto_scalarmult_SCALARBYTES), peer.count == Int(crypto_scalarmult_BYTES) else { return nil }
        var rc: Int32 = -1
        let out = SecretKey(count: Int(crypto_scalarmult_BYTES)) { out in
            rc = secret.withUnsafeBytes { s in crypto_scalarmult(out.u8, s.u8, peer) }
        }
        return rc == 0 ? out : nil
    }

    /** BLAKE2b-256, unkeyed or keyed. */
    public static func hash(_ message: [UInt8], key: [UInt8]? = nil) -> [UInt8] {
        ready()
        var out = [UInt8](repeating: 0, count: 32)
        if let key {
            _ = crypto_generichash(&out, 32, message, UInt64(message.count), key, key.count)
        } else {
            _ = crypto_generichash(&out, 32, message, UInt64(message.count), nil, 0)
        }
        return out
    }

    /** BLAKE2b-256 of `prefix` then `secret`, kept as a secret: neither the input nor the hash passes through an array. */
    static func secretHash(prefix: [UInt8], _ secret: SecretKey) -> SecretKey {
        ready()
        return SecretKey(count: 32) { out in
            // libsodium's state wants 64-byte alignment, which a Swift value does not promise.
            let size = crypto_generichash_statebytes()
            let raw = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: 64)
            defer {
                sodium_memzero(raw, size)
                raw.deallocate()
            }
            let state = OpaquePointer(raw)
            _ = crypto_generichash_init(state, nil, 0, 32)
            _ = crypto_generichash_update(state, prefix, UInt64(prefix.count))
            secret.withUnsafeBytes { _ = crypto_generichash_update(state, $0.u8, UInt64($0.count)) }
            _ = crypto_generichash_final(state, out.u8, 32)
        }
    }

    /** BLAKE2b-256 of secret input, kept as a secret. */
    static func secretHash(_ message: [UInt8]) -> SecretKey {
        ready()
        return SecretKey(count: 32) { out in _ = crypto_generichash(out.u8, 32, message, UInt64(message.count), nil, 0) }
    }

    /** BLAKE2b-256 keyed with a secret, giving a secret: derived keys never pass through an array. */
    static func hash(_ message: [UInt8], key: SecretKey) -> SecretKey {
        ready()
        return SecretKey(count: 32) { out in
            key.withUnsafeBytes { k in
                _ = crypto_generichash(out.u8, 32, message, UInt64(message.count), k.u8, k.count)
            }
        }
    }

    /** A sealed box: an ephemeral key per call, so libsodium picks the nonce and no two repeat. */
    public static func seal(_ message: [UInt8], to recipient: [UInt8]) throws -> [UInt8] {
        ready()
        guard recipient.count == Int(crypto_box_PUBLICKEYBYTES) else { throw ProtocolError(.badKey, "recipient key is not 32 bytes") }
        var out = [UInt8](repeating: 0, count: message.count + crypto_box_sealbytes())
        guard crypto_box_seal(&out, message, UInt64(message.count), recipient) == 0 else {
            throw ProtocolError(.badKey, "recipient key refused")
        }
        return out
    }

    /** Nil when the box was not sealed to `keys` or was altered. */
    public static func sealOpen(_ sealed: [UInt8], keys: KeyPair) -> [UInt8]? {
        ready()
        let overhead = crypto_box_sealbytes()
        guard sealed.count >= overhead, keys.publicKey.count == Int(crypto_box_PUBLICKEYBYTES),
              keys.secretKey.count == Int(crypto_box_SECRETKEYBYTES) else { return nil }
        var out = [UInt8](repeating: 0, count: sealed.count - overhead)
        let rc = keys.secretKey.withUnsafeBytes { sk in
            crypto_box_seal_open(&out, sealed, UInt64(sealed.count), keys.publicKey, sk.u8)
        }
        return rc == 0 ? out : nil
    }

    public static func sign(_ message: [UInt8], secretKey: SecretKey) -> [UInt8] {
        ready()
        precondition(secretKey.count == Int(crypto_sign_SECRETKEYBYTES), "an Ed25519 secret key is 64 bytes")
        var sig = [UInt8](repeating: 0, count: Int(crypto_sign_BYTES))
        secretKey.withUnsafeBytes { sk in
            _ = crypto_sign_detached(&sig, nil, message, UInt64(message.count), sk.u8)
        }
        return sig
    }

    public static func verify(_ signature: [UInt8], _ message: [UInt8], publicKey: [UInt8]) -> Bool {
        ready()
        guard signature.count == Int(crypto_sign_BYTES), publicKey.count == Int(crypto_sign_PUBLICKEYBYTES) else { return false }
        return crypto_sign_verify_detached(signature, message, UInt64(message.count), publicKey) == 0
    }

    /** HMAC-SHA-512-256. */
    static func auth(_ message: [UInt8], key: SecretKey) -> [UInt8] {
        ready()
        precondition(key.count == Int(crypto_auth_KEYBYTES), "an auth key is 32 bytes")
        var tag = [UInt8](repeating: 0, count: Int(crypto_auth_BYTES))
        key.withUnsafeBytes { k in _ = crypto_auth(&tag, message, UInt64(message.count), k.u8) }
        return tag
    }

    /** Constant time, as crypto_auth_verify is. */
    static func authVerify(_ tag: [UInt8], _ message: [UInt8], key: SecretKey) -> Bool {
        ready()
        guard tag.count == Int(crypto_auth_BYTES), key.count == Int(crypto_auth_KEYBYTES) else { return false }
        return key.withUnsafeBytes { k in crypto_auth_verify(tag, message, UInt64(message.count), k.u8) == 0 }
    }

    static let secretboxKeyBytes = Int(crypto_secretbox_KEYBYTES)
    static let secretboxNonceBytes = Int(crypto_secretbox_NONCEBYTES)
    static let secretboxMacBytes = Int(crypto_secretbox_MACBYTES)

    /** XSalsa20-Poly1305 under a fresh random nonce, returned first. */
    static func secretbox(_ message: [UInt8], key: [UInt8]) -> [UInt8] {
        ready()
        precondition(key.count == secretboxKeyBytes)
        let nonce = randomBytes(secretboxNonceBytes)
        var out = [UInt8](repeating: 0, count: message.count + secretboxMacBytes)
        _ = crypto_secretbox_easy(&out, message, UInt64(message.count), nonce, key)
        return nonce + out
    }

    /** Nil when `key` does not open it or it was altered. */
    static func secretboxOpen(_ sealed: ArraySlice<UInt8>, nonce: ArraySlice<UInt8>, key: [UInt8]) -> [UInt8]? {
        ready()
        guard key.count == secretboxKeyBytes, nonce.count == secretboxNonceBytes, sealed.count >= secretboxMacBytes else { return nil }
        let c = Array(sealed), n = Array(nonce)
        var out = [UInt8](repeating: 0, count: c.count - secretboxMacBytes)
        return crypto_secretbox_open_easy(&out, c, UInt64(c.count), n, key) == 0 ? out : nil
    }
}

extension UnsafeMutableRawBufferPointer {
    /** The first byte of a non-empty buffer. */
    var u8: UnsafeMutablePointer<UInt8> { baseAddress!.assumingMemoryBound(to: UInt8.self) }
}

extension UnsafeRawBufferPointer {
    /** The first byte of a non-empty buffer. */
    var u8: UnsafePointer<UInt8> { baseAddress!.assumingMemoryBound(to: UInt8.self) }
}
