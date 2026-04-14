import SwiftUI
import AVKit
import Kingfisher

/// VOD movie detail — poster, info, play button.
/// Player is presented via AVPlayerViewController (UIKit) for proper tvOS behavior.
struct VODDetailView: View {
    let item: VodItem
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState

    private var isFav: Bool {
        appState.syncService.isFavorite(item.streamId)
    }

    private var savedProgress: WatchEntry? {
        appState.syncService.getProgress(contentKey: item.streamId)
    }

    var body: some View {
        ZStack {
            Color(hex: 0x0E0B1E).ignoresSafeArea()

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

                    if let plot = item.plot ?? item.description, !plot.isEmpty {
                        Text(plot)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(8)
                    }

                    // Progress bar if resume available
                    if let progress = savedProgress {
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

                    HStack(spacing: 20) {
                        Button {
                            play()
                        } label: {
                            Label(savedProgress != nil ? "Reprendre" : "Regarder", systemImage: "play.fill")
                                .font(.headline)
                        }

                        Button {
                            appState.syncService.toggleFavorite(.from(vod: item))
                        } label: {
                            Label(isFav ? "Retirer" : "Favori", systemImage: isFav ? "heart.fill" : "heart")
                        }
                        .tint(isFav ? .red : .gray)

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
                            }
                            .disabled(appState.collectionsService.collections.isEmpty)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(80)
        }
    }

    private func play() {
        guard let url = api.vodStreamUrl(streamId: item.streamId, extension: item.containerExtension) else { return }
        PlayerPresenter.playVOD(
            url: url,
            title: item.name,
            resumeFromMs: savedProgress?.positionMs,
            contentKey: "vod_\(item.streamId)"
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
