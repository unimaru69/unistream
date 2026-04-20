import SwiftUI
import Kingfisher

/// Grid of channel cards — loads channels for the given category on appear.
struct ChannelGridView: View {
    let category: Category
    @Bindable var viewModel: LiveViewModel
    var showFavoritesOnly: Bool = false
    var isAllChannels: Bool = false

    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 40)
    ]

    /// Unique key that changes when the user picks a different category. Drives
    /// `.task(id:)` so the channel list re-loads on every switch.
    private var taskKey: String {
        if showFavoritesOnly { return "__favorites__" }
        if isAllChannels { return "__all__" }
        return category.categoryId
    }

    private var displayedChannels: [Channel] {
        if showFavoritesOnly {
            return viewModel.channels.filter { appState.syncService.isFavorite($0.streamId) }
        }
        return viewModel.channels
    }

    var body: some View {
        Group {
            if (viewModel.isLoadingChannels || viewModel.isLoadingAllChannels) && viewModel.channels.isEmpty {
                ProgressView("Chargement…")
            } else if let error = viewModel.error, viewModel.channels.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.yellow)
                    Text(error)
                        .foregroundColor(.secondary)
                    Button("Réessayer") {
                        Task { await reload() }
                    }
                }
            } else if displayedChannels.isEmpty {
                EmptyStateView(
                    icon: showFavoritesOnly ? "heart.slash" : "tv.slash",
                    title: showFavoritesOnly ? "Aucun favori" : "Aucune chaîne",
                    description: showFavoritesOnly
                        ? "Ajoute des chaînes aux favoris pour les retrouver ici."
                        : "Cette catégorie ne contient aucune chaîne pour le moment."
                )
            } else {
                ScrollView {
                    // Titre inline qui défile avec le contenu (évite la surimpression
                    // du grand titre de navigation sur les cartes lors du scroll).
                    HStack {
                        Text(
                            showFavoritesOnly ? "Favoris" :
                            isAllChannels ? "Toutes les chaînes" :
                            category.categoryName
                        )
                        .font(.largeTitle).bold()
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        Spacer()
                    }

                    LazyVGrid(columns: columns, spacing: 40) {
                        ForEach(displayedChannels) { channel in
                            Button {
                                playChannel(channel)
                            } label: {
                                FocusableCardLabel(
                                    title: channel.name,
                                    imageUrl: channel.displayIcon,
                                    hasBadge: channel.hasCatchup,
                                    subtitle: viewModel.currentProgram(for: channel.streamId)?.title,
                                    channelNumber: channel.num,
                                    isFavorite: appState.syncService.isFavorite(channel.streamId),
                                    isLive: viewModel.currentProgram(for: channel.streamId) != nil
                                )
                            }
                            .buttonStyle(.tvCard)
                            .contextMenu {
                                let isFav = appState.syncService.isFavorite(channel.streamId)
                                Button {
                                    appState.syncService.toggleFavorite(.from(channel: channel))
                                } label: {
                                    Label(isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                                          systemImage: isFav ? "heart.slash" : "heart")
                                }

                                // Add to collection (Premium)
                                if FeatureAccess.canUse(.collections, account: appState.authService.cachedAccountInfo),
                                   !appState.collectionsService.collections.isEmpty {
                                    Menu("Ajouter à une collection") {
                                        ForEach(appState.collectionsService.collections(for: "live")) { collection in
                                            Button {
                                                appState.collectionsService.addToCollection(
                                                    collectionId: collection.id,
                                                    item: .from(channel: channel)
                                                )
                                            } label: {
                                                Label(collection.name, systemImage: "folder")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(40)
                }
            }
        }
        // Pas de .navigationTitle ici — on utilise un titre inline dans le ScrollView
        // pour éviter le grand titre tvOS qui reste en surimpression lors du scroll.
        // Keyed on the category id so switching between two categories re-triggers
        // the load (otherwise SwiftUI reuses the view and .task never re-fires).
        .task(id: taskKey) {
            await reload()
        }
    }

    private func reload() async {
        if showFavoritesOnly || isAllChannels {
            // Use all channels for favorites/all views
            if viewModel.allChannels.isEmpty {
                await viewModel.loadAllChannels()
            }
            viewModel.setChannels(viewModel.allChannels)
            // Load EPG for visible subset
            let epgTargets = Array(displayedChannels.prefix(30))
            if !epgTargets.isEmpty {
                await viewModel.loadEpgForChannels(epgTargets)
            }
        } else {
            await viewModel.loadChannels(for: category)
        }
    }

    private func playChannel(_ channel: Channel) {
        // Launch with zapping support — swipe left/right to change channel
        guard let index = displayedChannels.firstIndex(where: { $0.streamId == channel.streamId }) else {
            // Fallback without zapping
            guard let url = appState.api.liveStreamUrl(streamId: channel.streamId) else { return }
            PlayerPresenter.playLive(url: url, title: channel.name, contentKey: "live_\(channel.streamId)")
            return
        }
        PlayerPresenter.playLiveWithZapping(
            channels: displayedChannels,
            startIndex: index,
            api: appState.api,
            timeshiftAllowed: FeatureAccess.canUse(.catchupReplay, account: appState.authService.cachedAccountInfo)
        )
    }
}
