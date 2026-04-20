import Foundation
import Observation

/// View-model glue for TMDB enrichment. Created per-detail-screen; fetches
/// results on `load()` and exposes them via `@Observable`.
///
/// Swift equivalent of the Riverpod `tmdbLookupProvider(family)` in Flutter.
@Observable
final class TMDBViewModel {
    var result: TMDBResult?
    var isLoading: Bool = false
    var hasFetched: Bool = false

    private let service = TMDBService.shared

    /// Loads TMDB enrichment for the given raw title + kind. Safe to call
    /// multiple times; subsequent calls with the same parameters hit the
    /// cache and return immediately.
    @MainActor
    func load(rawTitle: String, kind: TMDBKind) async {
        guard !hasFetched else { return }
        hasFetched = true

        // Synchronous cache hit → render without the loading flash.
        let parsed = TitleYearParser.parse(rawTitle)
        if parsed.isUsable,
           let entry = TMDBCache.shared.get(kind: kind, title: parsed.title, year: parsed.year) {
            if !entry.negative {
                result = entry.result
                return
            }
            if entry.negative {
                // Cached miss — don't re-fetch until TTL expires.
                return
            }
        }

        isLoading = true
        let r = await service.enrich(rawTitle: rawTitle, kind: kind)
        isLoading = false
        result = r
    }
}
