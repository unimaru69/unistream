import SwiftUI
import AVKit
import Kingfisher

/// Series detail with season/episode picker.
/// Player is presented via AVPlayerViewController (UIKit).
struct SeriesDetailView: View {
    let series: SeriesItem
    @Bindable var viewModel: SeriesViewModel
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState
    @State private var selectedSeason: String?

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
            }
            .padding(.vertical, 40)
        }
        .task {
            await viewModel.loadEpisodes(for: series)
            selectedSeason = sortedSeasons.first
        }
        .overlay {
            if viewModel.isLoadingEpisodes {
                ProgressView()
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

                if let plot = series.plot ?? series.description, !plot.isEmpty {
                    Text(plot)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(5)
                }

                HStack(spacing: 12) {
                    Button {
                        appState.syncService.toggleFavorite(.from(series: series))
                    } label: {
                        Label(isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                              systemImage: isFav ? "heart.fill" : "heart")
                    }
                    .tint(isFav ? .red : .gray)

                    Button {
                        appState.syncService.toggleWatchlist(.from(series: series))
                    } label: {
                        Label(isInWatchlist ? "Retirer de la liste" : "À regarder",
                              systemImage: isInWatchlist ? "bookmark.fill" : "bookmark")
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
        // Before starting playback, mark previous episodes of the same season
        // as watched (if they weren't already). Mirrors Flutter behaviour.
        markPreviousAsWatched(before: episode)

        guard let url = api.seriesStreamUrl(
            episodeId: episode.episodeId,
            extension: episode.containerExtension
        ) else { return }
        PlayerPresenter.playVOD(
            url: url,
            title: episode.displayTitle,
            contentKey: contentKey(for: episode)
        )
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

// MARK: - Season chip (focus-aware)

private struct SeasonChip: View {
    let season: String
    let watched: Int
    let total: Int
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.isFocused) private var isFocused

    private var accent: Color { Color(hex: 0x1B6B8A) }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text("Saison \(season)")
                    .foregroundColor(textColor)
                    .fontWeight(isSelected ? .semibold : .regular)

                if total > 0 && watched == total {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(isFocused ? .black : .green)
                } else if watched > 0 {
                    Text("\(watched)/\(total)")
                        .font(.caption)
                        .foregroundColor(textColor.opacity(0.7))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(rowBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if isFocused { return .black }
        return isSelected ? .white : .white.opacity(0.8)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isFocused {
            Color.white
        } else if isSelected {
            accent
        } else {
            Color.white.opacity(0.12)
        }
    }
}
