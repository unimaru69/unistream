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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    // Continue Watching
                    ContinueWatchingRow()

                    // Quick access to favorite channels
                    let liveFavs = appState.syncService.favorites.values
                        .filter { $0.mode == "live" }
                        .sorted { $0.name < $1.name }
                        .prefix(10)

                    if !liveFavs.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Chaînes favorites")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 50)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 24) {
                                    ForEach(Array(liveFavs), id: \.key) { fav in
                                        Button {
                                            if let sid = fav.streamId,
                                               let url = appState.api.liveStreamUrl(streamId: sid) {
                                                PlayerPresenter.playLive(url: url, title: fav.name, contentKey: "live_\(sid)")
                                            }
                                        } label: {
                                            FocusableCardLabel(
                                                title: fav.name,
                                                imageUrl: fav.displayIcon
                                            )
                                            .frame(width: 200)
                                        }
                                        .buttonStyle(.tvCard)
                                    }
                                }
                                .padding(.horizontal, 50)
                            }
                        }
                    }

                    // Catch-up replay (Premium only)
                    if FeatureAccess.canUse(.catchupReplay, account: appState.authService.cachedAccountInfo) {
                        CatchUpRow()
                    }

                    // Recently Added
                    RecentlyAddedRow()

                    // Empty state if nothing to show
                    if appState.syncService.watchProgress.isEmpty &&
                       appState.syncService.favorites.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles.tv")
                                .font(.system(size: 60))
                                .foregroundColor(Color(hex: 0x1B6B8A).opacity(0.5))
                            Text("Bienvenue sur UniStream")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("Parcourez les onglets Live, Films et Séries pour commencer")
                                .foregroundColor(.white.opacity(0.6))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 100)
                    }
                }
                .padding(.vertical, 40)
            }
            .navigationTitle("UniStream")
        }
    }
}
