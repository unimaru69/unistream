import Foundation
import CryptoKit
import os

/// On-disk cache for TMDB enrichment results. Entries expire after 30 days
/// (positive hits) or 7 days (negative hits — so we retry on a title that
/// may have appeared on TMDB in the meantime).
///
/// Parity with the Flutter `tmdbLookupProvider` caching layer.
///
/// ## Why this is file-backed and not in UserDefaults
/// The previous implementation stored one `UserDefaults.standard` key per
/// `(kind, title, year)` and **never deleted** entries (expired ones were
/// merely ignored on read). Browsing the catalogue enriches every visible
/// card via TMDB, so the standard preferences domain grew without bound.
/// `CFPreferences` enforces a hard size limit on a domain (~4 MB on tvOS);
/// once exceeded, the *next* write to that domain aborts the process —
/// `__CFPREFERENCES_HAS_DETECTED_THIS_APP_TRYING_TO_STORE_TOO_MUCH_DATA…`
/// → SIGABRT. That was the "app quits back to the tvOS home menu" crash
/// (Sentry issue, build 73): it fired while browsing grids *and* when
/// launching a channel (any later `defaults.set` tipped the oversized
/// domain over), which is why it looked like three unrelated bugs.
///
/// A cache belongs on disk, not in preferences. Each entry is a small JSON
/// file under `Caches/tmdb-cache/`. The OS may evict the Caches directory
/// under storage pressure — fine, it's a cache; a miss just re-fetches.
///
/// `@unchecked Sendable`: writes are atomic file replacements and reads are
/// independent, so concurrent access from async TMDB lookups is safe (a
/// torn read simply fails to decode and is treated as a miss).
final class TMDBCache: @unchecked Sendable {
    static let shared = TMDBCache()

    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "TMDBCache")
    private let ttlPositive: TimeInterval = 60 * 60 * 24 * 30
    private let ttlNegative: TimeInterval = 60 * 60 * 24 * 7
    private let directory: URL

    private init() {
        let caches = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        directory = caches.appendingPathComponent("tmdb-cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Self.purgeLegacyUserDefaults(logger: logger)
    }

    struct Entry {
        let result: TMDBResult?
        let negative: Bool
    }

    /// On-disk record. Replaces the old "dict with `_savedAt`/`_negative`
    /// sentinel keys" shape with a typed wrapper.
    private struct StoredEntry: Codable {
        let savedAt: TimeInterval
        let negative: Bool
        let result: TMDBResult?
    }

    func get(kind: TMDBKind, title: String, year: Int?) -> Entry? {
        let url = fileURL(kind: kind, title: title, year: year)
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode(StoredEntry.self, from: data)
        else { return nil }

        let age = Date().timeIntervalSince1970 - stored.savedAt
        if stored.negative {
            guard age < ttlNegative else { return nil }
            return Entry(result: nil, negative: true)
        }
        guard age < ttlPositive, let result = stored.result else { return nil }
        return Entry(result: result, negative: false)
    }

    func put(_ result: TMDBResult, title: String, year: Int?) {
        write(
            StoredEntry(savedAt: Date().timeIntervalSince1970, negative: false, result: result),
            to: fileURL(kind: result.kind, title: title, year: year)
        )
    }

    func putNegative(kind: TMDBKind, title: String, year: Int?) {
        write(
            StoredEntry(savedAt: Date().timeIntervalSince1970, negative: true, result: nil),
            to: fileURL(kind: kind, title: title, year: year)
        )
    }

    // MARK: - Storage

    private func write(_ entry: StoredEntry, to url: URL) {
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// Stable cache key (kept identical to the old scheme for readability)
    /// hashed into a filesystem-safe filename.
    private func fileURL(kind: TMDBKind, title: String, year: Int?) -> URL {
        let normalized = title.lowercased().replacingOccurrences(of: " ", with: "_")
        let key = "tmdb.cache.\(kind.rawValue).\(normalized).\(year.map(String.init) ?? "na")"
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent("\(name).json")
    }

    /// One-shot cleanup: remove the legacy `tmdb.cache.*` keys the old
    /// implementation left in `UserDefaults.standard`. Without this, devices
    /// that already crashed stay crashed — the preferences domain remains
    /// oversized and the next unrelated `defaults.set` aborts again. Cheap:
    /// after the first launch there are no matching keys, so it no-ops.
    private static func purgeLegacyUserDefaults(logger: Logger) {
        let defaults = UserDefaults.standard
        let legacyKeys = defaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("tmdb.cache.") }
        guard !legacyKeys.isEmpty else { return }
        for key in legacyKeys { defaults.removeObject(forKey: key) }
        logger.info("Purged \(legacyKeys.count) legacy tmdb.cache.* keys from UserDefaults")
    }
}
