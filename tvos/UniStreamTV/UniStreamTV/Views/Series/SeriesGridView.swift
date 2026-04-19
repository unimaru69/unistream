import SwiftUI

/// Grid of series in a category.
struct SeriesGridView: View {
    let category: Category
    @Bindable var viewModel: SeriesViewModel
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 30)
    ]

    var body: some View {
        Group {
            if viewModel.isLoadingItems && viewModel.items.isEmpty {
                ProgressView("Chargement…")
            } else if viewModel.items.isEmpty {
                EmptyStateView(
                    icon: "tv.inset.filled",
                    title: "Aucune série",
                    description: "Cette catégorie ne contient aucune série pour le moment."
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
                            .contextMenu {
                                // Favorite toggle
                                let isFav = appState.syncService.isFavorite(item.seriesId)
                                Button {
                                    appState.syncService.toggleFavorite(.from(series: item))
                                } label: {
                                    Label(isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                                          systemImage: isFav ? "heart.slash" : "heart")
                                }

                                // Add to collection (Premium)
                                if FeatureAccess.canUse(.collections, account: appState.authService.cachedAccountInfo),
                                   !appState.collectionsService.collections.isEmpty {
                                    Menu("Ajouter à une collection") {
                                        ForEach(appState.collectionsService.collections(for: "series")) { collection in
                                            Button {
                                                appState.collectionsService.addToCollection(
                                                    collectionId: collection.id,
                                                    item: .from(series: item)
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
        // Titre inline dans le ScrollView (voir ChannelGridView)
        .navigationDestination(for: SeriesItem.self) { series in
            SeriesDetailView(series: series, viewModel: viewModel, api: api)
        }
        .task {
            await viewModel.loadItems(for: category)
        }
    }
}
