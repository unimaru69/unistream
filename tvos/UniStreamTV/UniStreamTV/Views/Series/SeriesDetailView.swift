import SwiftUI
@preconcurrency import AVKit
import Kingfisher

/// Series detail — Apple TV+ style: full-bleed backdrop, hero block
/// with smart "Reprendre / Démarrer S1E1" CTA, season chips, then a
/// vertical episode list with per-episode TMDB stills and synopses.
struct SeriesDetailView: View {
    let series: SeriesItem
    @Bindable var viewModel: SeriesViewModel
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState
    @State private var selectedSeason: String?
    @State private var tmdbVM = TMDBViewModel()
    /// TMDB episode metadata (still + synopsis) keyed by season number.
    /// Loaded on demand whenever `selectedSeason` changes.
    @State private var seasonMeta: [Int: [Int: TMDBService.EpisodeMeta]] = [:]
    @State private var loadingSeason: Int?
    /// Episode awaiting the user's resume choice ("reprendre" vs
    /// "depuis le début"). Set by `playEpisode` when there's >10s of
    /// saved progress; the `confirmationDialog` reads this and the
    /// matching `pendingResumeProgress` to render its two actions.
    @State private var pendingResumeEpisode: Episode?
    @State private var pendingResumeProgress: WatchEntry?

    private var sourceSynopsis: String {
        series.plot ?? series.description ?? ""
    }
    private var effectiveSynopsis: String {
        if !sourceSynopsis.isEmpty { return sourceSynopsis }
        return tmdbVM.result?.overview ?? ""
    }
    private var backdropURL: String {
        if let b = tmdbVM.result?.backdropURL(size: "original") {
            return b.absoluteString
        }
        if tmdbVM.isLoading || !tmdbVM.hasFetched { return "" }
        return series.displayIcon
    }

    private var isFav: Bool {
        appState.syncService.isFavorite(series.seriesId)
    }
    private var isInWatchlist: Bool {
        appState.syncService.isInWatchlist(series.seriesId)
    }

