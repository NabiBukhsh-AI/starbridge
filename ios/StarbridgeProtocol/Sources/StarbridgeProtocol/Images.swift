// packages/protocol/src/images.ts. A decision's image travels apart from its boxes, sealed once
// for every device: the blob is the image under a random key (XSalsa20-Poly1305, the nonce
// first), and the signed body carries the key and the blob's hash.

/** An image as clients show it, once its blob opened. */
public struct ShownImage: Equatable, Sendable {
    public let type: String
    public let width: Int
    public let height: Int
    public let alt: String?
    public let data: [UInt8]
}

public enum Images {
    private static func blobHash(_ blob: [UInt8]) -> [UInt8] { Sodium.hash(label("image") + blob) }

    /** Encrypts an image's bytes under a fresh key and nonce: the blob to post, and the ref to sign. */
    public static func seal(_ bytes: [UInt8]) -> (blob: String, ref: ImageRef) {
        var key = Sodium.randomBytes(Sodium.secretboxKeyBytes)
        defer { wipe(&key) }
        let blob = Sodium.secretbox(bytes, key: key)
        return (toB64(blob), ImageRef(key: toB64(key), hash: toB64(blobHash(blob))))
    }

    /** The image's bytes, once the blob matches the signed hash and opens under the signed key. */
    public static func open(_ blob: String, ref: ImageRef) throws -> [UInt8] {
        let bytes: [UInt8]
        do {
            bytes = try fromB64(blob)
        } catch {
            throw ProtocolError(.cannotOpen, "image blob is not base64url")
        }
        guard let hash = try? fromB64(ref.hash), constantTimeEqual(blobHash(bytes), hash) else {
            throw ProtocolError(.cannotOpen, "image hash differs")
        }
        let n = Sodium.secretboxNonceBytes
        if bytes.count < n + Sodium.secretboxMacBytes { throw ProtocolError(.cannotOpen, "image blob too short") }
        guard var key = try? fromB64(ref.key) else { throw ProtocolError(.cannotOpen, "image does not open") }
        defer { wipe(&key) }
        guard let plain = Sodium.secretboxOpen(bytes[n...], nonce: bytes[..<n], key: key) else {
            throw ProtocolError(.cannotOpen, "image does not open")
        }
        return plain
    }

    /**
     * A decision's images that open from the item's blobs, in order. One whose blob is missing (a
     * push carries none) or fails to open is left out, as a client leaves out a broken image.
     */
    public static func open(_ item: SealedItem, images: [DecisionImage]?) -> [ShownImage] {
        (images ?? []).enumerated().compactMap { i, image in
            guard let blobs = item.blobs, blobs.indices.contains(i), let data = try? open(blobs[i], ref: image.ref) else { return nil }
            return ShownImage(type: image.type, width: image.width, height: image.height, alt: image.alt, data: data)
        }
    }
}
