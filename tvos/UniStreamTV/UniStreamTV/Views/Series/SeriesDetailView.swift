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

    private var sortedSeasons: [String] {
        viewModel.episodes.keys.sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                // Header
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

                        Button {
                            appState.syncService.toggleFavorite(.from(series: series))
                        } label: {
                            Label(isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                                  systemImage: isFav ? "heart.fill" : "heart")
                        }
                        .tint(isFav ? .red : .gray)
                    }
                }
                .padding(.horizontal, 40)

                // Season picker
                if sortedSeasons.count > 1 {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(sortedSeasons, id: \.self) { season in
                                Button("Saison \(season)") {
                                    selectedSeason = season
                                }
                                .buttonStyle(.bordered)
                                .tint(selectedSeason == season ? Color(hex: 0x1B6B8A) : .gray)
                            }
                        }
                        .padding(.horizontal, 40)
                    }
                }

                // Episodes list
                if let season = selectedSeason, let eps = viewModel.episodes[season] {
                    LazyVStack(spacing: 8) {
                        ForEach(eps) { episode in
                            Button {
                                playEpisode(episode)
                            } label: {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(Color(hex: 0x1B6B8A))
                                    Text(episode.displayTitle)
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.horizontal, 40)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.tvRow)
                        }
                    }
                }
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

    private func playEpisode(_ episode: Episode) {
        guard let url = api.seriesStreamUrl(episodeId: episode.episodeId, extension: episode.containerExtension) else { return }
        PlayerPresenter.playVOD(url: url, title: episode.displayTitle, contentKey: "ep_\(episode.episodeId)")
    }
}
