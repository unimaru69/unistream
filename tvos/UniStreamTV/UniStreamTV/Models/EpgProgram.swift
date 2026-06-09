import Foundation

/// EPG program entry for a live channel.
struct EpgProgram: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var start: Date?
    var end: Date?
    /// The raw server-local start string from the EPG `start` field.
    /// Used directly to build timeshift URLs (format: "YYYY-MM-DD HH:mm:ss").
    var serverLocalStart: String = ""

    /// Whether this program is currently airing.
    var isCurrent: Bool {
        guard let start, let end else { return false }
        let now = Date()
        return now >= start && now < end
    }

    /// Whether this program has already ended (eligible for catch-up replay).
    var isPast: Bool {
        guard let end else { return false }
        return Date() >= end
    }

    /// Duration in minutes.
    var durationMinutes: Int {
        guard let start, let end else { return 0 }
        return max(0, Int(end.timeIntervalSince(start) / 60))
    }

    /// Progress ratio (0.0–1.0) for current program.
    var progress: Double {
        guard let start, let end, isCurrent else { return 0 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return Date().timeIntervalSince(start) / total
    }

    init(json: [String: Any]) {
        // Title — may be base64 encoded
        let rawTitle = coerceString(json["title"])
        title = rawTitle.base64Decoded

        // Store raw server-local start for timeshift URL
        serverLocalStart = coerceString(json["start"])

        // Prefer epoch timestamps (reliable, no timezone ambiguity)
        if let startEpoch = Self.parseEpoch(json["start_timestamp"]),
           let stopEpoch = Self.parseEpoch(json["stop_timestamp"]) {
            start = Date(timeIntervalSince1970: startEpoch)
            end = Date(timeIntervalSince1970: stopEpoch)
        } else {
            // Fallback: parse date strings (server-local treated as UTC for display)
            start = Self.dateFormatter.date(from: coerceString(json["start"]))
            end = Self.dateFormatter.date(from: coerceString(json["end"]))
        }
    }

    // MARK: - Helpers

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static func parseEpoch(_ value: Any?) -> TimeInterval? {
        if let intVal = value as? Int { return TimeInterval(intVal) }
        if let strVal = value as? String, let intVal = Int(strVal) { return TimeInterval(intVal) }
        return nil
    }
}
