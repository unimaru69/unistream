import SwiftUI

/// Grid of series in a category.
struct SeriesGridView: View {
    let category: Category
    @Bindable var viewModel: SeriesViewModel
    let api: XtreamAPIService
    /// Reported back to the parent split view so the backdrop can render
    /// at full screen (behind sidebar + tab bar), not just behind the
    /// grid pane. Optional so the grid still works on its own.
    var focusedItem: Binding<SeriesItem?>? = nil

    @Environment(AppState.self) private var appState
    /// Tracks which series card the focus engine is currently on.
    @FocusState private var focusedSeriesId: String?

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
                // ScrollViewReader so we can programmatically scroll back
                // to the top when the user returns from the detail view
                // — that's what re-reveals the floating tab bar that the
                // tvOS TabView auto-hides when the grid is scrolled.
                ScrollViewReader { proxy in
                    ScrollView {
                    HStack {
                        Text(category.categoryName)
                            .font(.largeTitle).bold()
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                            .id("__top__")
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
                            .focused($focusedSeriesId, equals: item.seriesId)
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
                    // Re-scroll to the top AND reset focus to the first
                    // card whenever we re-appear (after a pop from
                    // SeriesDetailView). Just scrolling wasn't enough:
                    // the tvOS focus engine restores focus to the
                    // previously-clicked card right after our scroll and
                    // snaps the offset back, hiding the tab bar again.
                    // Forcing focus to the first item — after a small
                    // delay so we override the system's restoration —
                    // keeps focus near the top, which is what the
                    // TabView watches to decide whether to show the bar.
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(120))
                            if let first = viewModel.items.first?.seriesId {
                                focusedSeriesId = first
                            }
                            withAnimation { proxy.scrollTo("__top__", anchor: .top) }
                        }
                    }
                }
            }
        }
        // Cinematic backdrop fades in/out as the focus engine moves
        // across the grid. `animation(_:value:)` ties the opacity to
        // the focused id so a different cover crossfades in.
        // Push the focused item up to the parent split view so the
        // backdrop can render full-screen (behind sidebar + floating
        // tab bar). When the binding isn't supplied (grid used in
        // isolation), the parent simply doesn't render a backdrop.
        .onChange(of: focusedSeriesId) { _, newId in
            guard let binding = focusedItem else { return }
            if let id = newId, let item = viewModel.items.first(where: { $0.seriesId == id }) {
                binding.wrappedValue = item
            } else {
                binding.wrappedValue = nil
            }
        }
        // Titre inline dans le ScrollView (voir ChannelGridView)
        .navigationDestination(for: SeriesItem.self) { series in
            SeriesDetailView(series: series, viewModel: viewModel, api: api)
        }
        // Keyed on category id — re-fires when the user picks a different category.
        .task(id: category.categoryId) {
            await viewModel.loadItems(for: category)
        }
    }
}
