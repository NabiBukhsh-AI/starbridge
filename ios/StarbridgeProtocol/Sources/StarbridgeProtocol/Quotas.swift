// packages/protocol/src/pace.ts and quotaAlerts.ts: a quota window's pace and alerts, and which
// alerts a device notifies about.

public enum Paces {
    /** Before this share of the window has passed, the rate is noise and the stage is "unknown". */
    public static let minElapsedFraction = 0.05
    /** How far from an even pace, in percentage points, still counts as on track. */
    public static let tolerance = 5.0

    public struct AlertRule: Sendable {
        /** Minutes before the reset an unused-headroom alert starts: for a day or less, and longer. */
        public var leadMinutesDay: Double = 60
        public var leadMinutesLonger: Double = 24 * 60
        /** Least headroom, in percent, worth an alert. */
        public var minUnusedPercent: Double = 30
        public var unusedHeadroom = true
        public var runsOut = true
        /** Percent left at or under which a "low" alert holds. */
        public var lowThresholds = [50, 20]

        public init() {}
    }

    /** JavaScript's Math.round(x * 10) / 10: halves round up. */
    static func round1(_ x: Double) -> Double { (x * 10 + 0.5).rounded(.down) / 10 }

    /**
     * Pace of one window at `now` (milliseconds since the epoch), assuming usage keeps its
     * average rate since the window began. Nil when the window's length or reset time is unknown.
     */
    public static func compute(usedPercent used: Double, windowMinutes: Int?, resetsAt: String?, now t: Int64) -> Pace? {
        guard let windowMinutes, let resetsAt, let reset = epochMillis(resetsAt) else { return nil }
        let length = Double(windowMinutes) * 60_000
        let remaining = min(max(Double(reset - t), 0), length)
        let elapsed = length - remaining
        let expected = elapsed / length * 100
        let delta = used - expected
        if used >= 100 {
            return Pace(stage: "ahead", expectedUsedPercent: round1(expected), deltaPercent: round1(delta),
                        projectedUsedPercent: round1(used), willLastToReset: false, runsOutAt: isoSeconds(t))
        }
        if elapsed < length * minElapsedFraction {
            return Pace(stage: "unknown", expectedUsedPercent: round1(expected), deltaPercent: round1(delta),
                        projectedUsedPercent: nil, willLastToReset: true, runsOutAt: nil)
        }
        let rate = used / elapsed
        let projected = used + rate * remaining
        let willLast = projected <= 100
        let stage = delta > tolerance ? "ahead" : delta < -tolerance ? "behind" : "on-track"
        return Pace(stage: stage, expectedUsedPercent: round1(expected), deltaPercent: round1(delta),
                    projectedUsedPercent: round1(projected), willLastToReset: willLast,
                    runsOutAt: willLast ? nil : isoSeconds(Int64((Double(t) + (100 - used) / rate).rounded(.down))))
    }

    /**
     * Alerts for one window: it will run out before its reset, it resets soon with headroom left
     * unused, or it has at most a threshold left (only the lowest threshold reached).
     */
    public static func alerts(provider: String, window w: QuotaWindow, now: Int64, rule: AlertRule = AlertRule()) -> [QuotaAlert] {
        // A window whose reset passed belongs to a cycle that ended; the next upload brings the new one.
        guard let resetsAt = w.resetsAt, let reset = epochMillis(resetsAt), reset > now else { return [] }
        var alerts: [QuotaAlert] = []
        let left = 100 - min(100, w.usedPercent)
        if let threshold = rule.lowThresholds.filter({ left <= Double($0) }).min() {
            alerts.append(QuotaAlert(kind: .low(threshold: threshold), provider: provider, window: w.id, resetsAt: resetsAt))
        }
        guard let pace = w.pace, let windowMinutes = w.windowMinutes else { return alerts }
        if rule.runsOut, let runsOutAt = pace.runsOutAt, let out = epochMillis(runsOutAt), out < reset {
            alerts.append(QuotaAlert(kind: .runsOut(runsOutAt: runsOutAt), provider: provider, window: w.id, resetsAt: resetsAt))
        }
        let remaining = Double(reset - now)
        let unused = round1(100 - min(100, pace.projectedUsedPercent ?? w.usedPercent))
        let lead = windowMinutes <= 24 * 60 ? rule.leadMinutesDay : rule.leadMinutesLonger
        if rule.unusedHeadroom, remaining > 0, remaining <= lead * 60_000, unused >= rule.minUnusedPercent {
            alerts.append(QuotaAlert(kind: .unusedHeadroom(unusedPercent: unused), provider: provider, window: w.id, resetsAt: resetsAt))
        }
        return alerts
    }
}

/** What a device notifies about, per window (#914); the settings stay on the device. */
public struct QuotaAlertSettings: Equatable, Sendable {
    public static let choices = ["runs-out", "low-50", "low-20", "unused-headroom"]

    /** Windows of a day or less. */
    public var short: [String]
    /** Longer windows, and those of unknown length. */
    public var long: [String]
    /**
     * A window's own choices, by `provider/window`, where an empty list is off. A key with no
     * window covers every window of its provider that has no key of its own.
     */
    public var windows: [String: [String]]

    public init(short: [String] = [], long: [String] = ["runs-out"], windows: [String: [String]] = [:]) {
        self.short = short
        self.long = long
        self.windows = windows
    }

    /** A 5-hour window that runs out resets within hours; a weekly one costs days. */
    public static let defaults = QuotaAlertSettings()

    public static func windowKey(provider: String, window: String) -> String { "\(provider)/\(window)" }

    /** A window of a day or less. */
    public static func isShort(_ minutes: Int?) -> Bool { minutes.map { $0 <= 24 * 60 } ?? false }

    /** What a window notifies about: its own choices, else its provider's, else its length's. */
    public func choices(provider: String, window: String, minutes: Int?) -> [String] {
        windows[Self.windowKey(provider: provider, window: window)] ?? windows[provider] ?? (Self.isShort(minutes) ? short : long)
    }

    /**
     * Whether an alert notifies. Only the lowest level reached is raised, so a window that skips
     * past a level picked still notifies at the next one down.
     */
    public func wants(provider: String, window: String, kind: String, threshold: Int?, minutes: Int?) -> Bool {
        let picked = choices(provider: provider, window: window, minutes: minutes)
        if kind != "low" { return picked.contains(kind) }
        let t = threshold ?? 0
        return picked.contains { $0.hasPrefix("low-") && Int($0.dropFirst(4)).map { $0 >= t } == true }
    }

    /**
     * Settings from before #914: a bell per provider, and two switches for every provider whose
     * bell was on. Each provider with its bell on keeps what the switches let through.
     */
    public static func migrate(notify: [String], notifyLow: Bool = true, notifyPace: Bool = true) -> QuotaAlertSettings {
        let kept = (notifyPace ? ["runs-out"] : []) + (notifyLow ? ["low-50", "low-20"] : []) + (notifyPace ? ["unused-headroom"] : [])
        return QuotaAlertSettings(windows: Dictionary(notify.map { ($0, kept) }, uniquingKeysWith: { _, b in b }))
    }
}
