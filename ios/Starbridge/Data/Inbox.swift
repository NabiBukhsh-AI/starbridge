import Foundation
import StarbridgeProtocol

/** A body kept as its signed text, parsed once when read back. */
private func body<T: ItemBody>(_ kind: String, _ text: String) throws -> T {
    guard let b = try parseBody(kind, text).item as? T else { throw ProtocolError(.wrongKind, kind) }
    return b
}

/** A machine's question as this iPhone keeps it, with what became of it. */
struct SavedDecision: Codable, Equatable {
    let from: String
    let text: String
    var answeredAt: String?
    /** This iPhone's answer, once the server took it. */
    var answer: String?
    /** Another device's answer, as the asking machine's settled notice named it (#330). */
    var theirAnswer: String?
    var answeredBy: String?
    /** How a settled notice closed it, and the agent's reason for a withdrawal (#1008). */
    var settled: String?
    var reason: String?
    var waiting: String?
    var waitingAt: String?
    var snoozedUntil: String?
    var snoozedAt: String?
    let body: Decision

    enum CodingKeys: String, CodingKey {
        case from, text, answeredAt, answer, theirAnswer, answeredBy, settled, reason, waiting, waitingAt, snoozedUntil, snoozedAt
    }

    init(from: String, text: String, answeredAt: String?) throws {
        self.from = from
        self.text = text
        self.answeredAt = answeredAt
        body = try Starbridge.body("decision", text)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        from = try c.decode(String.self, forKey: .from)
        text = try c.decode(String.self, forKey: .text)
        answeredAt = try c.decodeIfPresent(String.self, forKey: .answeredAt)
        answer = try c.decodeIfPresent(String.self, forKey: .answer)
        theirAnswer = try c.decodeIfPresent(String.self, forKey: .theirAnswer)
        answeredBy = try c.decodeIfPresent(String.self, forKey: .answeredBy)
        settled = try c.decodeIfPresent(String.self, forKey: .settled)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        waiting = try c.decodeIfPresent(String.self, forKey: .waiting)
        waitingAt = try c.decodeIfPresent(String.self, forKey: .waitingAt)
        snoozedUntil = try c.decodeIfPresent(String.self, forKey: .snoozedUntil)
        snoozedAt = try c.decodeIfPresent(String.self, forKey: .snoozedAt)
        body = try Starbridge.body("decision", text)
    }

    var id: String { body.id }
    var isOpen: Bool { answeredAt == nil && answer == nil }

    /** Until when the owner put it off; none after Back now, whose time is its own (#571). */
    var snoozed: Date? {
        guard isOpen, let until = snoozedUntil.flatMap(Dates.parse) else { return nil }
        if let at = snoozedAt.flatMap(Dates.parse), until <= at { return nil }
        return until > Date() ? until : nil
    }
}

/** A machine's permission prompt as this iPhone keeps it. */
struct SavedPrompt: Codable, Equatable {
    let from: String
    let text: String
    var answeredAt: String?
    /** This iPhone's answer: `allow:<scope>` or `deny`. */
    var answer: String?
    let body: Permission

    enum CodingKeys: String, CodingKey { case from, text, answeredAt, answer }

    init(from: String, text: String, answeredAt: String?) throws {
        self.from = from
        self.text = text
        self.answeredAt = answeredAt
        body = try Starbridge.body("permission", text)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        from = try c.decode(String.self, forKey: .from)
        text = try c.decode(String.self, forKey: .text)
        answeredAt = try c.decodeIfPresent(String.self, forKey: .answeredAt)
        answer = try c.decodeIfPresent(String.self, forKey: .answer)
        body = try Starbridge.body("permission", text)
    }

    var id: String { body.id }

    /** Still answerable here: unanswered, and inside its answer window. */
    var isOpen: Bool {
        answeredAt == nil && answer == nil && (Dates.parse(body.expiresAt).map { $0 > Date() } ?? false)
    }
}

/** One update of a `starbridge run`, the latest this iPhone has. */
struct SavedRun: Codable, Equatable {
    let from: String
    let text: String
    let body: Run

    enum CodingKeys: String, CodingKey { case from, text }

    init(from: String, text: String) throws {
        self.from = from
        self.text = text
        body = try Starbridge.body("run", text)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        from = try c.decode(String.self, forKey: .from)
        text = try c.decode(String.self, forKey: .text)
        body = try Starbridge.body("run", text)
    }

    var id: String { body.id }

    /** When its machine last said anything about it. */
    var lastNews: Date { Dates.parse(body.at) ?? .distantPast }

    /** Running with no update for RUN_STALE_MS: its machine is gone. */
    var lost: Bool { body.exit == nil && Date().timeIntervalSince(lastNews) * 1000 > Double(RUN_STALE_MS) }
}

/**
 * An answer signed and sealed, kept until the server takes it (#329): tapped offline, it goes
 * once the server can be reached. `mayHaveLanded` once a try may have reached the server, so a
 * later `already-answered` is taken as this answer's.
 */
struct QueuedAnswer: Codable, Equatable {
    let decisionId: String
    /** What the owner chose or typed, as the card shows it. */
    let answer: String
    /** The sealed item's JSON text. */
    let item: String
    let at: String
    var mayHaveLanded = false
}

/** The directory head a machine signed into its items (#362), as JSON text. */
struct SavedHead: Codable, Equatable {
    let id: String
    let head: String
}

enum Dates {
    static func parse(_ text: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        if let d = f.date(from: text) { return d }
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.date(from: text)
    }

    static func format(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
