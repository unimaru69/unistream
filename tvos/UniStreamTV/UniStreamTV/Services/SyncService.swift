import Foundation
import Supabase
import os

/// Cloud sync service — mirrors Flutter's `sync_service.dart`.
/// Syncs favorites, watch progress, and collections to Supabase.
@MainActor @Observable
final class SyncService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Sync")
    private let client = SupabaseConfig.client

    // Local state
    private(set) var favorites: [String: FavoriteItem] = [:]  // key → item
    private(set) var watchProgress: [String: WatchEntry] = [:]  // contentKey → entry

    // Debounce
    private var pushFavoritesTask: Task<Void, Never>?
    private var pushProgressTask: Task<Void, Never>?

    private var profileHash: String = ""
    private var userId: String = ""

    // MARK: - Initialize

    func configure(profileHash: String, userId: String) {
        self.profileHash = profileHash
        self.userId = userId
    }

    var isReady: Bool {
        !profileHash.isEmpty && !userId.isEmpty
    }

    /// Pull all remote data and merge with local.
    func pullAll() async {
        guard isReady else { return }
        logger.info("Pulling sync data…")

        async let favs = pullFavorites()
        async let progress = pullWatchProgress()

        let remoteFavs = await favs
        let remoteProgress = await progress

        // Merge: local wins, remote fills gaps
        for (key, item) in remoteFavs where favorites[key] == nil {
            favorites[key] = item
        }
        for (key, entry) in remoteProgress where watchProgress[key] == nil {
            watchProgress[key] = entry
        }

        logger.info("Sync pulled: \(remoteFavs.count) favs, \(remoteProgress.count) progress")
        writeTopShelfSnapshot()
    }

    // MARK: - Top Shelf sharing (App Group)

    /// App Group id — must match the one declared in both entitlements files and
    /// in TopShelfContentProvider.swift.
    private static let topShelfAppGroup = "group.fr.unimaru.unistream.tv"
    private static let topShelfKey = "topshelf.favorites.v1"

    /// Snapshot of favorites used by the TV Top Shelf extension. Lightweight mirror
    /// of `FavoriteItem` — only the fields the extension needs.
    private struct TopShelfSnapshot: Codable {
        let key: String
        let name: String
        let imageUrl: String?
    }

    /// Writes the current live favorites to the shared App Group so the Top Shelf
    /// extension can display them without hitting Supabase or Xtream.
    func writeTopShelfSnapshot() {
        guard let defaults = UserDefaults(suiteName: Self.topShelfAppGroup) else { return }

        // Only live channels for now; sorted alphabetically; cap at 12.
        let snapshots: [TopShelfSnapshot] = favorites.values
            .filter { $0.mode == "live" }
            .sorted { $0.name < $1.name }
            .prefix(12)
            .map { TopShelfSnapshot(key: $0.key, name: $0.name, imageUrl: $0.displayIcon.isEmpty ? nil : $0.displayIcon) }

        if let data = try? JSONEncoder().encode(snapshots) {
            defaults.set(data, forKey: Self.topShelfKey)
        }
    }

    // MARK: - Favorites

    func toggleFavorite(_ item: FavoriteItem) {
        if favorites[item.key] != nil {
            favorites.removeValue(forKey: item.key)
        } else {
            favorites[item.key] = item
        }
        debouncePushFavorites()
        writeTopShelfSnapshot()
    }

    func isFavorite(_ key: String) -> Bool {
        favorites[key] != nil
    }

    private func pullFavorites() async -> [String: FavoriteItem] {
        do {
            let rows: [[String: String]] = try await client
                .from("user_favorites")
                .select("item_key, item_json")
                .eq("profile_hash", value: profileHash)
                .eq("list_type", value: "favorite")
                .eq("deleted", value: false)
                .execute()
                .value

            var result: [String: FavoriteItem] = [:]
            let decoder = JSONDecoder()
            for row in rows {
                guard let key = row["item_key"],
                      let jsonStr = row["item_json"],
                      let data = jsonStr.data(using: .utf8),
                      let item = try? decoder.decode(FavoriteItem.self, from: data)
                else { continue }
                result[key] = item
            }
            return result
        } catch {
            logger.warning("pullFavorites failed: \(error.localizedDescription)")
            return [:]
        }
    }

    private func debouncePushFavorites() {
        pushFavoritesTask?.cancel()
        pushFavoritesTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await pushFavorites()
        }
    }

    private func pushFavorites() async {
        guard isReady else { return }
        let encoder = JSONEncoder()

        for (key, item) in favorites {
            guard let jsonData = try? encoder.encode(item),
                  let jsonStr = String(data: jsonData, encoding: .utf8)
            else { continue }

            do {
                try await client
                    .from("user_favorites")
                    .upsert([
                        "user_id": userId,
                        "profile_hash": profileHash,
                        "item_key": key,
                        "list_type": "favorite",
                        "item_json": jsonStr,
                        "updated_at": ISO8601DateFormatter().string(from: Date()),
                        "deleted": "false",
                    ])
                    .execute()
            } catch {
                logger.warning("pushFavorite failed for \(key): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Watch Progress

    func saveProgress(contentKey: String, positionMs: Int, durationMs: Int, title: String? = nil) {
        guard durationMs > 10000 else { return }  // Ignore < 10s

        // Auto-clear if > 95% watched
        if positionMs > Int(Double(durationMs) * 0.95) {
            watchProgress.removeValue(forKey: contentKey)
        } else {
            // Preserve existing title if new one is nil
            let existingTitle = watchProgress[contentKey]?.title
            watchProgress[contentKey] = WatchEntry(
                positionMs: positionMs,
                durationMs: durationMs,
                updatedAt: Date(),
                title: title ?? existingTitle
            )
        }

        debouncePushProgress(contentKey: contentKey)
    }

    func getProgress(contentKey: String) -> WatchEntry? {
        watchProgress[contentKey]
    }

    /// Register a playback session — stores the title immediately so history always has a name.
    /// Called at the start of playback, before any progress is tracked.
    func registerPlayback(contentKey: String, title: String, durationMs: Int = 0) {
        let existing = watchProgress[contentKey]
        // Always update the title (even if one exists — caller has the latest)
        watchProgress[contentKey] = WatchEntry(
            positionMs: existing?.positionMs ?? 1,
            durationMs: durationMs > 0 ? durationMs : (existing?.durationMs ?? 0),
            updatedAt: Date(),
            title: title
        )
        debouncePushProgress(contentKey: contentKey)
    }

    /// Resolve missing titles from API data.
    /// Call after preloading VOD/series/channel lists.
    func resolveMissingTitles(channels: [Channel], vodItems: [VodItem], episodes: [(id: String, title: String)]) {
        var updated = false
        for (key, entry) in watchProgress where entry.title == nil || entry.title?.isEmpty == true {
            var resolved: String?
            if key.hasPrefix("vod_") {
                let sid = String(key.dropFirst(4))
                resolved = vodItems.first(where: { $0.streamId == sid })?.name
            } else if key.hasPrefix("ep_") {
                let eid = String(key.dropFirst(3))
                resolved = episodes.first(where: { $0.id == eid })?.title
            } else if key.hasPrefix("live_") {
                let sid = String(key.dropFirst(5))
                resolved = channels.first(where: { $0.streamId == sid })?.name
            }
            if let resolved {
                watchProgress[key]?.title = resolved
                updated = true
                debouncePushProgress(contentKey: key)
            }
        }
        if updated {
            let count = watchProgress.filter { $0.value.title != nil }.count
            logger.info("Resolved \(count) history titles")
        }
    }

    /// Remove a single watch progress entry.
    func removeProgress(contentKey: String) {
        watchProgress.removeValue(forKey: contentKey)
    }

    /// Clear all watch progress.
    func clearAllProgress() {
        watchProgress.removeAll()
    }

    private func pullWatchProgress() async -> [String: WatchEntry] {
        do {
            let rows: [[String: AnyJSON]] = try await client
                .from("user_watch_progress")
                .select("content_key, position_ms, duration_ms, updated_at, meta_json")
                .eq("profile_hash", value: profileHash)
                .execute()
                .value

            var result: [String: WatchEntry] = [:]
            for row in rows {
                guard let key = row["content_key"]?.stringValue else { continue }
                let posMs = row["position_ms"]?.intValue ?? 0
                let durMs = row["duration_ms"]?.intValue ?? 0
                guard durMs > 10000 else { continue }

                // Extract title from meta_json
                var title: String?
                if let metaStr = row["meta_json"]?.stringValue,
                   let metaData = metaStr.data(using: .utf8),
                   let metaDict = try? JSONSerialization.jsonObject(with: metaData) as? [String: Any] {
                    title = metaDict["title"] as? String
                }

                // Parse updated_at
                var updatedAt = Date()
                if let dateStr = row["updated_at"]?.stringValue {
                    let fmt = ISO8601DateFormatter()
                    fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    updatedAt = fmt.date(from: dateStr) ?? Date()
                }

                result[key] = WatchEntry(positionMs: posMs, durationMs: durMs, updatedAt: updatedAt, title: title)
            }
            return result
        } catch {
            logger.warning("pullWatchProgress failed: \(error.localizedDescription)")
            return [:]
        }
    }

    private func debouncePushProgress(contentKey: String) {
        pushProgressTask?.cancel()
        pushProgressTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await pushProgress(contentKey: contentKey)
        }
    }

    private func pushProgress(contentKey: String) async {
        guard isReady, let entry = watchProgress[contentKey] else { return }

        // Store title in meta_json for cross-device sync
        var meta = "{}"
        if let title = entry.title {
            let escaped = title.replacingOccurrences(of: "\"", with: "\\\"")
            meta = "{\"title\":\"\(escaped)\"}"
        }

        do {
            try await client
                .from("user_watch_progress")
                .upsert([
                    "user_id": userId,
                    "profile_hash": profileHash,
                    "content_key": contentKey,
                    "position_ms": "\(entry.positionMs)",
                    "duration_ms": "\(entry.durationMs)",
                    "meta_json": meta,
                    "updated_at": ISO8601DateFormatter().string(from: Date()),
                ])
                .execute()
        } catch {
            logger.warning("pushProgress failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

struct WatchEntry {
    var positionMs: Int
    var durationMs: Int
    var updatedAt: Date
    var title: String?

    var progress: Double {
        guard durationMs > 0 else { return 0 }
        return min(Double(positionMs) / Double(durationMs), 1.0)
    }

    /// Formatted elapsed time string (e.g. "1h 23min" or "45 min").
    var elapsedFormatted: String {
        let totalSec = positionMs / 1000
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))min" }
        return "\(m) min"
    }

    /// Formatted total duration string.
    var durationFormatted: String {
        let totalSec = durationMs / 1000
        let h = totalSec / 3600
        let m = (totalSec % 3600) / 60
        if h > 0 { return "\(h)h \(String(format: "%02d", m))min" }
        return "\(m) min"
    }
}

// MARK: - AnyJSON Helpers

extension AnyJSON {
    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        if case .integer(let i) = self { return i }
        if case .double(let d) = self { return Int(d) }
        if case .string(let s) = self { return Int(s) }
        return nil
    }
}
