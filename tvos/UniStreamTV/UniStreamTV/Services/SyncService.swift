import Foundation
@preconcurrency import Supabase
import os

/// Cloud sync service — mirrors Flutter's `sync_service.dart`.
/// Syncs favorites, watch progress, and collections to Supabase.
@MainActor @Observable
final class SyncService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Sync")
    private let client = SupabaseConfig.client

    // Local state
    private(set) var favorites: [String: FavoriteItem] = [:]  // key → item
    private(set) var watchlist: [String: FavoriteItem] = [:]  // key → item ("À regarder")
    private(set) var watchProgress: [String: WatchEntry] = [:]  // contentKey → entry

    // Pending deletions — tracked separately so the push step can mark
    // the matching Supabase rows as `deleted = true` (favorites /
    // watchlist) or DELETE them outright (watch progress). Without
    // this, removing a favourite or marking-as-unwatched only mutates
    // the local dictionary; the next `pullAll` re-hydrates the same
    // item from Supabase and the user sees their action revert. Also
    // consulted by `pullAll`'s merge step so a remote row in flight
    // can't override an explicit user removal.
    private var pendingFavoriteDeletes: Set<String> = []
    private var pendingWatchlistDeletes: Set<String> = []
    private var pendingProgressDeletes: Set<String> = []

    // Pending *upserts* — keys whose local state hasn't yet flushed to
    // Supabase. Critical for two reasons:
    //   1. `debouncePushProgress` keeps a single task that gets
    //      cancelled on each new call — without batching, bulk-marking
    //      eight episodes back-to-back resulted in only the last one
    //      ever reaching Supabase. The set accumulates every key that
    //      changed; the eventual flush walks them all.
    //   2. `pullAll`'s authoritative merge wipes local items missing
    //      from the remote snapshot. A freshly-mutated key that
    //      hasn't pushed yet would get wiped if we didn't exclude it
    //      from the wipe filter.
    private var pendingProgressPushes: Set<String> = []
    private var pendingFavoritePushes: Set<String> = []
    private var pendingWatchlistPushes: Set<String> = []

    // Debounce
    private var pushFavoritesTask: Task<Void, Never>?
    private var pushWatchlistTask: Task<Void, Never>?
    private var pushProgressTask: Task<Void, Never>?

    private var profileHash: String = ""
    private var userId: String = ""

    // MARK: - Initialize

    func configure(profileHash: String, userId: String) {
        self.profileHash = profileHash
        self.userId = userId
        // Hydrate the in-memory caches from disk *before* the first
        // Supabase pull lands. This makes a "mark vu → power off Apple
        // TV → boot back up" sequence reliable even if the Supabase
        // push didn't get a chance to flush before shutdown — the
        // local cache survives via UserDefaults and gets re-pushed on
        // the next debounce.
        loadLocalCache()
    }

    var isReady: Bool {
        !profileHash.isEmpty && !userId.isEmpty
    }

    /// Pull all remote data and merge with local.
    func pullAll() async {
        guard isReady else { return }
        logger.info("Pulling sync data…")

        // Each pull returns a Result so the merge step can tell
        // "remote really has zero items" (apply authoritative wipe)
        // from "the network blew up" (skip wipe — the local cache is
        // the only truth left). Before this distinction, a transient
        // network error during pullWatchProgress wiped every locally-
        // marked-as-watched episode on launch — exactly the bug
        // reported on Apple TV restart in build 36.
        async let favs: Result<[String: FavoriteItem], Error> = Result {
            try await pullFavoritesThrowing()
        }
        async let wlist: Result<[String: FavoriteItem], Error> = Result {
            try await pullWatchlistThrowing()
        }
        async let progress: Result<[String: WatchEntry], Error> = Result {
            try await pullWatchProgressThrowing()
        }

        let remoteFavs = await favs
        let remoteWatchlist = await wlist
        let remoteProgress = await progress

        // Apply additions first — always safe (we're filling gaps).
        if case .success(let dict) = remoteFavs {
            for (key, item) in dict where favorites[key] == nil && !pendingFavoriteDeletes.contains(key) {
                favorites[key] = item
            }
        }
        if case .success(let dict) = remoteWatchlist {
            for (key, item) in dict where watchlist[key] == nil && !pendingWatchlistDeletes.contains(key) {
                watchlist[key] = item
            }
        }
        if case .success(let dict) = remoteProgress {
            for (key, entry) in dict where watchProgress[key] == nil && !pendingProgressDeletes.contains(key) {
                watchProgress[key] = entry
            }
        }

        // Authoritative wipes — only run when the corresponding pull
        // actually succeeded. A failure → skip; the local cache stays
        // intact and we'll reconcile on the next successful pull /
        // realtime event.
        //
        // The wipe filters also exclude `pending*Pushes`: a key the
        // user just mutated locally but that hasn't reached Supabase
        // yet (still inside the 500 ms debounce window) can't be
        // wiped just because the racing pull doesn't see it. Without
        // this exclusion, bulk-marking eight episodes back-to-back
        // and pulling immediately afterward would erase the seven
        // most-recent marks before the push could land them.
        var wiped = 0
        if case .success(let dict) = remoteFavs {
            let toWipe = favorites.keys.filter {
                !dict.keys.contains($0)
                    && !pendingFavoriteDeletes.contains($0)
                    && !pendingFavoritePushes.contains($0)
            }
            for key in toWipe { favorites.removeValue(forKey: key) }
            wiped += toWipe.count
        } else if case .failure(let err) = remoteFavs {
            logger.warning("pullFavorites failed (skipping wipe): \(err.localizedDescription)")
        }
        if case .success(let dict) = remoteWatchlist {
            let toWipe = watchlist.keys.filter {
                !dict.keys.contains($0)
                    && !pendingWatchlistDeletes.contains($0)
                    && !pendingWatchlistPushes.contains($0)
            }
            for key in toWipe { watchlist.removeValue(forKey: key) }
            wiped += toWipe.count
        } else if case .failure(let err) = remoteWatchlist {
            logger.warning("pullWatchlist failed (skipping wipe): \(err.localizedDescription)")
        }
        if case .success(let dict) = remoteProgress {
            let toWipe = watchProgress.keys.filter {
                !dict.keys.contains($0)
                    && !pendingProgressDeletes.contains($0)
                    && !pendingProgressPushes.contains($0)
            }
            for key in toWipe { watchProgress.removeValue(forKey: key) }
            wiped += toWipe.count
        } else if case .failure(let err) = remoteProgress {
            logger.warning("pullWatchProgress failed (skipping wipe): \(err.localizedDescription)")
        }

        let favCount = (try? remoteFavs.get().count) ?? -1
        let wlCount = (try? remoteWatchlist.get().count) ?? -1
        let progCount = (try? remoteProgress.get().count) ?? -1
        logger.info("Sync pulled: \(favCount) favs, \(wlCount) watchlist, \(progCount) progress; wiped \(wiped) stale local rows (-1 = pull failed)")
        writeTopShelfSnapshot()
    }

    // MARK: - Local cache (restart-survival)

    /// UserDefaults keys for the local mirror of the Supabase state.
    /// Stored at the app group so the Top Shelf extension can also
    /// read them later if needed; keyed by profile hash so two
    /// profiles on the same Apple TV don't share data.
    private static let localCacheGroup = "group.fr.unimaru.unistream.tv"
    private func cacheKey(_ kind: String) -> String {
        "synccache.\(kind).\(profileHash)"
    }

    /// Mirror the in-memory dictionaries to UserDefaults. Writes are
    /// cheap and synchronous-ish — the snapshot gets to disk before
    /// the user can power off the box, so a mark-vu / favourite-
    /// toggle can't be lost to an instant shutdown that happens
    /// inside the 500 ms push debounce.
    private func writeLocalCache() {
        guard !profileHash.isEmpty else { return }
        guard let defaults = UserDefaults(suiteName: Self.localCacheGroup) else { return }
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(favorites) {
            defaults.set(data, forKey: cacheKey("favorites"))
        }
        if let data = try? encoder.encode(watchlist) {
            defaults.set(data, forKey: cacheKey("watchlist"))
        }
        if let data = try? encoder.encode(watchProgress) {
            defaults.set(data, forKey: cacheKey("watchProgress"))
        }
    }

    /// Read the on-disk mirror back into memory. Called from
    /// `configure` so the UI sees something the moment the user
    /// returns to the app, even before the Supabase pull completes.
    private func loadLocalCache() {
        guard let defaults = UserDefaults(suiteName: Self.localCacheGroup) else { return }
        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: cacheKey("favorites")),
           let dict = try? decoder.decode([String: FavoriteItem].self, from: data) {
            favorites = dict
        }
        if let data = defaults.data(forKey: cacheKey("watchlist")),
           let dict = try? decoder.decode([String: FavoriteItem].self, from: data) {
            watchlist = dict
        }
        if let data = defaults.data(forKey: cacheKey("watchProgress")),
           let dict = try? decoder.decode([String: WatchEntry].self, from: data) {
            watchProgress = dict
        }
        let counts = "\(favorites.count) favs, \(watchlist.count) watchlist, \(watchProgress.count) progress"
        logger.info("Local cache hydrated: \(counts)")
    }

    // MARK: - Top Shelf sharing (App Group)

    /// App Group id — must match the one declared in both entitlements files and
    /// in TopShelfContentProvider.swift.
    private static let topShelfAppGroup = "group.fr.unimaru.unistream.tv"
    private static let topShelfFavoritesKey = "topshelf.favorites.v2"
    private static let topShelfContinueKey = "topshelf.continue.v1"

    /// Lightweight mirror of `FavoriteItem` — only the fields the extension needs.
    private struct TopShelfFavorite: Codable {
        let key: String
        let name: String
        let imageUrl: String?
        let mode: String  // "live", "movie", "series"
    }

    /// Lightweight mirror of in-progress items for the Top Shelf "Continue Watching" row.
    private struct TopShelfContinueItem: Codable {
        let key: String
        let name: String
        let imageUrl: String?
        let progress: Double  // 0.0–1.0
        let updatedAt: TimeInterval  // Date().timeIntervalSince1970
    }

    /// Writes favorites and continue-watching to the shared App Group so the
    /// Top Shelf extension can display them without hitting Supabase or Xtream.
    /// Also mirrors the full state to a local cache so the next launch can
    /// hydrate before Supabase has had a chance to round-trip.
    func writeTopShelfSnapshot() {
        writeLocalCache()
        guard let defaults = UserDefaults(suiteName: Self.topShelfAppGroup) else { return }
        let encoder = JSONEncoder()

        // Favorites: all modes, sorted alphabetically, cap at 20.
        let favSnapshots: [TopShelfFavorite] = favorites.values
            .sorted { $0.name < $1.name }
            .prefix(20)
            .map { TopShelfFavorite(key: $0.key, name: $0.name, imageUrl: $0.displayIcon.isEmpty ? nil : $0.displayIcon, mode: $0.mode) }

        if let data = try? encoder.encode(favSnapshots) {
            defaults.set(data, forKey: Self.topShelfFavoritesKey)
        }

        // Continue Watching: in-progress items (5–95%), sorted by most recent, cap at 10.
        let continueSnapshots: [TopShelfContinueItem] = watchProgress
            .filter { $0.value.progress > 0.05 && $0.value.progress < 0.95 }
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
            .prefix(10)
            .map { (key, entry) in
                let fav = favorites[key]
                let title = entry.title ?? fav?.name ?? key
                let image = fav?.displayIcon
                return TopShelfContinueItem(
                    key: key,
                    name: title,
                    imageUrl: (image?.isEmpty ?? true) ? nil : image,
                    progress: entry.progress,
                    updatedAt: entry.updatedAt.timeIntervalSince1970
                )
            }

        if let data = try? encoder.encode(continueSnapshots) {
            defaults.set(data, forKey: Self.topShelfContinueKey)
        }
    }

    // MARK: - Favorites

    func toggleFavorite(_ item: FavoriteItem) {
        if favorites[item.key] != nil {
            favorites.removeValue(forKey: item.key)
            pendingFavoriteDeletes.insert(item.key)
            pendingFavoritePushes.remove(item.key)
        } else {
            favorites[item.key] = item
            // Re-favourite supersedes a pending delete — clear it so
            // the push doesn't soft-delete the row we just upserted.
            pendingFavoriteDeletes.remove(item.key)
            // Track for the merge wipe filter — without this an
            // authoritative pull that races the 500 ms push debounce
            // would treat the new favourite as a stale local row and
            // wipe it.
            pendingFavoritePushes.insert(item.key)
        }
        debouncePushFavorites()
        writeTopShelfSnapshot()
    }

    func isFavorite(_ key: String) -> Bool {
        favorites[key] != nil
    }

    private func pullFavorites() async -> [String: FavoriteItem] {
        // Legacy non-throwing wrapper kept for the recovery /
        // migration code paths that don't care to differentiate
        // failure from emptiness.
        (try? await pullFavoritesThrowing()) ?? [:]
    }

    /// Throwing variant. Used by `pullAll` so the merge step can tell
    /// "remote really has zero items" from "the network blew up".
    /// Without that distinction, a transient pull failure on launch
    /// silently wiped the entire local cache via the authoritative
    /// merge path.
    private func pullFavoritesThrowing() async throws -> [String: FavoriteItem] {
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
                pendingFavoritePushes.remove(key)
            } catch {
                logger.warning("pushFavorite failed for \(key): \(error.localizedDescription)")
            }
        }

        // Flush pending deletes: mark the matching rows as deleted on
        // Supabase. Failed deletes are re-queued so the next push
        // retries them — otherwise an offline removal would silently
        // disappear once the network comes back.
        await flushFavoriteDeletes(listType: "favorite", pending: \.pendingFavoriteDeletes)
    }

    /// Soft-delete the rows queued in `keyPath` from Supabase. Pulls
    /// the snapshot up-front, clears the local set, and re-queues any
    /// failures so a future push retries.
    private func flushFavoriteDeletes(
        listType: String,
        pending keyPath: ReferenceWritableKeyPath<SyncService, Set<String>>
    ) async {
        let pending = self[keyPath: keyPath]
        guard !pending.isEmpty else { return }
        self[keyPath: keyPath] = []
        let nowIso = ISO8601DateFormatter().string(from: Date())

        for key in pending {
            do {
                try await client
                    .from("user_favorites")
                    .update([
                        "deleted": "true",
                        "updated_at": nowIso,
                    ])
                    .eq("user_id", value: userId)
                    .eq("profile_hash", value: profileHash)
                    .eq("item_key", value: key)
                    .eq("list_type", value: listType)
                    .execute()
            } catch {
                logger.warning("\(listType) delete failed for \(key): \(error.localizedDescription)")
                self[keyPath: keyPath].insert(key)
            }
        }
    }

    // MARK: - Watchlist ("À regarder")

    func toggleWatchlist(_ item: FavoriteItem) {
        if watchlist[item.key] != nil {
            watchlist.removeValue(forKey: item.key)
            pendingWatchlistDeletes.insert(item.key)
            pendingWatchlistPushes.remove(item.key)
        } else {
            watchlist[item.key] = item
            pendingWatchlistDeletes.remove(item.key)
            pendingWatchlistPushes.insert(item.key)
        }
        debouncePushWatchlist()
        // Persist to disk so the toggle survives an immediate Apple
        // TV restart even if the 500 ms push debounce hasn't fired.
        writeLocalCache()
    }

    func isInWatchlist(_ key: String) -> Bool {
        watchlist[key] != nil
    }

    private func pullWatchlist() async -> [String: FavoriteItem] {
        (try? await pullWatchlistThrowing()) ?? [:]
    }

    private func pullWatchlistThrowing() async throws -> [String: FavoriteItem] {
        let rows: [[String: String]] = try await client
            .from("user_favorites")
            .select("item_key, item_json")
            .eq("profile_hash", value: profileHash)
            .eq("list_type", value: "watchlist")
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
    }

    private func debouncePushWatchlist() {
        pushWatchlistTask?.cancel()
        pushWatchlistTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await pushWatchlist()
        }
    }

    private func pushWatchlist() async {
        guard isReady else { return }
        let encoder = JSONEncoder()

        for (key, item) in watchlist {
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
                        "list_type": "watchlist",
                        "item_json": jsonStr,
                        "updated_at": ISO8601DateFormatter().string(from: Date()),
                        "deleted": "false",
                    ])
                    .execute()
                pendingWatchlistPushes.remove(key)
            } catch {
                logger.warning("pushWatchlist failed for \(key): \(error.localizedDescription)")
            }
        }

        await flushFavoriteDeletes(listType: "watchlist", pending: \.pendingWatchlistDeletes)
    }

    // MARK: - Watch Progress

    func saveProgress(contentKey: String, positionMs: Int, durationMs: Int, title: String? = nil, streamUrl: String? = nil, coverUrl: String? = nil, seriesId: String? = nil) {
        guard durationMs > 10000 else { return }  // Ignore < 10s

        // Keep the entry even when > 95% watched — that flag tells us the
        // item is "watched" (see WatchEntry.isWatched). The Reprendre row
        // and Top Shelf filter those out on their side.
        let existing = watchProgress[contentKey]
        watchProgress[contentKey] = WatchEntry(
            positionMs: positionMs,
            durationMs: durationMs,
            updatedAt: Date(),
            title: title ?? existing?.title,
            streamUrl: streamUrl ?? existing?.streamUrl,
            coverUrl: coverUrl ?? existing?.coverUrl,
            seriesId: seriesId ?? existing?.seriesId
        )
        // Re-mark / re-save supersedes a queued unwatch.
        pendingProgressDeletes.remove(contentKey)
        debouncePushProgress(contentKey: contentKey)
        writeTopShelfSnapshot()
    }

    /// Mark a content item as fully watched (progress ≈ 99%).
    /// Used for "Marquer vu" and auto-mark-previous-episodes on play.
    func markAsWatched(contentKey: String, title: String? = nil) {
        let existing = watchProgress[contentKey]
        // Synthetic 1h duration — real duration will overwrite on first real play.
        let durationMs = existing?.durationMs ?? 3_600_000
        let positionMs = Int(Double(durationMs) * 0.99)
        watchProgress[contentKey] = WatchEntry(
            positionMs: positionMs,
            durationMs: durationMs,
            updatedAt: Date(),
            title: title ?? existing?.title,
            streamUrl: existing?.streamUrl,
            coverUrl: existing?.coverUrl,
            seriesId: existing?.seriesId
        )
        // Re-watch supersedes a pending delete from a prior unwatch
        // gesture that hasn't flushed yet.
        pendingProgressDeletes.remove(contentKey)
        debouncePushProgress(contentKey: contentKey)
        writeTopShelfSnapshot()
    }

    /// Clear any watched / in-progress state for the content item.
    /// `removeProgress` handles the deletion queue + push + Top Shelf
    /// snapshot — this is just the user-facing alias.
    func markAsUnwatched(contentKey: String) {
        removeProgress(contentKey: contentKey)
    }

    /// Whether the item has been fully watched (≥ 95%).
    func isWatched(contentKey: String) -> Bool {
        watchProgress[contentKey]?.isWatched ?? false
    }

    func getProgress(contentKey: String) -> WatchEntry? {
        watchProgress[contentKey]
    }

    /// Register a playback session — stores the title immediately so history always has a name.
    /// Called at the start of playback, before any progress is tracked.
    /// Patch only the `coverUrl` on an existing entry — used by the
    /// series detail flow to upgrade the coarse "series poster"
    /// fallback with a per-episode TMDB still once the async fetch
    /// resolves. No-op if the entry doesn't exist yet (the caller
    /// should have called `registerPlayback` first).
    func updateCoverUrl(contentKey: String, _ url: String) {
        guard var entry = watchProgress[contentKey] else { return }
        entry.coverUrl = url
        watchProgress[contentKey] = entry
        debouncePushProgress(contentKey: contentKey)
        writeTopShelfSnapshot()
    }

    func registerPlayback(contentKey: String, title: String, durationMs: Int = 0, streamUrl: String? = nil, coverUrl: String? = nil, seriesId: String? = nil) {
        let existing = watchProgress[contentKey]
        // Always update the title (even if one exists — caller has the latest)
        watchProgress[contentKey] = WatchEntry(
            positionMs: existing?.positionMs ?? 1,
            durationMs: durationMs > 0 ? durationMs : (existing?.durationMs ?? 0),
            updatedAt: Date(),
            title: title,
            streamUrl: streamUrl ?? existing?.streamUrl,
            coverUrl: coverUrl ?? existing?.coverUrl,
            seriesId: seriesId ?? existing?.seriesId
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

    /// Remove a single watch progress entry. Queues the row for
    /// deletion on Supabase and writes the Top Shelf snapshot — the
    /// HistoryView "Supprimer" gesture and `markAsUnwatched` both
    /// land here, so callers don't have to remember to debounce.
    func removeProgress(contentKey: String) {
        guard watchProgress[contentKey] != nil else { return }
        watchProgress.removeValue(forKey: contentKey)
        pendingProgressDeletes.insert(contentKey)
        debouncePushProgress(contentKey: contentKey)
        writeTopShelfSnapshot()
    }

    /// Clear all watch progress. Queues every key for cloud-side
    /// deletion so the wipe persists across pulls / new devices.
    func clearAllProgress() {
        let keys = Array(watchProgress.keys)
        watchProgress.removeAll()
        for key in keys {
            pendingProgressDeletes.insert(key)
            debouncePushProgress(contentKey: key)
        }
        writeTopShelfSnapshot()
    }

    private func pullWatchProgress() async -> [String: WatchEntry] {
        (try? await pullWatchProgressThrowing()) ?? [:]
    }

    private func pullWatchProgressThrowing() async throws -> [String: WatchEntry] {
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

            // Extract title + streamUrl + coverUrl + seriesId from
            // meta_json. Flutter writes `name`, `cover`, `url`;
            // older tvOS-only entries write `title`. Accept either
            // side. `objectValue` tolerates both shapes Supabase can
            // return — JSONB columns come back as already-parsed
            // objects, TEXT columns come back as JSON-encoded strings.
            var title: String?
            var streamUrl: String?
            var coverUrl: String?
            var seriesId: String?
            if let metaDict = row["meta_json"]?.objectValue {
                title = (metaDict["title"] as? String) ?? (metaDict["name"] as? String)
                streamUrl = metaDict["url"] as? String
                coverUrl = metaDict["cover"] as? String
                seriesId = metaDict["series_id"] as? String
            }

            // Parse updated_at
            var updatedAt = Date()
            if let dateStr = row["updated_at"]?.stringValue {
                let fmt = ISO8601DateFormatter()
                fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                updatedAt = fmt.date(from: dateStr) ?? Date()
            }

            result[key] = WatchEntry(
                positionMs: posMs,
                durationMs: durMs,
                updatedAt: updatedAt,
                title: title,
                streamUrl: streamUrl,
                coverUrl: coverUrl,
                seriesId: seriesId
            )
        }
        return result
    }

    private func debouncePushProgress(contentKey: String) {
        // Accumulate the changed key in a Set rather than capturing
        // it in the Task closure. Bulk operations like
        // "Marquer tous les précédents comme vus" call this 8+ times
        // back-to-back in a tight loop; the previous design cancelled
        // each Task as the next call landed, so only the *last* key
        // ever made it past the 500 ms sleep — every other mark was
        // lost on Apple TV restart because Supabase never received
        // the upsert. The Set means the eventual flush walks every
        // accumulated key.
        pendingProgressPushes.insert(contentKey)
        pushProgressTask?.cancel()
        pushProgressTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let keys = pendingProgressPushes
            for key in keys {
                await pushProgress(contentKey: key)
                // Remove only after a successful push so a racing
                // pullAll's wipe step still excludes keys that didn't
                // make it to Supabase yet (e.g. transient network
                // failure mid-flush).
                pendingProgressPushes.remove(key)
            }
        }
    }

    private func pushProgress(contentKey: String) async {
        guard isReady else { return }

        // Two cases. If the user just hit "Marquer non vu" (or
        // otherwise removed the entry), the local entry is gone and
        // the key sits in `pendingProgressDeletes` — issue a DELETE
        // against Supabase so the row doesn't come back on the next
        // pull. Otherwise upsert the local entry as before.
        if watchProgress[contentKey] == nil, pendingProgressDeletes.contains(contentKey) {
            pendingProgressDeletes.remove(contentKey)
            do {
                try await client
                    .from("user_watch_progress")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("profile_hash", value: profileHash)
                    .eq("content_key", value: contentKey)
                    .execute()
            } catch {
                logger.warning("pushProgress delete failed for \(contentKey): \(error.localizedDescription)")
                // Re-queue so the next push retries. Without this an
                // offline unwatch would silently revive once online.
                pendingProgressDeletes.insert(contentKey)
            }
            return
        }

        guard let entry = watchProgress[contentKey] else { return }

        // Store title + URL + cover in meta_json for cross-device sync.
        // Use JSONSerialization so quotes / unicode encode safely.
        // Keys mirror what Flutter writes (`name`/`url`/`cover`) plus the
        // `title` alias tvOS reads — older tvOS builds only knew `title`.
        var metaDict: [String: Any] = [:]
        if let title = entry.title {
            metaDict["title"] = title
            metaDict["name"] = title
        }
        if let url = entry.streamUrl { metaDict["url"] = url }
        if let cover = entry.coverUrl { metaDict["cover"] = cover }
        if let sid = entry.seriesId { metaDict["series_id"] = sid }
        let metaData = (try? JSONSerialization.data(withJSONObject: metaDict)) ?? Data("{}".utf8)
        let meta = String(data: metaData, encoding: .utf8) ?? "{}"

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

struct WatchEntry: Codable {
    var positionMs: Int
    var durationMs: Int
    var updatedAt: Date
    var title: String?
    /// Full Xtream stream URL captured at playback time. Lets us resume
    /// from the Continue Watching row without re-deriving the URL from a
    /// content key (impossible without the original `containerExtension`,
    /// which isn't carried in the key). Synced cross-device via
    /// `meta_json.url` on `user_watch_progress` — same key Flutter uses.
    var streamUrl: String?
    /// Poster / cover URL for the item, captured at playback time. Lets
    /// the Continue Watching shelf show real artwork instead of a grey
    /// play-icon placeholder when the item isn't favorited (the favorite
    /// store was the only previous source of cover URLs). Synced via
    /// `meta_json.cover` — Flutter already writes that key.
    var coverUrl: String?
    /// Owning series id for episode entries (`ep_…` content keys).
    /// Lets the CW shelf collapse a series down to its single most-
    /// recently-played episode instead of repeating five Drag Race
    /// rows in a row. Synced via `meta_json.series_id`.
    var seriesId: String?

    var progress: Double {
        guard durationMs > 0 else { return 0 }
        return min(Double(positionMs) / Double(durationMs), 1.0)
    }

    /// An item is considered watched once it has crossed the 95% threshold.
    var isWatched: Bool { progress > 0.95 }

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

    /// Decode a JSON object regardless of whether the column came back
    /// as a JSON string (TEXT column) or already-parsed object (JSONB
    /// column). The `meta_json` column on `user_watch_progress` ships
    /// as both depending on Supabase project config — this accessor
    /// hides that.
    var objectValue: [String: Any]? {
        switch self {
        case .object(let dict):
            // Convert AnyJSON values to plain Foundation types so
            // call-sites can keep using `as? String` etc.
            var out: [String: Any] = [:]
            for (k, v) in dict {
                out[k] = v.unwrappedValue
            }
            return out
        case .string(let s):
            guard let data = s.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return nil }
            return parsed
        default:
            return nil
        }
    }

    /// Recursively unwrap an AnyJSON tree to plain Foundation values.
    fileprivate var unwrappedValue: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let b): return b
        case .integer(let i): return i
        case .double(let d): return d
        case .string(let s): return s
        case .array(let a): return a.map { $0.unwrappedValue }
        case .object(let o):
            var out: [String: Any] = [:]
            for (k, v) in o { out[k] = v.unwrappedValue }
            return out
        }
    }
}
