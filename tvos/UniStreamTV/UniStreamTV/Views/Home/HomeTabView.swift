import SwiftUI

/// Main tabbed navigation — tvOS top-shelf style.
struct HomeTabView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedTab = 0
    @State private var hasLoadedLive = false

    var body: some View {
        // The previous round added `.focusEffectDisabled()` on every
        // non-Settings tab to silence a pale-grey focus halo we'd
        // observed in the iOS simulator. Hardware testing on real
        // Apple TV showed the halo never actually rendered there —
        // it was a simulator-only artefact. Meanwhile the per-tab
        // modifier inserted an extra environment-mutating wrapper
        // between each tab's content and its `.tabItem`, which
        // correlated with the tab-switch flash the user observed
        // (system tab transition animating against an unstable
        // tree). Removing the modifiers entirely: visually identical
        // on hardware, hopefully fixes the flash.
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
        // No background paint here. Painting any colour at the TabView
        // root has compressed Settings's Form rows into "dark text on
        // dark substrate" no matter what value we tried (pure black,
        // surfaceElevated). The proper fix for the inter-tab flash
        // belongs at a layer below the SwiftUI hierarchy
        // (UIWindow.backgroundColor) — to be tackled in a follow-up.
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

/// What the home wallpaper currently shows. Carries just enough info
/// for `HomeBackdropWallpaper` to do its TMDB lookup — the source of
/// truth (favorite item, watch entry, hero rotation) is intentionally
/// erased so the wallpaper layer doesn't need to know about each row.
struct BackdropTarget: Equatable, Identifiable {
    let id: String
    let title: String
    let kind: TMDBKind
}

/// Home tab content — Continue Watching + favorites summary.
struct HomeContentView: View {
    @Environment(AppState.self) private var appState
    /// Mirrors `HomeHeroBanner.currentItem` so we can render a full-screen
    /// wallpaper behind everything (under the floating tab bar, behind
    /// the rows below the hero) — Apple TV+ / Netflix home pattern.
    @State private var heroItem: RecentlyAddedItem?
    /// Set by whichever row card the user has currently focused. Wins
    /// over the auto-rotating hero so the backdrop "follows" the user
    /// when they navigate down into Reprendre / Films favoris / Séries
    /// favorites — Plex-style.
    @State private var rowFocused: BackdropTarget?

    /// Resolved wallpaper source: focused card if any, falls back to
    /// the auto-rotated hero item.
    private var wallpaperTarget: BackdropTarget? {
        if let r = rowFocused { return r }
        guard let h = heroItem else { return nil }
        return BackdropTarget(
            id: h.id,
            title: h.name,
            kind: h.id.hasPrefix("vod_") ? .movie : .tv
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Padding.sectionGap) {
                    // Cinematic hero at the top — bleeds under the top
                    // tab bar (no top padding from the safe area).
                    HomeHeroBanner(displayedItem: $heroItem)
                        .ignoresSafeArea(edges: .top)

                    // Continue Watching
                    ContinueWatchingRow(rowFocused: $rowFocused)
                        .focusSection()

                    // Quick access to favorite channels
                    let liveFavs = appState.syncService.favorites.values
                        .filter { $0.isLive }
                        .sorted { $0.name < $1.name }
                        .prefix(10)

                    if !liveFavs.isEmpty {
                        FavoritesShelf(title: "Chaînes favorites", items: Array(liveFavs), rowFocused: $rowFocused)
                            .focusSection()
                    }

                    // Quick access to favorite movies
                    let movieFavs = appState.syncService.favorites.values
                        .filter { $0.isMovie }
                        .sorted { $0.name < $1.name }
                        .prefix(10)

                    if !movieFavs.isEmpty {
                        FavoritesShelf(title: "Films favoris", items: Array(movieFavs), rowFocused: $rowFocused)
                            .focusSection()
                    }

                    // Quick access to favorite series
                    let seriesFavs = appState.syncService.favorites.values
                        .filter { $0.isSeries }
                        .sorted { $0.name < $1.name }
                        .prefix(10)

                    if !seriesFavs.isEmpty {
                        FavoritesShelf(title: "Séries favorites", items: Array(seriesFavs), rowFocused: $rowFocused)
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
                    if let target = wallpaperTarget {
                        HomeBackdropWallpaper(target: target)
                            .id(target.id)
                            .transition(.opacity.animation(DS.Motion.slow))
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
    let target: BackdropTarget
    @State private var tmdbVM = TMDBViewModel()

    /// Only use the TMDB backdrop ("original" = ≥1280px wide on TMDB,
    /// matches our 1920×1080 viewport without scaling artefacts). The
    /// IPTV provider's `displayIcon` is a poster sized for thumbnails
    /// (~500px); stretched full-screen it reads as pixelated, especially
    /// for obscure films. Returning nil here keeps the wallpaper at
    /// `DS.Colour.background` — the hero foreground stays visible, just
    /// over a flat dark page instead of a degraded image.
    private var imageURL: String? {
        tmdbVM.result?.backdropURL(size: "original")?.absoluteString
    }

    var body: some View {
        // No blur on the home wallpaper — the hero is the only thing
        // most users see on Accueil before they scroll, so showing the
        // backdrop sharp keeps the page feeling cinematic. Plex-style
        // gradients (left-darken + bottom-fade) inside `PlexBackdrop`
        // continue to keep the title block readable over busy imagery.
        Group {
            if let url = imageURL {
                PlexBackdrop(imageUrl: url, blurRadius: 0)
            } else {
                DS.Colour.background.ignoresSafeArea()
            }
        }
        .task(id: target.id) {
            await tmdbVM.load(rawTitle: target.title, kind: target.kind)
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
    /// Optional — when supplied, each card pushes itself as the active
    /// `BackdropTarget` whenever it gains focus, so the home wallpaper
    /// "follows" the user's selection across rows.
    var rowFocused: Binding<BackdropTarget?>? = nil
    @Environment(AppState.self) private var appState
    /// Modal presentation drives instead of NavigationLink — see
    /// SeriesGridView for the rationale (TabView's tab bar collapses
    /// across push/pop and there's no public API on tvOS 17 to force
    /// it back on).
    @State private var presentedVod: VodItem?
    @State private var presentedSeries: SeriesItem?
    @FocusState private var focusedKey: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Typography.title1)
                .foregroundColor(DS.Colour.textPrimary)
                .padding(.horizontal, DS.Padding.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.lg) {
                    ForEach(items, id: \.key) { fav in
                        card(for: fav)
                            .focused($focusedKey, equals: fav.key)
                    }
                }
                .padding(.horizontal, DS.Padding.screenHorizontal)
            }
        }
        .onChange(of: focusedKey) { _, newKey in
            guard let key = newKey else {
                // Focus left the row entirely (user pressed Up to the
                // hero or Down to another section). Clear the
                // wallpaper target so the parent falls back on the
                // hero's auto-rotating item instead of staying stuck
                // on the last card we were on.
                rowFocused?.wrappedValue = nil
                return
            }
            guard let fav = items.first(where: { $0.key == key }) else { return }
            // Live channels rarely have rich TMDB backdrops; map them
            // through `.tv` for now — better than `.movie` and the
            // wallpaper falls back to flat black if no match.
            let kind: TMDBKind = fav.isMovie ? .movie : .tv
            rowFocused?.wrappedValue = BackdropTarget(
                id: "fav_\(fav.key)",
                title: fav.name,
                kind: kind
            )
        }
        .fullScreenCover(item: $presentedVod) { vod in
            VODDetailView(item: vod, api: appState.api)
        }
        .fullScreenCover(item: $presentedSeries) { series in
            if let seriesVM = appState.seriesVM {
                SeriesDetailView(series: series, viewModel: seriesVM, api: appState.api)
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
            Button {
                presentedVod = vodItem(from: fav)
            } label: {
                FocusableCardLabel(
                    title: fav.name,
                    imageUrl: fav.displayIcon,
                    aspectRatio: 2/3
                )
                .frame(width: 180)
            }
            .buttonStyle(.tvCard)
        } else if fav.isSeries {
            Button {
                presentedSeries = seriesItem(from: fav)
            } label: {
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