    private var sortedSeasons: [String] {
        viewModel.episodes.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    /// Total seasons — prefer the IPTV provider, fall back to TMDB.
    private var displaySeasonCount: Int {
        if let s = series.numSeasons, let n = Int(s), n > 0 { return n }
        return tmdbVM.result?.numberOfSeasons ?? sortedSeasons.count
    }
    /// Total episodes (across all seasons) — TMDB only, since the
    /// provider doesn't always populate this until episodes are loaded.
    private var displayEpisodeCount: Int {
        tmdbVM.result?.numberOfEpisodes ?? viewModel.episodes.values.map(\.count).reduce(0, +)
    }

    private var displayYear: String {
        if let y = tmdbVM.result?.year { return "\(y)" }
        return ""
    }

    private func contentKey(for episode: Episode) -> String {
        "ep_\(episode.episodeId)"
    }
    private func isWatched(_ episode: Episode) -> Bool {
        appState.syncService.isWatched(contentKey: contentKey(for: episode))
    }
    private func progressEntry(for episode: Episode) -> WatchEntry? {
        appState.syncService.getProgress(contentKey: contentKey(for: episode))
    }

    /// Most recently watched / in-progress episode, used to drive the
    /// smart primary CTA on the hero. Walks `viewModel.episodes` once
    /// across every season, picking the one with the latest
    /// `updatedAt`. Returns nil when nothing has ever been started for
    /// this series.
    private var resumeTarget: (season: String, episode: Episode, entry: WatchEntry)? {
        var latest: (season: String, episode: Episode, entry: WatchEntry)?
        for (season, eps) in viewModel.episodes {
            for ep in eps {
                guard let entry = progressEntry(for: ep) else { continue }
                if latest == nil || entry.updatedAt > latest!.entry.updatedAt {
                    latest = (season, ep, entry)
                }
            }
        }
        return latest
    }

    /// First-ever-episode fallback when there's no progress yet.
    private var firstEpisode: (season: String, episode: Episode)? {
        guard let s = sortedSeasons.first, let eps = viewModel.episodes[s], let first = eps.first else {
            return nil
        }
        return (s, first)
    }

    /// Smart primary-CTA copy + action. Uses a named struct rather
    /// than a labelled tuple so the trailing-closure syntax doesn't
    /// confuse the parser.
    private struct PrimaryCTA {
        let label: String
        let icon: String
        let action: () -> Void
    }

    private var primaryCTA: PrimaryCTA? {
        if let r = resumeTarget {
            // In-progress / last-watched. Three sub-cases: still
            // unfinished → resume; finished and there's a next episode
            // → autoplay it; finished and last episode of the season →
            // "Revoir" from the start.
            if r.entry.isWatched {
                if let next = nextEpisode(after: r.episode, in: r.season) {
                    return PrimaryCTA(
                        label: "Lecture E\(next.episodeNum ?? 0)",
                        icon: "play.fill",
                        action: { playEpisode(next, season: r.season, force: true) }
                    )
                }
                return PrimaryCTA(
                    label: "Revoir",
                    icon: "play.fill",
                    action: { playEpisode(r.episode, season: r.season, force: true) }
                )
            }
            return PrimaryCTA(
                label: "Reprendre E\(r.episode.episodeNum ?? 0)",
                icon: "play.fill",
                action: { startPlayback(episode: r.episode, season: r.season, resumeFromMs: r.entry.positionMs) }
            )
        }
        if let f = firstEpisode {
            return PrimaryCTA(
                label: "Démarrer S\(f.season)E\(f.episode.episodeNum ?? 1)",
                icon: "play.fill",
                action: { playEpisode(f.episode, season: f.season, force: true) }
            )
        }
        return nil
    }

    private func nextEpisode(after ep: Episode, in season: String) -> Episode? {
        guard let eps = viewModel.episodes[season],
              let idx = eps.firstIndex(where: { $0.episodeId == ep.episodeId }),
              idx + 1 < eps.count
        else { return nil }
        return eps[idx + 1]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Padding.sectionGap) {
                hero
                seasonPicker
                episodesList
                castRow
            }
            .padding(.bottom, DS.Padding.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PlexBackdrop(imageUrl: backdropURL).ignoresSafeArea())
        .ignoresSafeArea()
        .task {
            await viewModel.loadEpisodes(for: series)
            if selectedSeason == nil { selectedSeason = sortedSeasons.first }
        }
        .task {
            await tmdbVM.load(rawTitle: series.name, kind: .tv)
        }
        // Whenever the TMDB id resolves *or* the user picks a different
        // season, fetch the per-episode meta for that season.
        .task(id: tmdbVM.result?.id) { await loadSeasonMeta(for: selectedSeason) }
        .onChange(of: selectedSeason) { _, newValue in
            Task { await loadSeasonMeta(for: newValue) }
        }
        .overlay {
            if viewModel.isLoadingEpisodes {
                ProgressView().tint(DS.Colour.textPrimary)
            }
        }
        .confirmationDialog(
            "Reprendre la lecture ?",
            isPresented: Binding(
                get: { pendingResumeEpisode != nil },
                set: { if !$0 { pendingResumeEpisode = nil; pendingResumeProgress = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingResumeProgress
        ) { progress in
            Button("Reprendre à \(Self.formatTime(progress.positionMs))") {
                if let ep = pendingResumeEpisode {
                    startPlayback(episode: ep, season: selectedSeason, resumeFromMs: progress.positionMs)
                }
                pendingResumeEpisode = nil
                pendingResumeProgress = nil
            }
            Button("Reprendre depuis le début") {
                if let ep = pendingResumeEpisode {
                    startPlayback(episode: ep, season: selectedSeason, resumeFromMs: nil)
                }
                pendingResumeEpisode = nil
                pendingResumeProgress = nil
            }
            Button("Annuler", role: .cancel) {
                pendingResumeEpisode = nil
                pendingResumeProgress = nil
            }
        }
    }

    // MARK: - Hero block

    private var hero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(series.name.cleanedTitleNoYear)
                .font(DS.Typography.displayHero)
                .foregroundColor(DS.Colour.textPrimary)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.6), radius: 12, y: 4)

            metadataStrip

            if !effectiveSynopsis.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(effectiveSynopsis)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colour.textSecondary)
                        .frame(maxHeight: 200, alignment: .topLeading)
                        .clipped()
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.85),
                                    .init(color: .clear, location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    if sourceSynopsis.isEmpty {
                        TMDBBadge()
                    }
                }
            } else if tmdbVM.isLoading {
                ProgressView().tint(DS.Colour.textTertiary)
            }

            primaryCTAs
        }
        .frame(maxWidth: 980, alignment: .leading)
        .padding(.horizontal, DS.Padding.screenHorizontal)
        .padding(.top, DS.Padding.sectionGap)
    }

    private var metadataStrip: some View {
        HStack(spacing: DS.Spacing.sm) {
            let rating = formattedRating(tmdbVM.result?.rating)
            if !rating.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(DS.Colour.warning)
                    Text(rating)
                }
            } else if let raw = series.rating, !raw.isEmpty, raw != "0" {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(DS.Colour.warning)
                    Text(raw)
                }
            }
            if !displayYear.isEmpty {
                separator
                Text(displayYear)
            }
            if displaySeasonCount > 0 {
                separator
                Text("\(displaySeasonCount) saison\(displaySeasonCount > 1 ? "s" : "")")
            }
            if displayEpisodeCount > 0 {
                separator
                Text("\(displayEpisodeCount) épisodes")
            }
        }
        .font(DS.Typography.bodyEmphasised)
        .foregroundColor(DS.Colour.textSecondary)
    }

    private var separator: some View {
        Text("·").foregroundColor(DS.Colour.textTertiary)
    }

    // MARK: - CTA row

    private var primaryCTAs: some View {
        HStack(spacing: DS.Spacing.md) {
            if let cta = primaryCTA {
                Button(action: cta.action) {
                    Label(cta.label, systemImage: cta.icon)
                }
                .buttonStyle(PrimaryHeroButton())
            }

            Button {
                appState.syncService.toggleFavorite(.from(series: series))
            } label: {
                Label {
                    Text(isFav ? "Retirer" : "Favori")
                } icon: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .symbolEffect(.bounce, value: isFav)
                }
            }
            .buttonStyle(GhostHeroButton(activeTint: DS.Colour.accentWarm, isActive: isFav))

            Button {
                appState.syncService.toggleWatchlist(.from(series: series))
            } label: {
                Label {
                    Text(isInWatchlist ? "Retirer" : "À regarder")
                } icon: {
                    Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                        .symbolEffect(.bounce, value: isInWatchlist)
                }
            }
            .buttonStyle(GhostHeroButton(activeTint: DS.Colour.accent, isActive: isInWatchlist))
        }
        .padding(.top, DS.Spacing.md)
    }

    // MARK: - Season picker

    @ViewBuilder
    private var seasonPicker: some View {
        if sortedSeasons.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(sortedSeasons, id: \.self) { season in
                        SeasonChip(
                            season: season,
                            watched: countWatchedEpisodes(in: season),
                            total: viewModel.episodes[season]?.count ?? 0,
                            isSelected: selectedSeason == season
                        ) {
                            selectedSeason = season
                        }
                    }
                }
                .padding(.horizontal, DS.Padding.screenHorizontal)
            }
        }
    }

    private func countWatchedEpisodes(in season: String) -> Int {
        (viewModel.episodes[season] ?? []).filter { isWatched($0) }.count
    }

    // MARK: - Episodes list

    @ViewBuilder
    private var episodesList: some View {
        if let season = selectedSeason, let eps = viewModel.episodes[season] {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                if let n = Int(season) {
                    Text("Saison \(season)")
                        .font(DS.Typography.title1)
                        .foregroundColor(DS.Colour.textPrimary)
                        .padding(.horizontal, DS.Padding.screenHorizontal)
                        .accessibilityHidden(loadingSeason == n)
                }
                LazyVStack(spacing: DS.Spacing.sm) {
                    ForEach(eps) { episode in
                        EpisodeRow(
                            series: series,
                            episode: episode,
                            season: season,
                            tmdbMeta: tmdbMetaFor(season: season, episode: episode),
                            watched: isWatched(episode),
                            progress: progressEntry(for: episode)?.progress ?? 0,
                            onTap: { playEpisode(episode, season: season, force: false) },
                            onMarkWatched: {
                                appState.syncService.markAsWatched(
                                    contentKey: contentKey(for: episode),
                                    title: episode.displayTitle
                                )
                            },
                            onMarkUnwatched: {
                                appState.syncService.markAsUnwatched(
                                    contentKey: contentKey(for: episode)
                                )
                            },
                            onMarkPreviousWatched: { markPreviousAsWatched(through: episode, in: season) }
                        )
                    }
                }
            }
        }
    }

    private func tmdbMetaFor(season: String, episode: Episode) -> TMDBService.EpisodeMeta? {
        guard let s = Int(season), let e = episode.episodeNum else { return nil }
        return seasonMeta[s]?[e]
    }

    @MainActor
    private func loadSeasonMeta(for season: String?) async {
        guard let season, let n = Int(season),
              let tmdbId = tmdbVM.result?.id, tmdbId > 0
        else { return }
        if seasonMeta[n] != nil { return } // already loaded
        loadingSeason = n
        defer { loadingSeason = nil }
        let metas = await TMDBService.shared.fetchSeason(tmdbId: tmdbId, season: n)
        guard !metas.isEmpty else { return }
        var dict: [Int: TMDBService.EpisodeMeta] = [:]
        for m in metas { dict[m.episodeNumber] = m }
        seasonMeta[n] = dict
    }

    // MARK: - Cast row

    @ViewBuilder
    private var castRow: some View {
        if let tmdb = tmdbVM.result, !tmdb.cast.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Distribution")
                        .font(DS.Typography.title1)
                        .foregroundColor(DS.Colour.textPrimary)
                    TMDBBadge()
                }
                .padding(.horizontal, DS.Padding.screenHorizontal)

                TMDBCastRow(cast: tmdb.cast)
            }
        }
    }

    // MARK: - Actions

    /// Tap an episode row. `force == true` skips the resume dialog —
    /// used by the smart hero CTA which already encodes the user's
    /// intent.
    private func playEpisode(_ episode: Episode, season: String?, force: Bool) {
        let key = contentKey(for: episode)
        let saved = appState.syncService.getProgress(contentKey: key)
        if !force, let saved, saved.positionMs > 10_000, !saved.isWatched {
            pendingResumeEpisode = episode
            pendingResumeProgress = saved
            return
        }
        startPlayback(episode: episode, season: season, resumeFromMs: nil)
    }

    private func startPlayback(episode: Episode, season: String?, resumeFromMs: Int?) {
        markPreviousAsWatched(before: episode, in: season ?? selectedSeason)
        guard let url = api.seriesStreamUrl(
            episodeId: episode.episodeId,
            extension: episode.containerExtension
        ) else { return }
        let key = contentKey(for: episode)
        // Episode rows from Xtream don't carry their own cover — seed
        // with the series poster, then upgrade to the per-episode TMDB
        // still in the background once it lands.
        let activeSeason = season ?? selectedSeason
        PlayerPresenter.playVOD(
            url: url,
            title: episode.displayTitle,
            resumeFromMs: resumeFromMs,
            contentKey: key,
            coverUrl: series.displayIcon,
            seriesId: series.seriesId
        )
        upgradeEpisodeCover(episode: episode, season: activeSeason, contentKey: key)
    }

    /// Fire-and-forget TMDB lookup for the episode's `still_path`.
    private func upgradeEpisodeCover(episode: Episode, season: String?, contentKey: String) {
        guard let seasonStr = season, let seasonNum = Int(seasonStr) else { return }
        guard let episodeNum = episode.episodeNum else { return }
        let seriesName = series.name

        Task.detached(priority: .utility) { [appState] in
            guard let result = await TMDBService.shared.enrich(rawTitle: seriesName, kind: .tv) else { return }
            guard let url = await TMDBService.shared.fetchEpisodeStill(
                tmdbId: result.id,
                season: seasonNum,
                episode: episodeNum
            ) else { return }
            await MainActor.run {
                appState.syncService.updateCoverUrl(contentKey: contentKey, url.absoluteString)
            }
        }
    }

    private static func formatTime(_ ms: Int) -> String {
        let total = ms / 1000
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    /// Mark all earlier episodes in the active season as watched (only
    /// those without meaningful progress, so we don't squash a user
    /// who's actively partway through one).
    private func markPreviousAsWatched(before episode: Episode, in season: String?) {
        guard let season,
              let eps = viewModel.episodes[season],
              let idx = eps.firstIndex(where: { $0.episodeId == episode.episodeId }),
              idx > 0
        else { return }
        for i in 0..<idx {
            let prev = eps[i]
            let key = contentKey(for: prev)
            guard let existing = appState.syncService.getProgress(contentKey: key) else {
                appState.syncService.markAsWatched(contentKey: key, title: prev.displayTitle)
                continue
            }
            if existing.positionMs < 30_000 {
                appState.syncService.markAsWatched(contentKey: key, title: prev.displayTitle)
            }
        }
    }

    /// Mark all episodes up to and including [episode] in the season as watched.
    private func markPreviousAsWatched(through episode: Episode, in season: String) {
        guard let eps = viewModel.episodes[season],
              let idx = eps.firstIndex(where: { $0.episodeId == episode.episodeId })
        else { return }
        for i in 0...idx {
            let e = eps[i]
            appState.syncService.markAsWatched(
                contentKey: contentKey(for: e),
                title: e.displayTitle
            )
        }
    }
}

