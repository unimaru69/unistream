import SwiftUI

/// Displays user's favorites and "À regarder" watchlist as poster-card grids.
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

    private var liveItems: [FavoriteItem] { items.filter { $0.isLive } }
    private var movieItems: [FavoriteItem] { items.filter { $0.isMovie } }
    private var seriesItems: [FavoriteItem] { items.filter { $0.isSeries } }

    private let posterColumns = [
        GridItem(.adaptive(minimum: 200, maximum: 240), spacing: 32),
    ]
    private let wideColumns = [
        GridItem(.adaptive(minimum: 240, maximum: 280), spacing: 28),
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Type", selection: $selectedList) {
                    Label("Favoris", systemImage: "heart.fill").tag(ListKind.favorites)
                    Label("À regarder", systemImage: "bookmark.fill").tag(ListKind.watchlist)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 100)
                .padding(.top, 20)
                .padding(.bottom, 12)

                content
                    .animation(.easeInOut(duration: 0.25), value: selectedList)
                    .animation(.easeInOut(duration: 0.25), value: items.count)
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
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    if !liveItems.isEmpty {
                        section(title: "Live", count: liveItems.count) {
                            LazyVGrid(columns: wideColumns, spacing: 32) {
                                ForEach(liveItems) { item in
                                    FavoriteCard(item: item, listKind: selectedList)
                                }
                            }
                        }
                    }
                    if !movieItems.isEmpty {
                        section(title: "Films", count: movieItems.count) {
                            LazyVGrid(columns: posterColumns, spacing: 32) {
                                ForEach(movieItems) { item in
                                    FavoriteCard(item: item, listKind: selectedList)
                                }
                            }
                        }
                    }
                    if !seriesItems.isEmpty {
                        section(title: "Séries", count: seriesItems.count) {
                            LazyVGrid(columns: posterColumns, spacing: 32) {
                                ForEach(seriesItems) { item in
                                    FavoriteCard(item: item, listKind: selectedList)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 20)
            }
        }
    }

    @ViewBuilder
    private func section<Content: View>(title: String, count: Int, @ViewBuilder body: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            body()
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: selectedList == .favorites ? "heart" : "bookmark",
            title: selectedList == .favorites ? "Aucun favori" : "Aucun élément dans « À regarder »",
            description: selectedList == .favorites
                ? "Maintenez une chaîne pour l'ajouter, ou utilisez le bouton ♥ sur les films et séries."
                : "Utilisez le bouton Signet sur un film ou une série pour le garder de côté."
        )
    }
}

// MARK: - Favorite Card (poster / wide tile)

private struct FavoriteCard: View {
    let item: FavoriteItem
    let listKind: FavoritesView.ListKind
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            if item.isSeries {
                NavigationLink(value: seriesItem) { cardLabel }
                    .buttonStyle(.tvCard)
            } else if item.isMovie {
                NavigationLink(value: vodItem) { cardLabel }
                    .buttonStyle(.tvCard)
            } else if item.isLive {
                Button { playLive() } label: { cardLabel }
                    .buttonStyle(.tvCard)
            } else {
                cardLabel
            }
        }
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

    private var cardLabel: some View {
        FocusableCardLabel(
            title: item.name,
            imageUrl: item.displayIcon,
            aspectRatio: item.isLive ? 16/9 : 2/3,
            isLive: item.isLive
        )
        .frame(width: item.isLive ? 260 : 200)
    }

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
