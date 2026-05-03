import SwiftUI

/// Grid of VOD movies in a category.
struct VODGridView: View {
    let category: Category
    @Bindable var viewModel: VODViewModel
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState
    /// See SeriesGridView for the rationale — the focused card's cover
    /// is rendered behind the grid as a Plex-style backdrop.
    @FocusState private var focusedVodId: String?

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 30)
    ]

    private var focusedItem: VodItem? {
        guard let id = focusedVodId else { return nil }
        return viewModel.items.first(where: { $0.streamId == id })
    }

    var body: some View {
        Group {
            if viewModel.isLoadingItems && viewModel.items.isEmpty {
                ProgressView("Chargement…")
            } else if let error = viewModel.error, viewModel.items.isEmpty {
                ErrorRetryView(error: error) {
                    Task { await viewModel.loadItems(for: category) }
                }
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "film.stack",
                    title: "Aucun film",
                    description: "Cette catégorie ne contient aucun film pour le moment."
                )
            } else {
                ScrollView {
                    HStack {
                        Text(category.categoryName)
                            .font(.largeTitle).bold()
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                        Spacer()
                    }
                    LazyVGrid(columns: columns, spacing: 30) {
                        ForEach(viewModel.items) { item in
                            NavigationLink(value: item) {
                                FocusableCardLabel(
                                    title: item.name,
                                    imageUrl: item.displayIcon,
                                    aspectRatio: 2/3
                                )
                            }
                            .buttonStyle(.tvCard)
                            .focused($focusedVodId, equals: item.streamId)
                            .contextMenu {
                                // Favorite toggle
                                let isFav = appState.syncService.isFavorite(item.streamId)
                                Button {
                                    appState.syncService.toggleFavorite(.from(vod: item))
                                } label: {
                                    Label(isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                                          systemImage: isFav ? "heart.slash" : "heart")
                                }

                                // Add to collection (Premium)
                                if FeatureAccess.canUse(.collections, account: appState.authService.cachedAccountInfo),
                                   !appState.collectionsService.collections.isEmpty {
                                    Menu("Ajouter à une collection") {
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
                                    }
                                }
                            }
                        }
                    }
                    .padding(40)
                }
            }
        }
        .background {
            if let item = focusedItem {
                PlexBackdrop(imageUrl: item.displayIcon)
                    .id(item.streamId)
                    .transition(.opacity.animation(.easeInOut(duration: 0.4)))
            } else {
                DS.Colour.background.ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: focusedVodId)
        // Titre inline dans le ScrollView (voir ChannelGridView)
        .navigationDestination(for: VodItem.self) { item in
            VODDetailView(item: item, api: api)
        }
        // Keyed on category id — re-fires when the user picks a different category.
        .task(id: category.categoryId) {
            await viewModel.loadItems(for: category)
        }
    }
}
