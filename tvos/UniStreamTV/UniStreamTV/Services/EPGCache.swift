import Foundation
import os

/// Day-keyed in-memory cache for EPG data, owned by `AppState` so it
/// survives navigation in and out of the EPG grid. Without it the
/// grid re-fetched the entire payload on every entry — a noticeable
/// 1-3 s delay on a 50-channel slice.
///
/// Keyed by:
///   * `dayKey`  → ISO calendar day string (`yyyy-MM-dd`)
///   * `streamId` → the channel's bare id
///
/// Fetch strategy:
///   * **Today** — uses `getShortEpg` (~30 entries per channel,
///     covers ~12 h of programming, lighter on the network).
///   * **Other days** — uses `getFullDayEpg` (the entire 24 h block
///     for that day). Heavier but unavoidable for catch-up replay
///     and "what's on tomorrow night?".
@MainActor @Observable
final class EPGCache {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "EPGCache")

    /// `[dayKey: [streamId: [EpgProgram]]]`
    private(set) var byDay: [String: [String: [EpgProgram]]] = [:]

    /// Days that have at least one channel currently being fetched.
    /// Drives the spinner in the EPG header.
    private(set) var loadingDays: Set<String> = []
    /// Per-day load progress for the user: `(loaded, total)`.
    private(set) var loadProgress: [String: (Int, Int)] = [:]
    /// Per-day in-flight channel set. A second `loadDay` call (for
    /// example when the user switches category mid-fetch) skips
    /// channels that are already in here — but doesn't bail out
    /// globally, so the new category's channels still get queued.
    private var inFlightChannels: [String: Set<String>] = [:]

    /// Refresh threshold for the *current* day — past/future days
    /// don't change so we cache them indefinitely within the session.
    private static let todayRefreshInterval: TimeInterval = 5 * 60
    private var lastTodayFetch: Date?

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone.current
        return f
    }()

    static func dayKey(for date: Date) -> String {
        dayKeyFormatter.string(from: date)
    }

    /// Cached programmes for a given (channel, day). Returns nil when
    /// nothing is cached yet — caller should either show a spinner
    /// or call `loadDay` first.
    func programs(for streamId: String, day: Date) -> [EpgProgram]? {
        byDay[Self.dayKey(for: day)]?[streamId]
    }

    /// Whether we already have something cached for the requested
    /// (day, channel) pair. Used by the grid to know if a spinner is
    /// needed before the channel's row can render.
    func hasData(for streamId: String, day: Date) -> Bool {
        programs(for: streamId, day: day) != nil
    }

    /// Force-bypass the cache for the next `loadDay` call — used by
    /// pull-to-refresh / explicit "Actualiser" buttons (none yet, but
    /// the hook is here for later).
    func invalidateToday() {
        lastTodayFetch = nil
        byDay[Self.dayKey(for: Date())] = nil
    }

    /// Fetch programmes for every channel in the requested set on the
    /// requested day. Idempotent: skips channels that are already
    /// cached for the day, plus channels whose cache is younger than
    /// `todayRefreshInterval` for "today".
    func loadDay(
        _ day: Date,
        channels: [Channel],
        api: XtreamAPIService
    ) async {
        let key = Self.dayKey(for: day)
        let isToday = Calendar.current.isDateInToday(day)

        // Snapshot for filtering — but we never mutate a *local copy*
        // of `byDay[key]` and write it back in one shot. That's what
        // caused the race in the previous version: two concurrent
        // `loadDay` calls (e.g. category switch mid-fetch) each held
        // their own local dictionary, then alternated writes to the
        // observable, clobbering each other's channel data.
        let snapshotMap = byDay[key] ?? [:]
        let inFlight = inFlightChannels[key] ?? []
        let toFetch = channels.filter {
            snapshotMap[$0.streamId] == nil && !inFlight.contains($0.streamId)
        }
        guard !toFetch.isEmpty else {
            logger.debug("EPGCache: \(key) already cached/in-flight for all \(channels.count) requested channels")
            return
        }

        // Reserve our slice of channels so concurrent callers don't
        // duplicate the fetch.
        var reservation = inFlight
        for ch in toFetch { reservation.insert(ch.streamId) }
        inFlightChannels[key] = reservation
        loadingDays.insert(key)
        let prevTotal = loadProgress[key]?.1 ?? 0
        let prevLoaded = loadProgress[key]?.0 ?? 0
        loadProgress[key] = (prevLoaded, prevTotal + toFetch.count)

        logger.info("EPGCache: loading \(toFetch.count) channels for \(key) (\(isToday ? "today/short" : "full-day"))")

        let batchSize = 6
        for batchStart in stride(from: 0, to: toFetch.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, toFetch.count)
            let batch = Array(toFetch[batchStart..<batchEnd])

            await withTaskGroup(of: (String, [EpgProgram]).self) { group in
                for channel in batch {
                    group.addTask {
                        do {
                            let progs = isToday
                                ? try await api.getShortEpg(streamId: channel.streamId, limit: 30)
                                : try await api.getFullDayEpg(streamId: channel.streamId)
                            return (channel.streamId, progs)
                        } catch {
                            return (channel.streamId, [])
                        }
                    }
                }
                for await (sid, progs) in group {
                    // Read the *latest* dayMap right before merging so
                    // we never overwrite another in-flight loader's
                    // contributions. Single-key writes keep
                    // @Observable consumers updating per channel.
                    var latest = byDay[key] ?? [:]
                    latest[sid] = progs
                    byDay[key] = latest

                    var current = inFlightChannels[key] ?? []
                    current.remove(sid)
                    inFlightChannels[key] = current
                    let cur = loadProgress[key] ?? (0, 0)
                    loadProgress[key] = (cur.0 + 1, cur.1)
                }
            }
        }

        if (inFlightChannels[key]?.isEmpty ?? true) {
            loadingDays.remove(key)
            loadProgress[key] = nil
            inFlightChannels[key] = nil
        }
        if isToday { lastTodayFetch = Date() }
        let cachedCount = self.byDay[key]?.count ?? 0
        logger.info("EPGCache: \(key) cached for \(cachedCount) channels")
    }
}
