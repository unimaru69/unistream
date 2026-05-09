import SwiftUI
import Kingfisher

/// Grid of channel cards — loads channels for the given category on appear.
struct ChannelGridView: View {
    let category: Category
    @Bindable var viewModel: LiveViewModel
    var showFavoritesOnly: Bool = false
    var isAllChannels: Bool = false

    @Environment(AppState.self) private var appState
    @FocusState private var focusedChannelId: String?

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
            // Build the set from FavoriteItem.resolvedStreamId so legacy
            // entries whose `item_key` is "live:STREAMID" still match the
            // bare `streamId` exposed on `Channel`.
            let favIds = Set(appState.syncService.favorites.values
                .filter { $0.isLive }
                .compactMap { $0.resolvedStreamId })
            return viewModel.channels.filter { favIds.contains($0.streamId) }
        }
        return viewModel.channels
    }

    private var focusedChannel: Channel? {
        guard let id = focusedChannelId else { return nil }
        return displayedChannels.first(where: { $0.streamId == id })
    }

    private var canUseCatchup: Bool {
        FeatureAccess.canUse(.catchupReplay, account: appState.authService.cachedAccountInfo)
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
                gridContent
            }
        }
        .task(id: taskKey) {
            await reload()
        }
    }

    @ViewBuilder
    private var gridContent: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    // Inline title that scrolls with content (avoids the
                    // tvOS large-title overlay overdraw on the cards).
                    Text(
                        showFavoritesOnly ? "Favoris" :
                        isAllChannels ? "Toutes les chaînes" :
                        category.categoryName
                    )
                    .font(.largeTitle).bold()
                    .padding(.horizontal, 40)
                    .padding(.top, 20)

                    // Catch-up shelf — only for users with the replay
                    // feature; surfaces "what was on lately" without
                    // having to drill into a channel's EPG.
                    if canUseCatchup {
                        CatchUpRow()
                            .focusSection()
                    }

                    LazyVGrid(columns: columns, spacing: 40) {
                        ForEach(displayedChannels) { channel in
                            channelCard(channel)
                        }
                    }
                    .padding(.horizontal, 40)

                    // Bottom inset so the preview overlay doesn't cover
                    // the last grid row.
                    Color.clear.frame(height: 200)
                }
            }
            .focusSection()

            // Focused-channel preview — slides in/out as the focus
            // engine moves. TMDB-enriched programme image when one
            // resolves, otherwise channel logo fallback.
            if let focused = focusedChannel {
                LiveFocusedPreview(
                    channel: focused,
                    currentProgram: viewModel.currentProgram(for: focused.streamId),
                    nextProgram: viewModel.nextProgram(for: focused.streamId)
                )
                .id(focused.streamId)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(DS.Motion.standard, value: focusedChannel?.streamId)
    }

    @ViewBuilder
    private func channelCard(_ channel: Channel) -> some View {
        Button {
            playChannel(channel)
        } label: {
            let current = viewModel.currentProgram(for: channel.streamId)
            FocusableCardLabel(
                title: channel.name,
                imageUrl: channel.displayIcon,
                hasBadge: channel.hasCatchup,
                subtitle: current?.title,
                channelNumber: channel.num,
                isFavorite: appState.syncService.isFavorite(channel.streamId),
                isLive: current != nil,
                programmeProgress: current?.progress
            )
        }
        .buttonStyle(.tvCard)
        .focused($focusedChannelId, equals: channel.streamId)
        .contextMenu {
            let isFav = appState.syncService.isFavorite(channel.streamId)
            Button {
                appState.syncService.toggleFavorite(.from(channel: channel))
            } label: {
                Label(isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                      systemImage: isFav ? "heart.slash" : "heart")
            }

            let isInWl = appState.syncService.isInWatchlist(channel.streamId)
            Button {
                appState.syncService.toggleWatchlist(.from(channel: channel))
            } label: {
                Label(isInWl ? "Retirer de À regarder" : "Ajouter à À regarder",
                      systemImage: isInWl ? "bookmark.slash" : "bookmark")
            }

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

    private func reload() async {
        if showFavoritesOnly || isAllChannels {
            if viewModel.allChannels.isEmpty {
                await viewModel.loadAllChannels()
            }
            viewModel.setChannels(viewModel.allChannels)
            let epgTargets = Array(displayedChannels.prefix(30))
            if !epgTargets.isEmpty {
                await viewModel.loadEpgForChannels(epgTargets)
            }
        } else {
            await viewModel.loadChannels(for: category)
        }
    }

    private func playChannel(_ channel: Channel) {
        guard let index = displayedChannels.firstIndex(where: { $0.streamId == channel.streamId }) else {
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
