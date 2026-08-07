import Foundation
import os

/// Owns the "go and re-pull the catalogue from the Xtream panel" policy.
///
/// `XtreamAPIService` caches stream lists for `Constants.streamCacheTTL`
/// (5 min), but that TTL is a *rate limiter*, not a freshness policy: it
/// only stops the UI hammering the panel while the user browses. Nothing
/// ever went back to the server on its own to pick up the films, episodes
/// and channels the provider added since launch — the only way to see
/// them was to quit and relaunch the app.
///
/// This service is that missing policy:
///   * an explicit **Actualiser le catalogue** action (Réglages),
///   * an optional **staleness check on foreground** (`isStale`),
///   * a `generation` counter views can key their `.task(id:)` on so
///     screens holding their own copy of the catalogue (hero banner,
///     "Ajoutés récemment", recherche) re-pull too.
///
/// A cold start already fetches everything from the network — the stream
/// cache lives in memory only — so process launch counts as a refresh
/// (`markFreshStart`) and doesn't trigger redundant work.
@MainActor @Observable
final class CatalogRefreshService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "CatalogRefresh")

    /// How long the catalogue may go unrefreshed before a return to the
    /// foreground triggers an automatic pull.
    enum Interval: Int, CaseIterable, Identifiable {
        case manual = 0
        case sixHours = 21_600
        case twelveHours = 43_200
        case daily = 86_400

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .manual: "Manuelle uniquement"
            case .sixHours: "Toutes les 6 h"
            case .twelveHours: "Toutes les 12 h"
            case .daily: "Une fois par jour"
            }
        }
    }

    // MARK: - Persistence keys

    /// User preference — global, not per profile.
    private static let intervalKey = "catalog.autoRefresh.interval"

    /// Per-profile timestamp: two profiles on two different panels have
    /// unrelated catalogues.
    private static func lastRefreshKey(_ prefix: String) -> String {
        "catalog.lastRefresh.\(prefix)"
    }

    // MARK: - State

    private(set) var lastRefresh: Date?
    private(set) var isRefreshing = false

    /// Bumped after every completed refresh. Views that keep their own
    /// slice of the catalogue observe this and re-run their loader.
    private(set) var generation = 0

    var interval: Interval {
        didSet {
            guard interval != oldValue else { return }
            UserDefaults.standard.set(interval.rawValue, forKey: Self.intervalKey)
        }
    }

    private var profilePrefix = ""

    init() {
        let stored = UserDefaults.standard.object(forKey: Self.intervalKey) as? Int
        interval = stored.flatMap(Interval.init(rawValue:)) ?? .sixHours
    }

    // MARK: - Lifecycle

    /// Bind to the active profile and restore its last-refresh stamp.
    func configure(profilePrefix: String) {
        self.profilePrefix = profilePrefix
        let ts = UserDefaults.standard.double(forKey: Self.lastRefreshKey(profilePrefix))
        lastRefresh = ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    /// Process launch pulls everything from the network anyway, so it
    /// counts as a refresh. Without this, every cold start after the
    /// interval elapsed would immediately re-fetch data it just fetched.
    func markFreshStart() {
        stampNow()
    }

    /// True when a foreground return should trigger an automatic pull.
    var isStale: Bool {
        guard interval != .manual else { return false }
        guard let lastRefresh else { return true }
        return Date().timeIntervalSince(lastRefresh) >= TimeInterval(interval.rawValue)
    }

    /// Human-readable age for the Réglages row. Recomputed on render —
    /// good enough for a settings screen.
    var lastRefreshLabel: String {
        guard let lastRefresh else { return "jamais" }
        let secs = Date().timeIntervalSince(lastRefresh)
        if secs < 60 { return "à l'instant" }
        if secs < 3_600 { return "il y a \(Int(secs / 60)) min" }
        if secs < 86_400 { return "il y a \(Int(secs / 3_600)) h" }
        return "il y a \(Int(secs / 86_400)) j"
    }

    // MARK: - Refresh

    /// Drop every catalogue cache and re-pull whatever the app is
    /// currently showing. Re-entrant calls are ignored.
    ///
    /// View-models are reloaded sequentially rather than concurrently:
    /// Xtream panels routinely cap simultaneous sessions per account
    /// (the client already sends `Connection: close` for that reason),
    /// and a refresh is not latency-critical.
    @discardableResult
    func refresh(_ appState: AppState, reason: String) async -> Bool {
        guard !isRefreshing else { return false }
        guard appState.api.isAuthenticated || DemoMode.isActive else {
            logger.info("Catalogue refresh skipped — not connected")
            return false
        }

        isRefreshing = true
        logger.info("Catalogue refresh started (\(reason))")

        appState.api.clearStreamCache()
        appState.epgCache.invalidateToday()
        appState.catalogIndex.reset()

        await appState.liveVM?.reloadAfterCatalogRefresh()
        await appState.vodVM?.reloadAfterCatalogRefresh()
        await appState.seriesVM?.reloadAfterCatalogRefresh()

        stampNow()
        generation &+= 1
        isRefreshing = false
        logger.info("Catalogue refresh done (generation \(self.generation))")
        return true
    }

    // MARK: - Private

    private func stampNow() {
        let now = Date()
        lastRefresh = now
        guard !profilePrefix.isEmpty else { return }
        UserDefaults.standard.set(now.timeIntervalSince1970,
                                  forKey: Self.lastRefreshKey(profilePrefix))
    }
}