// MARK: - Episode row

/// Single row in the episodes list — TMDB still on the left, title +
/// synopsis on the right, mini progress bar below the title for
/// in-progress episodes. Whole row is one focusable button.
private struct EpisodeRow: View {
    let series: SeriesItem
    let episode: Episode
    let season: String
    let tmdbMeta: TMDBService.EpisodeMeta?
    let watched: Bool
    let progress: Double
    let onTap: () -> Void
    let onMarkWatched: () -> Void
    let onMarkUnwatched: () -> Void
    let onMarkPreviousWatched: () -> Void

    var body: some View {
        Button(action: onTap) {
            EpisodeRowContent(
                series: series,
                episode: episode,
                season: season,
                tmdbMeta: tmdbMeta,
                watched: watched,
                progress: progress
            )
        }
        .buttonStyle(EpisodeRowButtonStyle())
        .contextMenu {
            if watched {
                Button(action: onMarkUnwatched) {
                    Label("Marquer non vu", systemImage: "xmark.circle")
                }
            } else {
                Button(action: onMarkWatched) {
                    Label("Marquer vu", systemImage: "checkmark.circle")
                }
            }
            Button(action: onMarkPreviousWatched) {
                Label("Marquer précédents comme vus", systemImage: "checklist")
            }
        }
    }
}

