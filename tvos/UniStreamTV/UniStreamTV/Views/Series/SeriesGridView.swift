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
    @FocusState private var focusedSeriesId: String?
    @State private var presentedSeries: SeriesItem?
    @State private var sortMode: CatalogSortMode = .default
    @State private var searchQuery: String = ""

    private let columns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 30)
    ]

    /// Items after applying search filter + selected sort mode. Series
    /// progress is tracked per-episode (`ep_<id>`), so "non vus" means
    /// "no episode of this series has any progress" and "en cours"
    /// means "at least one episode is in progress".
    private var displayedItems: [SeriesItem] {
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
            return items.filter { series in
                !progress.contains { (_, entry) in
                    entry.seriesId == series.seriesId && entry.progress > 0.005
                }
            }
        case .inProgress:
            return items.filter { series in
                progress.contains { (_, entry) in
                    entry.seriesId == series.seriesId
                        && entry.progress > 0.005
                        && entry.progress < 0.95
                }
            }
        }
    }

    /// Currently-focused SeriesItem — drives the bottom preview.
    private var focusedSeries: SeriesItem? {
        guard let id = focusedSeriesId else { return nil }
        return viewModel.items.first(where: { $0.seriesId == id })
    }

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
                gridContent
            }
        }
        .onChange(of: focusedSeriesId) { _, newId in
            guard let binding = focusedItem else { return }
            if let id = newId, let item = viewModel.items.first(where: { $0.seriesId == id }) {
                binding.wrappedValue = item
            } else {
                binding.wrappedValue = nil
            }
        }
        .fullScreenCover(item: $presentedSeries) { series in
            SeriesDetailView(series: series, viewModel: viewModel, api: api)
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

                        CatalogSortChips(selection: $sortMode)
                            .padding(.horizontal, 40)
                            .focusSection()

                        if displayedItems.isEmpty {
                            emptySearchResult
                        } else {
                            grid
                        }

                        Color.clear.frame(height: 180)
                    }
                }
                .focusSection()

                if let focused = focusedSeries {
                    FocusedItemPreview(
                        rawTitle: focused.name,
                        coverUrl: focused.displayIcon,
                        providerRating: focused.rating,
                        kind: .tv
                    )
                    .id(focused.seriesId)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(DS.Motion.standard, value: focusedSeries?.seriesId)
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    if let first = displayedItems.first?.seriesId {
                        focusedSeriesId = first
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
                    presentedSeries = item
                } label: {
                    FocusableCardLabel(
                        title: item.name,
                        imageUrl: item.displayIcon,
                        aspectRatio: 2/3
                    )
                }
                .buttonStyle(.tvCard)
                .focused($focusedSeriesId, equals: item.seriesId)
                .contextMenu {
                    let isFav = appState.syncService.isFavorite(item.seriesId)
                    Button {
                        appState.syncService.toggleFavorite(.from(series: item))
                    } label: {
                        Label(isFav ? "Retirer des favoris" : "Ajouter aux favoris",
                              systemImage: isFav ? "heart.slash" : "heart")
                    }

                    let isInWl = appState.syncService.isInWatchlist(item.seriesId)
                    Button {
                        appState.syncService.toggleWatchlist(.from(series: item))
                    } label: {
                        Label(isInWl ? "Retirer de À regarder" : "Ajouter à À regarder",
                              systemImage: isInWl ? "bookmark.slash" : "bookmark")
                    }

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
