import Foundation
import os

/// Search filter for watch status.
enum SearchFilter: String, CaseIterable, Identifiable {
    case all = "Tout"
    case watched = "Vu"
    case inProgress = "En cours"
    case unwatched = "Non vu"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: "line.3.horizontal.decrease.circle"
        case .watched: "checkmark.circle.fill"
        case .inProgress: "play.circle.fill"
        case .unwatched: "circle"
        }
    }
}

/// Search across all content types with filters and history.
@MainActor @Observable
final class SearchViewModel {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Search")

    private(set) var channels: [Channel] = []
    private(set) var vodItems: [VodItem] = []
    private(set) var seriesItems: [SeriesItem] = []
    var query = ""
    var isSearching = false
    var activeFilter: SearchFilter = .all

    /// Search history (most recent first).
    private(set) var searchHistory: [String] = []
    private static let historyKey = "search_history"
    private static let maxHistory = 20

    /// All channels/vod/series loaded from API (cached for local filtering).
    private var allChannels: [Channel] = []
    private var allVod: [VodItem] = []
    private var allSeries: [SeriesItem] = []
    private var isLoaded = false

    private let api: XtreamAPIService
    /// Injected from outside so we can filter by watch status.
    var syncService: SyncService?

    init(api: XtreamAPIService) {
        self.api = api
        loadHistory()
    }

    /// Pre-load all content for local search (called once).
    func preload() async {
        guard !isLoaded else { return }
        isSearching = true
        do {
            async let ch = api.getLiveStreams()
            async let vd = api.getVodStreams()
            async let sr = api.getSeries()
            allChannels = try await ch
            allVod = try await vd
            allSeries = try await sr
            isLoaded = true
            logger.info("Search preloaded: \(self.allChannels.count) ch, \(self.allVod.count) vod, \(self.allSeries.count) series")
        } catch {
            logger.error("Search preload failed: \(error.localizedDescription)")
        }
        isSearching = false
    }

    /// Filter results by query and active filter (local, instant).
    func search() {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else {
            channels = []
            vodItems = []
            seriesItems = []
            return
        }

        // Text match
        let matchedChannels = allChannels.filter { $0.name.lowercased().contains(q) }
        var matchedVod = allVod.filter { $0.name.lowercased().contains(q) }
        var matchedSeries = allSeries.filter { $0.name.lowercased().contains(q) }

        // Apply watch status filter for VOD and Series
        if activeFilter != .all, let sync = syncService {
            matchedVod = matchedVod.filter { filterByStatus("vod_\($0.streamId)", sync: sync) }
            matchedSeries = matchedSeries.filter { filterByStatus("series_\($0.seriesId)", sync: sync) }
        }

        channels = Array(matchedChannels.prefix(50))
        vodItems = Array(matchedVod.prefix(50))
        seriesItems = Array(matchedSeries.prefix(50))
    }

    private func filterByStatus(_ key: String, sync: SyncService) -> Bool {
        let entry = sync.getProgress(contentKey: key)
        switch activeFilter {
        case .all: return true
        case .watched: return entry != nil && entry!.progress > 0.95
        case .inProgress: return entry != nil && entry!.progress > 0.0 && entry!.progress <= 0.95
        case .unwatched: return entry == nil
        }
    }

    // MARK: - Search History

    func commitSearch() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        // Remove duplicates, add to front
        searchHistory.removeAll { $0.lowercased() == q.lowercased() }
        searchHistory.insert(q, at: 0)
        if searchHistory.count > Self.maxHistory {
            searchHistory = Array(searchHistory.prefix(Self.maxHistory))
        }
        saveHistory()
    }

    func deleteHistoryItem(_ item: String) {
        searchHistory.removeAll { $0 == item }
        saveHistory()
    }

    func clearHistory() {
        searchHistory = []
        saveHistory()
    }

    func selectHistoryItem(_ item: String) {
        query = item
        search()
    }

    private func loadHistory() {
        searchHistory = UserDefaults.standard.stringArray(forKey: Self.historyKey) ?? []
    }

    private func saveHistory() {
        UserDefaults.standard.set(searchHistory, forKey: Self.historyKey)
    }
}
