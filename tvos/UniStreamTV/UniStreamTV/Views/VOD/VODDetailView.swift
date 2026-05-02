import SwiftUI
@preconcurrency import AVKit
import Kingfisher

/// VOD movie detail — poster, info, play button.
/// Player is presented via AVPlayerViewController (UIKit) for proper tvOS behavior.
struct VODDetailView: View {
    let item: VodItem
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState
    @State private var tmdbVM = TMDBViewModel()

    private var contentKey: String { "vod_\(item.streamId)" }

    private var sourceSynopsis: String {
        item.plot ?? item.description ?? ""
    }
    private var effectiveSynopsis: String {
        if !sourceSynopsis.isEmpty { return sourceSynopsis }
        return tmdbVM.result?.overview ?? ""
    }
    private var backdropURL: String {
        if let b = tmdbVM.result?.backdropURL(size: "original") {
            return b.absoluteString
        }
        // While TMDB is still loading, keep the backdrop empty so PlexBackdrop
        // stays plain dark — avoids flashing the low-res source poster.
        if tmdbVM.isLoading || !tmdbVM.hasFetched {
            return ""
        }
        return item.displayIcon
    }

    private var isFav: Bool {
        appState.syncService.isFavorite(item.streamId)
    }

    private var isInWatchlist: Bool {
        appState.syncService.isInWatchlist(item.streamId)
    }

    private var isWatched: Bool {
        appState.syncService.isWatched(contentKey: contentKey)
    }

    private var savedProgress: WatchEntry? {
        appState.syncService.getProgress(contentKey: contentKey)
    }

    var body: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 50) {
                // Poster
                KFImage(URL(string: item.displayIcon))
                    .resizable()
                    .placeholder {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(hex: 0x161230))
                            .overlay {
                                Image(systemName: "film")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.3))
                            }
                    }
                    .aspectRatio(2/3, contentMode: .fit)
                    .frame(width: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                // Info
                VStack(alignment: .leading, spacing: 20) {
                    Text(item.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    if let rating = item.rating, !rating.isEmpty, rating != "0" {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text(rating)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }

                    // Synopsis — fall back to TMDB when the source has none.
                    if !effectiveSynopsis.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(effectiveSynopsis)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.75))
                                .lineLimit(8)
                            if sourceSynopsis.isEmpty && !effectiveSynopsis.isEmpty {
                                TMDBBadge()
                            }
                        }
                    } else if tmdbVM.isLoading {
                        ProgressView()
                            .tint(.white.opacity(0.6))
                    }

                    // Watched badge
                    if isWatched {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Déjà vu")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        }
                    }

                    // Progress bar if resume available (and not marked watched)
                    if let progress = savedProgress, !isWatched {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: progress.progress)
                                .tint(Color(hex: 0x1B6B8A))
                            Text("Reprendre à \(formatTime(progress.positionMs))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                        .frame(maxWidth: 400)
                    }

                    Spacer()

                    // Primary actions
                    HStack(spacing: 20) {
                        Button {
                            play()
                        } label: {
                            Label(
                                isWatched ? "Revoir" : (savedProgress != nil ? "Reprendre" : "Regarder"),
                                systemImage: "play.fill"
                            )
                            .font(.headline)
                        }

                        Button {
                            appState.syncService.toggleFavorite(.from(vod: item))
                        } label: {
                            Label {
                                Text(isFav ? "Retirer" : "Favori")
                            } icon: {
                                Image(systemName: isFav ? "heart.fill" : "heart")
                                    .symbolEffect(.bounce, value: isFav)
                            }
                        }
                        .tint(isFav ? .red : .gray)

                        Button {
                            appState.syncService.toggleWatchlist(.from(vod: item))
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

                    // Secondary actions
                    HStack(spacing: 20) {
                        Button {
                            if isWatched {
                                appState.syncService.markAsUnwatched(contentKey: contentKey)
                            } else {
                                appState.syncService.markAsWatched(contentKey: contentKey, title: item.name)
                            }
                        } label: {
                            Label(
                                isWatched ? "Marquer non vu" : "Marquer vu",
                                systemImage: isWatched ? "xmark.circle" : "checkmark.circle"
                            )
                            .font(.subheadline)
                        }

                        // Add to collection menu (Premium)
                        if FeatureAccess.canUse(.collections, account: appState.authService.cachedAccountInfo) {
                            Menu {
                                ForEach(appState.collectionsService.collections(for: "movie")) { collection in
                                    Button {
                                        appState.collectionsService.addToCollection(
                                            collectionId: collection.id,
                                            item: .from(vod: item)
                                        )
                                    } label: {
                                        Label(collection.name, systemImage: "folder")
                                    }
                                }
                            } label: {
                                Label("Collection", systemImage: "folder.badge.plus")
                                    .font(.subheadline)
                            }
                            .disabled(appState.collectionsService.collections.isEmpty)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(80)

            // TMDB cast row (below the hero) — only shown when we have data.
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
        .background(PlexBackdrop(imageUrl: backdropURL))
        .task {
            await tmdbVM.load(rawTitle: item.name, kind: .movie)
        }
    }

    private func play() {
        guard let url = api.vodStreamUrl(streamId: item.streamId, extension: item.containerExtension) else { return }
        PlayerPresenter.playVOD(
            url: url,
            title: item.name,
            resumeFromMs: savedProgress?.positionMs,
            contentKey: contentKey
        )
    }

    private func formatTime(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