/// Row body — extracted so we can read `\.isFocused` from inside and
/// scale only the still image (not the whole row). Same pattern used
/// in the Continue Watching cards.
private struct EpisodeRowContent: View {
    let series: SeriesItem
    let episode: Episode
    let season: String
    let tmdbMeta: TMDBService.EpisodeMeta?
    let watched: Bool
    let progress: Double

    @Environment(\.isFocused) private var isFocused

    /// Compose the displayed title — prefer the cleaner TMDB episode
    /// name when present, fall back on the IPTV provider's title.
    private var titleLine: String {
        let raw = tmdbMeta?.name ?? episode.title ?? episode.displayTitle
        return raw.strippingProviderTag
    }

    /// "S03E07" prefix shown next to the title.
    private var episodePrefix: String {
        let s = Int(season) ?? 0
        let e = episode.episodeNum ?? 0
        return String(format: "S%02dE%02d", s, e)
    }

    private var synopsis: String {
        tmdbMeta?.overview ?? ""
    }

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.md) {
            still
                .scaleEffect(isFocused ? 1.04 : 1.0)
                .shadow(color: .black.opacity(isFocused ? 0.55 : 0), radius: 18, y: 8)
                .animation(DS.Focus.animation, value: isFocused)

            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(episodePrefix)
                        .font(DS.Typography.label)
                        .foregroundColor(DS.Colour.accentLight)
                    Text(titleLine)
                        .font(DS.Typography.title3)
                        .foregroundColor(watched ? DS.Colour.textTertiary : DS.Colour.textPrimary)
                        .lineLimit(1)
                }

                if !synopsis.isEmpty {
                    Text(synopsis)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colour.textSecondary)
                        .lineLimit(2)
                }

                if !watched, progress > 0.005, progress < 0.95 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15)).frame(height: 4)
                            Capsule().fill(DS.Colour.accent).frame(width: geo.size.width * progress, height: 4)
                        }
                    }
                    .frame(height: 4)
                    .frame(maxWidth: 480)
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            // Trailing icon — watched check or play indicator.
            Image(systemName: watched ? "checkmark.circle.fill" : "play.circle.fill")
                .font(.title2)
                .foregroundColor(watched ? DS.Colour.success : DS.Colour.textPrimary.opacity(0.85))
                .padding(.top, 4)
        }
        .padding(.vertical, DS.Spacing.sm)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                .fill(isFocused ? Color.white.opacity(0.08) : Color.clear)
        )
        .padding(.horizontal, DS.Padding.screenHorizontal)
    }

    @ViewBuilder
    private var still: some View {
        let placeholder = RoundedRectangle(cornerRadius: DS.Radius.card)
            .fill(DS.Colour.surface)
            .overlay(
                Image(systemName: "tv")
                    .font(.title2)
                    .foregroundColor(DS.Colour.textTertiary)
            )

        if let url = tmdbMeta?.stillURL() {
            KFImage(url)
                .resizable()
                .placeholder { placeholder }
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: 220, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        } else if let cover = URL(string: series.displayIcon) {
            // Fallback to the series poster if TMDB has no per-episode
            // still — at least it's not a flat grey rectangle.
            KFImage(cover)
                .resizable()
                .placeholder { placeholder }
                .aspectRatio(16/9, contentMode: .fill)
                .frame(width: 220, height: 124)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
        } else {
            placeholder.frame(width: 220, height: 124)
        }
    }
}

