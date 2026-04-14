import SwiftUI

/// Displays user's favorite channels, movies, and series — playable.
struct FavoritesView: View {
    @Environment(AppState.self) private var appState

    private var favorites: [FavoriteItem] {
        Array(appState.syncService.favorites.values).sorted { $0.name < $1.name }
    }

    private var liveItems: [FavoriteItem] { favorites.filter { $0.mode == "live" } }
    private var movieItems: [FavoriteItem] { favorites.filter { $0.mode == "movie" } }
    private var seriesItems: [FavoriteItem] { favorites.filter { $0.mode == "series" } }

    var body: some View {
        NavigationStack {
            Group {
                if favorites.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Aucun favori")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text("Maintenez une chaîne pour l'ajouter, ou utilisez le bouton ♥ sur les films et séries")
                            .font(.body)
                            .foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(60)
                } else {
                    List {
                        if !liveItems.isEmpty {
                            Section("Live (\(liveItems.count))") {
                                ForEach(liveItems) { item in
                                    FavoriteRow(item: item)
                                }
                            }
                        }

                        if !movieItems.isEmpty {
                            Section("Films (\(movieItems.count))") {
                                ForEach(movieItems) { item in
                                    FavoriteRow(item: item)
                                }
                            }
                        }

                        if !seriesItems.isEmpty {
                            Section("Séries (\(seriesItems.count))") {
                                ForEach(seriesItems) { item in
                                    FavoriteRow(item: item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Favoris")
        }
    }
}

struct FavoriteRow: View {
    let item: FavoriteItem
    @Environment(AppState.self) private var appState

    var body: some View {
        Button {
            playItem()
        } label: {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(Color(hex: 0x1B6B8A))
                    .frame(width: 30)
                Text(item.name)
                Spacer()
            }
        }
        .contextMenu {
            Button(role: .destructive) {
                appState.syncService.toggleFavorite(item)
            } label: {
                Label("Retirer des favoris", systemImage: "heart.slash")
            }
        }
    }

    private var iconName: String {
        switch item.mode {
        case "live": "tv"
        case "movie": "film"
        case "series": "tv.inset.filled"
        default: "star"
        }
    }

    private func playItem() {
        let api = appState.api
        switch item.mode {
        case "live":
            guard let sid = item.streamId,
                  let url = api.liveStreamUrl(streamId: sid) else { return }
            PlayerPresenter.playLive(url: url, title: item.name, contentKey: "live_\(sid)")
        case "movie":
            guard let sid = item.streamId,
                  let url = api.vodStreamUrl(streamId: sid, extension: item.containerExtension ?? "mp4") else { return }
            PlayerPresenter.playVOD(url: url, title: item.name, contentKey: "vod_\(sid)")
        case "series":
            // Series favorites can't be played directly — just show a hint
            break
        default:
            break
        }
    }
}
