import SwiftUI

/// Main tabbed navigation — tvOS top-shelf style.
struct HomeTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var hasLoadedLive = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // Home (Continue Watching + quick access)
            HomeContentView()
                .tabItem { Label("Accueil", systemImage: "house") }
                .tag(0)

            // Live TV (sidebar + grid split view)
            if let liveVM = appState.liveVM {
                LiveSplitView(viewModel: liveVM)
                    .tabItem { Label("Live", systemImage: "tv") }
                    .tag(1)
            }

            // Films (sidebar + grid split view)
            if let vodVM = appState.vodVM {
                VODSplitView(viewModel: vodVM, api: appState.api)
                    .tabItem { Label("Films", systemImage: "film") }
                    .tag(2)
            }

            // Séries (sidebar + grid split view)
            if let seriesVM = appState.seriesVM {
                SeriesSplitView(viewModel: seriesVM, api: appState.api)
                    .tabItem { Label("Séries", systemImage: "tv.inset.filled") }
                    .tag(3)
            }

            // Favorites
            FavoritesView()
                .tabItem { Label("Favoris", systemImage: "heart.fill") }
                .tag(4)

            // Search
            SearchView()
                .tabItem { Label("Recherche", systemImage: "magnifyingglass") }
                .tag(5)

            // Settings
            NavigationStack {
                SettingsView()
                    .navigationDestination(for: String.self) { dest in
                        switch dest {
                        case "history": HistoryView()
                        case "collections": PremiumGate(feature: .collections) { CollectionsView() }
                        case "parental": PremiumGate(feature: .parentalControls) { ParentalSettingsView() }
                        case "profiles": PremiumGate(feature: .multipleProfiles) { ProfileEditorView() }
                        default: EmptyView()
                        }
                    }
            }
            .tabItem { Label("Réglages", systemImage: "gear") }
            .tag(6)
        }
        .task {
            guard !hasLoadedLive else { return }
            hasLoadedLive = true
            await appState.liveVM?.loadCategories()
        }
        .overlay(alignment: .top) {
            if let alert = appState.reminderService.pendingAlert {
                EPGReminderToast(reminder: alert) {
                    appState.reminderService.dismissAlert()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: appState.reminderService.pendingAlert?.id)
                .padding(.top, 40)
            }
        }
    }
}

// MARK: - EPG Reminder Toast

private struct EPGReminderToast: View {
    let reminder: EPGReminder
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "bell.fill")
                .font(.title3)
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Rappel EPG")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.7))
                Text("\(reminder.programTitle)")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(reminder.channelName) — dans 5 min")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Button("OK", action: onDismiss)
                .font(.caption)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 80)
    }
}

/// Home tab content — Continue Watching + favorites summary.
struct HomeContentView: View {
    @Environment(AppState.self) private var appState
    /// Mirrors `HomeHeroBanner.currentItem` so we can render a full-screen
    /// wallpaper behind everything (under the floating tab bar, behind
    /// the rows below the hero) — Apple TV+ / Netflix home pattern.
    @State private var heroItem: RecentlyAddedItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Cinematic hero at the top — bleeds under the top
                    // tab bar (no top padding from the safe area).
                    HomeHeroBanner(displayedItem: $heroItem)
                        .ignoresSafeArea(edges: .top)

                    // Continue Watching
                    ContinueWatchingRow()
                        .focusSection()

                    // Quick access to favorite channels
                    let liveFavs = appState.syncService.favorites.values
                        .filter { $0.isLive }
                        .sorted { $0.name < $1.name }
                        .prefix(10)

                    if !liveFavs.isEmpty {
                        FavoritesShelf(title: "Chaînes favorites", items: Array(liveFavs))
                            .focusSection()
                    }

                    // Quick access to favorite movies
                    let movieFavs = appState.syncService.favorites.values
                        .filter { $0.isMovie }
                        .sorted { $0.name < $1.name }
                        .prefix(10)

                    if !movieFavs.isEmpty {
                        FavoritesShelf(title: "Films favoris", items: Array(movieFavs))
                            .focusSection()
                    }

                    // Quick access to favorite series
                    let seriesFavs = appState.syncService.favorites.values
                        .filter { $0.isSeries }
                        .sorted { $0.name < $1.name }
                        .prefix(10)

                    if !seriesFavs.isEmpty {
                        FavoritesShelf(title: "Séries favorites", items: Array(seriesFavs))
                            .focusSection()
                    }

                    // Catch-up replay (Premium only)
                    if FeatureAccess.canUse(.catchupReplay, account: appState.authService.cachedAccountInfo) {
                        CatchUpRow()
                            .focusSection()
                    }

