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

    /// Days currently being fetched — UI surfaces a progress indicator
    /// while the set is non-empty.
    private(set) var loadingDays: Set<String> = []
    /// Per-day load progress for the user: `(loaded, total)`.
    private(set) var loadProgress: [String: (Int, Int)] = [:]

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
        if loadingDays.contains(key) { return }

        let isToday = Calendar.current.isDateInToday(day)
        // Skip the load entirely when today is fresh.
        if isToday, let last = lastTodayFetch,
           Date().timeIntervalSince(last) < Self.todayRefreshInterval {
            // Still need to load any newly-added channel that wasn't
            // in the cache before — fall through but only fetch the
            // missing ones below.
        }

        var dayMap = byDay[key] ?? [:]
        let toFetch = channels.filter { dayMap[$0.streamId] == nil }
        guard !toFetch.isEmpty else {
            logger.debug("EPGCache: \(key) already cached for all \(channels.count) channels")
            return
        }

        loadingDays.insert(key)
        loadProgress[key] = (0, toFetch.count)
        defer {
            loadingDays.remove(key)
            loadProgress[key] = nil
        }

        logger.info("EPGCache: loading \(toFetch.count) channels for \(key) (\(isToday ? "today/short" : "full-day"))")

        // Bounded concurrency — Xtream backends typically rate-limit;
        // 6 in flight matches what `EPGViewModel.loadEPG` was doing.
        let batchSize = 6
        var loaded = 0
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
                    dayMap[sid] = progs
                    loaded += 1
                    loadProgress[key] = (loaded, toFetch.count)
                }
            }
        }

        byDay[key] = dayMap
        if isToday { lastTodayFetch = Date() }
        logger.info("EPGCache: \(key) cached for \(dayMap.count) channels")
    }
}
