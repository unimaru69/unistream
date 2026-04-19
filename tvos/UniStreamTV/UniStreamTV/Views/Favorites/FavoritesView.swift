import SwiftUI

/// Displays user's favorites and "À regarder" watchlist — playable.
struct FavoritesView: View {
    @Environment(AppState.self) private var appState

    enum ListKind: Hashable {
        case favorites
        case watchlist
    }

    @State private var selectedList: ListKind = .favorites

    private var favorites: [FavoriteItem] {
        Array(appState.syncService.favorites.values).sorted { $0.name < $1.name }
    }

    private var watchlist: [FavoriteItem] {
        Array(appState.syncService.watchlist.values).sorted { $0.name < $1.name }
    }

    private var items: [FavoriteItem] {
        selectedList == .favorites ? favorites : watchlist
    }

    private var liveItems: [FavoriteItem] { items.filter { $0.mode == "live" } }
    private var movieItems: [FavoriteItem] { items.filter { $0.mode == "movie" } }
    private var seriesItems: [FavoriteItem] { items.filter { $0.mode == "series" } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented toggle
                Picker("Type", selection: $selectedList) {
                    Label("Favoris", systemImage: "heart.fill").tag(ListKind.favorites)
                    Label("À regarder", systemImage: "bookmark.fill").tag(ListKind.watchlist)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 100)
                .padding(.top, 20)
                .padding(.bottom, 12)

                content
            }
            .navigationTitle(selectedList == .favorites ? "Favoris" : "À regarder")
            .navigationDestination(for: SeriesItem.self) { series in
                if let seriesVM = appState.seriesVM {
                    SeriesDetailView(series: series, viewModel: seriesVM, api: appState.api)
                }
            }
            .navigationDestination(for: VodItem.self) { vod in
                VODDetailView(item: vod, api: appState.api)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if items.isEmpty {
            emptyState
        } else {
            List {
                if !liveItems.isEmpty {
                    Section("Live (\(liveItems.count))") {
                        ForEach(liveItems) { item in
                            FavoriteRow(item: item, listKind: selectedList)
                        }
                    }
                }

                if !movieItems.isEmpty {
                    Section("Films (\(movieItems.count))") {
                        ForEach(movieItems) { item in
                            FavoriteRow(item: item, listKind: selectedList)
                        }
                    }
                }

                if !seriesItems.isEmpty {
                    Section("Séries (\(seriesItems.count))") {
                        ForEach(seriesItems) { item in
                            FavoriteRow(item: item, listKind: selectedList)
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedList == .favorites ? "heart" : "bookmark")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text(selectedList == .favorites ? "Aucun favori" : "Aucun élément dans « À regarder »")
                .font(.title3)
                .foregroundColor(.secondary)
            Text(selectedList == .favorites
                 ? "Maintenez une chaîne pour l'ajouter, ou utilisez le bouton ♥ sur les films et séries."
                 : "Utilisez le bouton Signet sur un film ou une série pour le garder de côté.")
                .font(.body)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FavoriteRow: View {
    let item: FavoriteItem
    let listKind: FavoritesView.ListKind
    @Environment(AppState.self) private var appState

    var body: some View {
        rowContent
            .contextMenu {
                switch listKind {
                case .favorites:
                    Button(role: .destructive) {
                        appState.syncService.toggleFavorite(item)
                    } label: {
                        Label("Retirer des favoris", systemImage: "heart.slash")
                    }
                case .watchlist:
                    Button(role: .destructive) {
                        appState.syncService.toggleWatchlist(item)
                    } label: {
                        Label("Retirer de « À regarder »", systemImage: "bookmark.slash")
                    }
                }
            }
    }

    @ViewBuilder
    private var rowContent: some View {
        switch item.mode {
        case "series":
            // Push SeriesDetailView via the enclosing NavigationStack
            NavigationLink(value: seriesItem) { label }
        case "movie":
            NavigationLink(value: vodItem) { label }
        case "live":
            Button { playLive() } label: { label }
        default:
            label
        }
    }

    private var label: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(Color(hex: 0x1B6B8A))
                .frame(width: 30)
            Text(item.name)
            Spacer()
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

    /// Reconstruct a SeriesItem from a FavoriteItem — enough fields for the
    /// detail view to load the episodes from the API.
    private var seriesItem: SeriesItem {
        SeriesItem(json: [
            "series_id": item.seriesId ?? item.key,
            "name": item.name,
            "cover": item.cover ?? "",
            "stream_icon": item.streamIcon ?? "",
            "category_id": item.categoryId ?? "",
            "rating": item.rating ?? "",
        ])
    }

    /// Reconstruct a VodItem from a FavoriteItem.
    private var vodItem: VodItem {
        VodItem(json: [
            "stream_id": item.streamId ?? item.key,
            "name": item.name,
            "cover": item.cover ?? "",
            "stream_icon": item.streamIcon ?? "",
            "category_id": item.categoryId ?? "",
            "container_extension": item.containerExtension ?? "mp4",
            "rating": item.rating ?? "",
        ])
    }

    private func playLive() {
        guard let sid = item.streamId,
              let url = appState.api.liveStreamUrl(streamId: sid) else { return }
        PlayerPresenter.playLive(url: url, title: item.name, contentKey: "live_\(sid)")
    }
}
