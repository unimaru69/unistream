import Foundation
import os

/// Lazy, in-memory full-catalog index used by `CastFilmographyView` to
/// resolve TMDB person credits against what the user actually has on
/// their Xtream provider. The category-scoped `VODViewModel` /
/// `SeriesViewModel` only know about the currently-browsed category;
/// without this index, "Christopher Nolan a tourné Inception" couldn't
/// answer "et est-ce que je l'ai dans mon catalogue ?" unless the user
/// had previously opened the right category.
///
/// Warms up on first access. The full payload from Xtream is small
/// enough (a few thousand titles) that we can hold all of it in memory
/// — much smaller than the per-category posters the rest of the UI
/// already keeps around.
@MainActor @Observable
final class CatalogIndex {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "CatalogIndex")

    enum LoadState: Equatable {
        case idle
        case loading
        case ready
        case failed(String)
    }

    /// Result of a cast-filmography lookup.
    enum Match {
        case vod(VodItem)
        case series(SeriesItem)
        case notFound
    }

    private(set) var movieState: LoadState = .idle
    private(set) var seriesState: LoadState = .idle

    /// Normalised-title → item. Built once, queried with the same
    /// normalisation so accents / case / "FR|" prefixes don't trip
    /// matching.
    private var movieIndex: [String: VodItem] = [:]
    private var seriesIndex: [String: SeriesItem] = [:]

    private var api: XtreamAPIService?

    func configure(api: XtreamAPIService) {
        self.api = api
    }

    // MARK: - Public lookups

    /// Best-effort match for a TMDB credit. Returns immediately when
    /// the relevant index is already loaded; kicks off a load when
    /// not. Callers can keep observing the relevant `*State` to know
    /// when to retry.
    func match(title: String, kind: TMDBKind) -> Match {
        let normalized = Self.normalise(title)
        if normalized.isEmpty { return .notFound }
        switch kind {
        case .movie:
            if let v = movieIndex[normalized] { return .vod(v) }
        case .tv:
            if let s = seriesIndex[normalized] { return .series(s) }
        }
        return .notFound
    }

    /// Trigger a warmup of either index. No-op when already loading or
    /// ready. The view holding the reference observes `movieState` /
    /// `seriesState` to react when the data lands.
    func warmupIfNeeded(_ kind: TMDBKind) {
        switch kind {
        case .movie:
            guard movieState == .idle || isFailed(movieState) else { return }
            Task { await loadMovies() }
        case .tv:
            guard seriesState == .idle || isFailed(seriesState) else { return }
            Task { await loadSeries() }
        }
    }

    // MARK: - Loaders

    private func loadMovies() async {
        guard let api else { return }
        movieState = .loading
        do {
            let items = try await api.getVodStreams(categoryId: nil)
            var dict: [String: VodItem] = [:]
            for it in items {
                let key = Self.normalise(it.name)
                guard !key.isEmpty else { continue }
                // First-write wins — collisions are rare; if the same
                // movie is in multiple categories the user can still
                // open it.
                if dict[key] == nil { dict[key] = it }
            }
            movieIndex = dict
            movieState = .ready
            logger.info("CatalogIndex: \(items.count) movies indexed (\(dict.count) unique titles)")
        } catch {
            movieState = .failed(error.localizedDescription)
            logger.warning("CatalogIndex movies failed: \(error.localizedDescription)")
        }
    }

    private func loadSeries() async {
        guard let api else { return }
        seriesState = .loading
        do {
            let items = try await api.getSeries(categoryId: nil)
            var dict: [String: SeriesItem] = [:]
            for it in items {
                let key = Self.normalise(it.name)
                guard !key.isEmpty else { continue }
                if dict[key] == nil { dict[key] = it }
            }
            seriesIndex = dict
            seriesState = .ready
            logger.info("CatalogIndex: \(items.count) series indexed (\(dict.count) unique titles)")
        } catch {
            seriesState = .failed(error.localizedDescription)
            logger.warning("CatalogIndex series failed: \(error.localizedDescription)")
        }
    }

    private func isFailed(_ state: LoadState) -> Bool {
        if case .failed = state { return true }
        return false
    }

    // MARK: - Title normalisation

    /// Strip the IPTV provider tag, the trailing `(YYYY)`, accents, and
    /// punctuation; lowercase. The match is intentionally fuzzy
    /// because TMDB titles and IPTV titles disagree on exact spelling
    /// fairly often.
    static func normalise(_ raw: String) -> String {
        let cleaned = raw.cleanedTitleNoYear
        let folded = cleaned.folding(options: .diacriticInsensitive, locale: .current)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let stripped = String(folded.unicodeScalars.filter { allowed.contains($0) })
        return stripped
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