                    // Recently Added
                    RecentlyAddedRow()
                        .focusSection()
                }
                .padding(.bottom, 40)
            }
            .background {
                ZStack {
                    DS.Colour.background.ignoresSafeArea()
                    if let item = heroItem {
                        HomeBackdropWallpaper(item: item)
                            .id(item.id)
                            .transition(.opacity.animation(.easeInOut(duration: 0.6)))
                    }
                }
                .ignoresSafeArea()
            }
            // Title omitted on purpose — the hero artwork carries the
            // brand on Accueil, so we don't want a separate "UniStream"
            // strip eating space above the hero.
            .toolbar(.hidden, for: .automatic)
            // Force the floating tab bar back on after popping detail
            // views (FavoritesShelf navigates into VOD/Series detail) —
            // tvOS otherwise caches the scrolled-collapsed state.
            .toolbar(.visible, for: .tabBar)
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
}

/// Full-screen wallpaper that mirrors whichever item the hero is currently
/// showing. Sits behind the entire Accueil tab (under the floating tab
/// bar, behind the rows below the hero) so the home feels immersive
/// instead of a hero rectangle floating on a flat dark page.
///
/// Pulls the TMDB backdrop the same way `HomeHeroBanner` does, and uses
/// `PlexBackdrop`'s blur/gradient treatment so the rows in front stay
/// readable.
private struct HomeBackdropWallpaper: View {
    let item: RecentlyAddedItem
    @State private var tmdbVM = TMDBViewModel()

    private var imageURL: String {
        if let b = tmdbVM.result?.backdropURL(size: "original") {
            return b.absoluteString
        }
        return item.displayIcon
    }

    private var kind: TMDBKind {
        item.id.hasPrefix("vod_") ? .movie : .tv
    }

    var body: some View {
        PlexBackdrop(imageUrl: imageURL, blurRadius: 22)
            .task(id: item.id) {
                await tmdbVM.load(rawTitle: item.name, kind: kind)
            }
    }
}

/// Horizontal carousel of favorite items shown on the Accueil tab.
///
/// Each card routes the user to the right action based on the favorite's
/// mode: live channels start playback, movies push the VOD detail view,
/// series push the SeriesDetail view. Keeps the home tab feeling like a
/// quick-access shelf rather than a duplicate of the Favoris tab.
private struct FavoritesShelf: View {
    let title: String
    let items: [FavoriteItem]
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 50)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(items, id: \.key) { fav in
                        card(for: fav)
                    }
                }
                .padding(.horizontal, 50)
            }
        }
    }

    @ViewBuilder
    private func card(for fav: FavoriteItem) -> some View {
        if fav.isLive {
            Button {
                if let sid = fav.resolvedStreamId,
                   let url = appState.api.liveStreamUrl(streamId: sid) {
                    PlayerPresenter.playLive(url: url, title: fav.name, contentKey: "live_\(sid)")
                }
            } label: {
                FocusableCardLabel(title: fav.name, imageUrl: fav.displayIcon)
                    .frame(width: 200)
            }
            .buttonStyle(.tvCard)
        } else if fav.isMovie {
            NavigationLink(value: vodItem(from: fav)) {
                FocusableCardLabel(
                    title: fav.name,
                    imageUrl: fav.displayIcon,
                    aspectRatio: 2/3
                )
                .frame(width: 180)
            }
            .buttonStyle(.tvCard)
        } else if fav.isSeries {
            NavigationLink(value: seriesItem(from: fav)) {
                FocusableCardLabel(
                    title: fav.name,
                    imageUrl: fav.displayIcon,
                    aspectRatio: 2/3
                )
                .frame(width: 180)
            }
            .buttonStyle(.tvCard)
        }
    }

    private func vodItem(from fav: FavoriteItem) -> VodItem {
        VodItem(json: [
            "stream_id": fav.streamId ?? fav.key,
            "name": fav.name,
            "cover": fav.cover ?? "",
            "stream_icon": fav.streamIcon ?? "",
            "category_id": fav.categoryId ?? "",
            "container_extension": fav.containerExtension ?? "mp4",
            "rating": fav.rating ?? "",
        ])
    }

    private func seriesItem(from fav: FavoriteItem) -> SeriesItem {
        SeriesItem(json: [
            "series_id": fav.seriesId ?? fav.key,
            "name": fav.name,
            "cover": fav.cover ?? "",
            "stream_icon": fav.streamIcon ?? "",
            "category_id": fav.categoryId ?? "",
            "rating": fav.rating ?? "",
        ])
    }
}