/// Plain button style — no tvOS card chrome (the row content already
/// renders its own focus background). Keeps press feedback subtle.
private struct EpisodeRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Season chip

private struct SeasonChip: View {
    let season: String
    let watched: Int
    let total: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("Saison \(season)")
                    .fontWeight(isSelected ? .semibold : .regular)
                if total > 0 && watched == total {
                    Image(systemName: "checkmark.circle.fill")
                } else if watched > 0 {
                    Text("\(watched)/\(total)")
                        .font(DS.Typography.caption)
                        .opacity(0.85)
                }
            }
        }
        .buttonStyle(SeasonChipButtonStyle(
            isSelected: isSelected,
            isComplete: total > 0 && watched == total
        ))
    }
}

private struct SeasonChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isComplete: Bool

    @Environment(\.isFocused) private var isFocused

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.bodyEmphasised)
            .foregroundColor(textColor)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.xs)
            .background(background)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? DS.Focus.chipScale : 1.0))
            .animation(DS.Focus.animation, value: isFocused)
    }

    private var textColor: Color {
        if isFocused { return .black }
        if isComplete { return DS.Colour.success }
        return isSelected ? DS.Colour.textPrimary : DS.Colour.textSecondary
    }

    @ViewBuilder
    private var background: some View {
        if isFocused {
            Color.white
        } else if isSelected {
            DS.Colour.accent
        } else {
            Color.white.opacity(0.10)
        }
    }
}
