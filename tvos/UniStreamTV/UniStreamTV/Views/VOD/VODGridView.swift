import SwiftUI

/// Grid of VOD movies in a category.
struct VODGridView: View {
    let category: Category
    @Bindable var viewModel: VODViewModel
    let api: XtreamAPIService
    /// Reported back to the parent so the backdrop can render full-screen
    /// (behind sidebar + tab bar). Optional — grid still works without it.
    var focusedItem: Binding<VodItem?>? = nil

    @Environment(AppState.self) private var appState
    @FocusState private var focusedVodId: String?
    @State private var presentedVod: VodItem?
    @State private var sortMode: CatalogSortMode = .default
    @State private var searchQuery: String = ""

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 30)
    ]

    /// Items after applying search filter + selected sort mode.
    private var displayedItems: [VodItem] {
        var items = viewModel.items
        let q = searchQuery.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            items = items.filter { $0.name.localizedCaseInsensitiveContains(q) }
        }
        let progress = appState.syncService.watchProgress
        switch sortMode {
        case .default:
            return items
        case .recent:
            return items.sorted { (a, b) in
                (a.added ?? a.lastModified ?? "") > (b.added ?? b.lastModified ?? "")
            }
        case .alphabetical:
            return items.sorted {
                $0.name.cleanedTitleNoYear.localizedCaseInsensitiveCompare(
                    $1.name.cleanedTitleNoYear) == .orderedAscending
            }
        case .unwatched:
            return items.filter { progress["vod_\($0.streamId)"] == nil }
        case .inProgress:
            return items.filter {
                guard let p = progress["vod_\($0.streamId)"]?.progress else { return false }
                return p > 0.005 && p < 0.95
            }
        }
    }

    /// Currently-focused VodItem — drives the bottom preview.
    private var focusedVod: VodItem? {
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
                gridContent
            }
        }
        .onChange(of: focusedVodId) { _, newId in
            guard let binding = focusedItem else { return }
            if let id = newId, let item = viewModel.items.first(where: { $0.streamId == id }) {
                binding.wrappedValue = item
            } else {
                binding.wrappedValue = nil
            }
        }
        .fullScreenCover(item: $presentedVod) { item in
            VODDetailView(item: item, api: api)
        }
        .task(id: category.categoryId) {
            await viewModel.loadItems(for: category)
        }
        .searchable(
            text: $searchQuery,
            prompt: "Rechercher dans \(category.categoryName)"
        )
    }

    @ViewBuilder
    private var gridContent: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(category.categoryName)
                            .font(.largeTitle).bold()
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                            .id("__top__")

                        // Sort chips — sit between the heading and the
                        // grid, scroll with the content so the user can
                        // get full vertical real estate when deep in
                        // the grid.
                        CatalogSortChips(selection: $sortMode)
                            .padding(.horizontal, 40)
                            .focusSection()

                        if displayedItems.isEmpty {
                            emptySearchResult
                        } else {
                            grid
                        }

                        // Bottom inset so the focus preview overlay
                        // doesn't cover the last row.
                        Color.clear.frame(height: 180)
                    }
                }
                .focusSection()

                // Mini-preview overlay — only visible when an item
                // is focused. Slides in/out smoothly.
                if let focused = focusedVod {
                    FocusedItemPreview(
                        rawTitle: focused.name,
                        coverUrl: focused.displayIcon,
                        providerRating: focused.rating,
                        kind: .movie
                    )
                    .id(focused.streamId)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(DS.Motion.standard, value: focusedVod?.streamId)
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    if let first = displayedItems.first?.streamId {
                        focusedVodId = first
                    }
                    withAnimation { proxy.scrollTo("__top__", anchor: .top) }
                }
            }
        }
    }

    @ViewBuilder
    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 30) {
            ForEach(displayedItems) { item in
                Button {
                    presentedVod = item
                } label: {
                    FocusableCardLabel(
                        title: item.name,
                        imageUrl: item.displayIcon,
                        aspectRatio: 2/3
                    )
                }
                .buttonStyle(.tvCard)
                .focused($focusedVodId, equals: item.streamId)
                .contextMenu {
                    let isFav = appState.syncService.isFavorite(item.streamId)
                    Button {
                        appState.syncService.toggleFavorite(.from(vod: item))
                    } label: {
                        Label(isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                              systemImage: isFav ? "heart.slash" : "heart")
                    }

                    let isInWl = appState.syncService.isInWatchlist(item.streamId)
                    Button {
                        appState.syncService.toggleWatchlist(.from(vod: item))
                    } label: {
                        Label(isInWl ? "Retirer de À regarder" : "Ajouter à À regarder",
                              systemImage: isInWl ? "bookmark.slash" : "bookmark")
                    }

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
        .padding(.horizontal, 40)
        .padding(.top, DS.Spacing.md)
    }

    private var emptySearchResult: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(DS.Colour.textTertiary)
            Text("Aucun résultat pour \"\(searchQuery)\"")
                .font(DS.Typography.body)
                .foregroundColor(DS.Colour.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DS.Spacing.xxl)
    }
}
