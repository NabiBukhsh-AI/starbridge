// packages/protocol/src/envelope.ts: sign, then seal; open, then verify, then parse.

public struct Opened: Sendable {
    public let signer: Member
    public let body: any ItemBody
    /** The body's JSON text exactly as signed. */
    public let bodyText: String
}

public enum Envelopes {
    /**
     * The bytes an Ed25519 signature covers: "starbridge/v1/<kind>", NUL, signer id, NUL, body.
     * The kind keeps a signature for one kind of message from passing as another; the signer id
     * binds the envelope's signer field.
     */
    public static func signatureMessage(kind: String, signer: String, body: String) -> [UInt8] {
        concat(label(kind), utf8(signer), [0], utf8(body))
    }

    /** Signs `body`, whose JSON text is kept exactly as it will be sent. */
    public static func sign(kind: String, body: JSON, signer: String, secretKey: SecretKey) -> SignedEnvelope {
        let text = body.text
        let sig = Sodium.sign(signatureMessage(kind: kind, signer: signer, body: text), secretKey: secretKey)
        return SignedEnvelope(kind: kind, signer: signer, body: text, sig: toB64(sig))
    }

    /** Throws `bad-signature` unless `signPk` signed this envelope. */
    public static func verify(_ env: SignedEnvelope, signPk: String) throws {
        let ok = (try? Sodium.verify(fromB64(env.sig), signatureMessage(kind: env.kind, signer: env.signer, body: env.body), publicKey: fromB64(signPk))) ?? false
        if !ok { throw ProtocolError(.badSignature, "signer \(env.signer)") }
    }

    /**
     * Signs `body` and seals the signed envelope to each recipient (sign, then seal). The body
     * must pass its kind's schema and its `to` must name exactly the recipients, so a recipient
     * cannot re-seal it to someone else unnoticed. Throws `UsageError` when either fails.
     */
    public static func seal(kind: ItemKind, body: JSON, signer: String, secretKey: SecretKey, recipients: [Member]) throws -> SealedItem {
        guard let parsed = (try? parseStrict(kind.rawValue, body))?.item else {
            throw UsageError("the body does not pass the \(kind.rawValue) schema")
        }
        let named = parsed.recipients
        let ids = recipients.map(\.id)
        guard named.count == ids.count, ids.allSatisfy(named.contains) else {
            throw UsageError("body.to must list exactly the recipients")
        }
        let env = sign(kind: kind.rawValue, body: body, signer: signer, secretKey: secretKey)
        let plain = utf8(env.json.text)
        let boxes = try recipients.map { SealedBox(to: $0.id, box: toB64(try Sodium.seal(plain, to: fromB64($0.boxPk)))) }
        return SealedItem(kind: kind, id: parsed.id, from: signer, re: parsed.re, wakeAt: parsed.wakeAt, blobs: nil, boxes: boxes)
    }

    /** Opens this member's box. The envelope inside is not verified yet. */
    public static func openBox(_ item: SealedItem, me: String, keys: KeyPair) throws -> SignedEnvelope {
        guard let mine = item.boxes.first(where: { $0.to == me }) else {
            throw ProtocolError(.wrongRecipient, "no box for \(me)")
        }
        // A box that does not decode is one that does not open, as in packages/protocol.
        guard let sealed = try? fromB64(mine.box), let plain = Sodium.sealOpen(sealed, keys: keys) else {
            throw ProtocolError(.cannotOpen)
        }
        var text = String(decoding: plain, as: UTF8.self)
        // TextDecoder's fatal mode: bytes that are not UTF-8 refuse, where String would replace them.
        guard Array(text.utf8) == plain else { throw ProtocolError(.badSchema, "sealed content is not UTF-8") }
        // TextDecoder drops a leading byte order mark; JSON.parse would refuse it.
        if text.unicodeScalars.first == "\u{FEFF}" { text.unicodeScalars.removeFirst() }
        let json: JSON
        do {
            json = try JSON.parse(text)
        } catch {
            throw ProtocolError(.badSchema, "sealed content is not JSON")
        }
        let env = try SignedEnvelope(json: json)
        if env.kind != item.kind.rawValue { throw ProtocolError(.wrongKind, "\(env.kind) in \(item.kind.rawValue)") }
        return env
    }

    /**
     * Opens, verifies and parses an item for `me`. The signer must be an active member of the
     * verified directory with the role allowed for this kind, and the signed body must match the
     * item's id and name `me` as a recipient.
     */
    public static func open(_ item: SealedItem, me: String, keys: KeyPair, directory: Directory) throws -> Opened {
        let env = try openBox(item, me: me, keys: keys)
        if env.signer != item.from { throw ProtocolError(.idMismatch, "from is not the signer") }
        guard let entry = directory.members[env.signer] else { throw ProtocolError(.unknownSigner, env.signer) }
        if !entry.active { throw ProtocolError(.revokedSigner, env.signer) }
        if entry.member.role != item.kind.signer {
            throw ProtocolError(.signerNotAllowed, "\(entry.member.role.rawValue) cannot sign \(item.kind.rawValue)")
        }
        try verify(env, signPk: entry.member.signPk)
        guard let body = try parseBody(item.kind.rawValue, env.body).item else { throw ProtocolError(.wrongKind) }
        if body.id != item.id { throw ProtocolError(.idMismatch, "body id is not the item id") }
        if item.re != body.re { throw ProtocolError(.idMismatch, "re is not the item the body refers to") }
        if item.wakeAt != body.wakeAt { throw ProtocolError(.idMismatch, "wakeAt is not the time the body names") }
        if !body.recipients.contains(me) { throw ProtocolError(.wrongRecipient, "body does not name me") }
        return Opened(signer: entry.member, body: body, bodyText: env.body)
    }
}
