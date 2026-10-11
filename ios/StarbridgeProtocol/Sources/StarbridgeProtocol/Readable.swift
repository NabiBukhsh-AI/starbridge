/** A string that is not one of `known`: what a newer sender may send. */
private func newer(_ v: JSON?, _ known: Set<String>) -> Bool {
    guard let s = v?.string else { return false }
    return !known.contains(s)
}

private func withSource(_ body: JSONObject) -> JSONObject {
    guard var source = body["source"]?.object, newer(source["machineKind"], Set(MachineKind.allCases.map(\.rawValue))) else {
        return body
    }
    var b = body
    source["machineKind"] = nil
    b["source"] = .object(source)
    return b
}

/**
 * What a reader makes of a body before its schema checks it (PROTOCOL.md, "What a reader
 * keeps"): a string it only displays and does not know reads as the neutral case, and an alert of
 * a kind it does not know is left out. A missing field, or a value of another type, is left for
 * the schema to refuse. Writers check against the schemas alone.
 */
public func readable(_ kind: String, _ json: JSON) -> JSON {
    guard var body = json.object else { return json }
    switch kind {
    case "decision", "permission":
        return .object(withSource(body))
    case "settled":
        if newer(body["outcome"], SETTLED_OUTCOMES) { body["outcome"] = nil }
        return .object(body)
    case "waiting":
        if newer(body["state"], WAITING_STATES) { body["state"] = "working" }
        return .object(body)
    case "run":
        body = withSource(body)
        if newer(body["progress"]?.object?["unit"], RUN_UNITS) { body["progress"] = nil }
        return .object(body)
    case "quota":
        if let providers = body["providers"]?.array {
            body["providers"] = .array(providers.map { p in
                guard var po = p.object, let windows = po["windows"]?.array else { return p }
                po["windows"] = .array(windows.map { w in
                    guard var wo = w.object, var pace = wo["pace"]?.object, newer(pace["stage"], PACE_STAGES) else { return w }
                    pace["stage"] = "unknown"
                    wo["pace"] = .object(pace)
                    return .object(wo)
                })
                return .object(po)
            })
        }
        if let alerts = body["alerts"]?.array {
            body["alerts"] = .array(alerts.filter { !newer($0.object?["kind"], ALERT_KINDS) })
        }
        return .object(body)
    default:
        return json
    }
}
