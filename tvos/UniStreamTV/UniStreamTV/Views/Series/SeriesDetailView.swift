import SwiftUI
@preconcurrency import AVKit
import Kingfisher

/// Series detail with season/episode picker.
/// Player is presented via AVPlayerViewController (UIKit).
struct SeriesDetailView: View {
    let series: SeriesItem
    @Bindable var viewModel: SeriesViewModel
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState
    @State private var selectedSeason: String?
    @State private var tmdbVM = TMDBViewModel()
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

    private func contentKey(for episode: Episode) -> String {
        "ep_\(episode.episodeId)"
    }

    private func isWatched(_ episode: Episode) -> Bool {
        appState.syncService.isWatched(contentKey: contentKey(for: episode))
    }

    private func progress(for episode: Episode) -> Double {
        appState.syncService.getProgress(contentKey: contentKey(for: episode))?.progress ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header
                seasonPicker
                episodesList
                // TMDB cast row (below the episodes list).
                if let tmdb = tmdbVM.result, !tmdb.cast.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 10) {
                            Text("Distribution")
                                .font(.title3.weight(.bold))
                                .foregroundColor(.white)
                            TMDBBadge()
                        }
                        .padding(.horizontal, 40)
                        TMDBCastRow(cast: tmdb.cast)
                    }
                    .padding(.bottom, 40)
                }
            }
            .padding(.vertical, 40)
        }
        .background(PlexBackdrop(imageUrl: backdropURL))
        .task {
            await viewModel.loadEpisodes(for: series)
            selectedSeason = sortedSeasons.first
        }
        .task {
            await tmdbVM.load(rawTitle: series.name, kind: .tv)
        }
        .overlay {
            if viewModel.isLoadingEpisodes {
                ProgressView()
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
                    startPlayback(episode: ep, resumeFromMs: progress.positionMs)
                }
                pendingResumeEpisode = nil
                pendingResumeProgress = nil
            }
            Button("Reprendre depuis le début") {
                if let ep = pendingResumeEpisode {
                    startPlayback(episode: ep, resumeFromMs: nil)
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

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top, spacing: 40) {
            KFImage(URL(string: series.displayIcon))
                .resizable()
                .placeholder {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(hex: 0x161230))
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 220)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 12) {
                Text(series.name)
                    .font(.title2)
                    .fontWeight(.bold)

                if let seasons = series.numSeasons {
                    Text("\(seasons) saison(s)")
                        .foregroundColor(.secondary)
                }

                if let rating = series.rating, !rating.isEmpty, rating != "0" {
                    HStack {
                        Image(systemName: "star.fill").foregroundColor(.yellow)
                        Text(rating)
                    }
                }

                // Synopsis — fall back to TMDB when the source has none.
                if !effectiveSynopsis.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(effectiveSynopsis)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(5)
                        if sourceSynopsis.isEmpty {
                            TMDBBadge()
                        }
                    }
                } else if tmdbVM.isLoading {
                    ProgressView().tint(.white.opacity(0.6))
                }

                HStack(spacing: 12) {
                    Button {
                        appState.syncService.toggleFavorite(.from(series: series))
                    } label: {
                        Label {
                            Text(isFav ? "Retirer des favoris" : "Ajouter aux favoris")
                        } icon: {
                            Image(systemName: isFav ? "heart.fill" : "heart")
                                .symbolEffect(.bounce, value: isFav)
                        }
                    }
                    .tint(isFav ? .red : .gray)

                    Button {
                        appState.syncService.toggleWatchlist(.from(series: series))
                    } label: {
                        Label {
                            Text(isInWatchlist ? "Retirer de la liste" : "À regarder")
                        } icon: {
                            Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                                .symbolEffect(.bounce, value: isInWatchlist)
                        }
                    }
                    .tint(isInWatchlist ? Color(hex: 0x1B6B8A) : .gray)
                }
            }
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Season picker

    @ViewBuilder
    private var seasonPicker: some View {
        if sortedSeasons.count > 1 {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
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
                .padding(.horizontal, 40)
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
            LazyVStack(spacing: 8) {
                ForEach(eps) { episode in
                    episodeRow(episode)
                }
            }
        }
    }

    @ViewBuilder
    private func episodeRow(_ episode: Episode) -> some View {
        let watched = isWatched(episode)
        let prog = progress(for: episode)

        Button {
            playEpisode(episode)
        } label: {
            HStack(spacing: 16) {
                // Leading icon: watched check or play
                ZStack {
                    if watched {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.green)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.title3)
                            .foregroundColor(Color(hex: 0x1B6B8A))
                    }
                }
                .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(episode.displayTitle)
                        .foregroundColor(watched ? .white.opacity(0.5) : .white)

                    // Mini progress bar for in-progress episodes
                    if !watched && prog > 0.005 && prog < 0.95 {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                                    .frame(height: 3)
                                Capsule()
                                    .fill(Color(hex: 0x1B6B8A))
                                    .frame(width: geo.size.width * prog, height: 3)
                            }
                        }
                        .frame(height: 3)
                        .frame(maxWidth: 280)
                    }
                }

                Spacer()

                if watched {
                    Text("Vu")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, 8)
        }
        .buttonStyle(.tvRow)
        .contextMenu {
            if watched {
                Button {
                    appState.syncService.markAsUnwatched(contentKey: contentKey(for: episode))
                } label: {
                    Label("Marquer non vu", systemImage: "xmark.circle")
                }
            } else {
                Button {
                    appState.syncService.markAsWatched(
                        contentKey: contentKey(for: episode),
                        title: episode.displayTitle
                    )
                } label: {
                    Label("Marquer vu", systemImage: "checkmark.circle")
                }
            }

            Button {
                markPreviousAsWatched(through: episode)
            } label: {
                Label("Marquer précédents comme vus", systemImage: "checklist")
            }
        }
    }

    // MARK: - Actions

    private func playEpisode(_ episode: Episode) {
        let key = contentKey(for: episode)
        let saved = appState.syncService.getProgress(contentKey: key)
        // If there's meaningful progress (> 10s, < 95% — i.e. partially
        // watched), let the user pick between resuming and starting over
        // via the `confirmationDialog`. Otherwise launch directly.
        if let saved, saved.positionMs > 10_000, !saved.isWatched {
            pendingResumeEpisode = episode
            pendingResumeProgress = saved
            return
        }
        startPlayback(episode: episode, resumeFromMs: nil)
    }

    /// Actually launches playback. `resumeFromMs == nil` means start over.
    private func startPlayback(episode: Episode, resumeFromMs: Int?) {
        markPreviousAsWatched(before: episode)
        guard let url = api.seriesStreamUrl(
            episodeId: episode.episodeId,
            extension: episode.containerExtension
        ) else { return }
        PlayerPresenter.playVOD(
            url: url,
            title: episode.displayTitle,
            resumeFromMs: resumeFromMs,
            contentKey: contentKey(for: episode)
        )
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

    /// Mark all episodes before [episode] in the current season as watched.
    private func markPreviousAsWatched(before episode: Episode) {
        guard let season = selectedSeason,
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
            // Only auto-mark if barely started (< 30s of a short episode)
            if existing.positionMs < 30_000 {
                appState.syncService.markAsWatched(contentKey: key, title: prev.displayTitle)
            }
        }
    }

    /// Mark all episodes up to and including [episode] in the current season as watched.
    private func markPreviousAsWatched(through episode: Episode) {
        guard let season = selectedSeason,
              let eps = viewModel.episodes[season],
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
                        .font(.caption)
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

/// ButtonStyle has genuine access to focus via @Environment inside makeBody
/// (unlike a View nested as the Button's label).
private struct SeasonChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isComplete: Bool

    @Environment(\.isFocused) private var isFocused

    private let accent = Color(hex: 0x1B6B8A)

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(textColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(background)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.04 : 1.0))
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var textColor: Color {
        // Focus wins over everything — black text on a white pill.
        if isFocused { return .black }
        if isComplete { return .green }
        return isSelected ? .white : .white.opacity(0.85)
    }

    @ViewBuilder
    private var background: some View {
        if isFocused {
            Color.white
        } else if isSelected {
            accent
        } else {
            Color.white.opacity(0.12)
        }
    }
}
