import Foundation
import StarbridgeProtocol

/** A response the server refused: its status and `{error, detail}` (PROTOCOL.md, "Server API"). */
struct ApiError: Error, CustomStringConvertible {
    let status: Int
    let error: String?
    let detail: String?

    var description: String { [error ?? "HTTP \(status)", detail].compactMap(\.self).joined(separator: ": ") }
}

struct Me: Equatable {
    let account: String
    let member: String?
}

/** A join by digits as the server holds it (PROTOCOL.md, "Joins"). */
struct JoinView {
    let state: String
    let version: Int
    let approverKey: String?
    let joinerKey: String?
    let approval: JSON?
}

/** The server's /v1 routes this app calls so far. */
struct Api {
    let server: String
    let session: String?
    var http: URLSession = .shared

    /** This release, as the server counts it and checks it against its minimum (PROTOCOL.md, "HTTP API"). */
    static let client = "ios/" + (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0")

    private func call(_ method: String, _ path: String, _ body: JSON? = nil, headers: [String: String] = [:], wait: Int? = nil) async throws -> (Int, JSON?) {
        guard let url = URL(string: server + "/v1" + path) else { throw ApiError(status: 0, error: "bad-server", detail: server) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        // A long-poll holds up to `wait` seconds before it answers.
        request.timeoutInterval = TimeInterval((wait ?? 0) + 30)
        if let session { request.setValue("Bearer \(session)", forHTTPHeaderField: "Authorization") }
        request.setValue(Api.client, forHTTPHeaderField: "starbridge-client")
        for (k, v) in headers { request.setValue(v, forHTTPHeaderField: k) }
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data(body.text.utf8)
        }
        let (data, response) = try await http.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let json = data.isEmpty ? nil : try? JSON.parse(String(decoding: data, as: UTF8.self))
        guard (200..<300).contains(status) else {
            throw ApiError(status: status, error: json?["error"]?.string, detail: json?["detail"]?.string)
        }
        return (status, json)
    }

    private func field(_ json: JSON?, _ key: String) throws -> JSON {
        guard let value = json?[key] else { throw ProtocolError(.badSchema, "a reply without \(key)") }
        return value
    }

    private func string(_ json: JSON?, _ key: String) throws -> String {
        guard let s = try field(json, key).string else { throw ProtocolError(.badSchema, "\(key) is not a string") }
        return s
    }

    // --- Auth ------------------------------------------------------------------

    func appSession(code: String, verifier: String) async throws -> String {
        try string(await call("POST", "/auth/app/session", ["code": .string(code), "verifier": .string(verifier)]).1, "session")
    }

    func ownerSignIn(token: String) async throws -> String {
        try string(await call("POST", "/auth/owner", ["token": .string(token)]).1, "session")
    }

    func me() async throws -> Me {
        let body = try await call("GET", "/me").1
        return Me(account: try string(body, "account"), member: body?["member"]?.string)
    }

    /** A single-use nonce to sign for [bind]. */
    func challenge() async throws -> String { try string(await call("GET", "/auth/challenge").1, "nonce") }

    /** Binds this session to an existing device that signed the challenge with its key. */
    func bind(member: String, sig: String) async throws {
        _ = try await call("POST", "/auth/bind", ["member": .string(member), "sig": .string(sig)])
    }

    func logout() async throws { _ = try await call("POST", "/auth/logout") }

    // --- Directory -------------------------------------------------------------

    func directory(from: Int) async throws -> [JSON] {
        guard let entries = try field(await call("GET", "/directory?from=\(from)").1, "entries").array else {
            throw ProtocolError(.badSchema, "entries is not a list")
        }
        return entries
    }

    func append(_ entry: SignedEnvelope) async throws { _ = try await call("POST", "/directory", ["entry": entry.json]) }

    // --- Joining by code -------------------------------------------------------

    func postPairing(_ request: PairingMessage, claimHash: String) async throws {
        _ = try await call("POST", "/pairings", ["request": request.json, "claimHash": .string(claimHash)])
    }

    /** The approval once a device approved this one; nil when `wait` seconds pass first. */
    func pairingResult(rendezvous: String, claim: String, wait: Int) async throws -> JSON? {
        let (status, body) = try await call("GET", "/pairings/\(rendezvous)/result?wait=\(wait)", headers: ["X-Claim": claim], wait: wait)
        if status == 204 { return nil }
        // A reply without one is the server's fault, never the end of the app (#274).
        return try field(body, "approval")
    }

    // --- Joining by digits -----------------------------------------------------

    private func join(_ body: JSON?) throws -> JoinView {
        let j = try field(body, "join")
        guard let state = j["state"]?.string, let version = j["version"]?.number else {
            throw ProtocolError(.badSchema, "a join without its state")
        }
        return JoinView(state: state, version: Int(version), approverKey: j["approverKey"]?.string, joinerKey: j["joinerKey"]?.string, approval: j["approval"].flatMap { $0.isNull ? nil : $0 })
    }

    func postJoin(request: String, commitment: String) async throws -> JoinView {
        try join(await call("POST", "/joins", ["request": .string(request), "commitment": .string(commitment)]).1)
    }

    /** The join; with `wait`, holds until its version passes `after`. */
    func join(id: String, after: Int, wait: Int) async throws -> JoinView {
        try join(await call("GET", "/joins/\(id)?after=\(after)&wait=\(wait)", wait: wait).1)
    }

    func revealJoin(id: String, key: String) async throws { _ = try await call("POST", "/joins/\(id)/reveal", ["key": .string(key)]) }

    func cancelJoin(id: String) async throws { _ = try await call("DELETE", "/joins/\(id)") }
}
