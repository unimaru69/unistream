import SwiftUI
import Kingfisher

/// Split-view layout for Live TV: fixed-width sidebar of categories on the
/// left, channel grid on the right. Replaces NavigationSplitView which
/// doesn't behave correctly on tvOS (takes full width, hides detail).
struct LiveSplitView: View {
    @Bindable var viewModel: LiveViewModel
    @Environment(AppState.self) private var appState

    @State private var selection: CategoryEntry = .all
    @State private var didInitSelection = false
    @FocusState private var focusedEntry: CategoryEntry?
    /// See SeriesSplitView for the rationale on this Namespace +
    /// .prefersDefaultFocus pair (sidebar is the preferred entry
    /// point when focus arrives from outside, e.g. ↓ from tab bar).
    @Namespace private var splitFocus
    /// Debounces sidebar focus → selection updates so a quick scroll
    /// doesn't constantly re-render the grid. Without this the grid
    /// flickers under a fast-moving focus and the engine occasionally
    /// drifts sideways into it; the Siri Remote trackpad makes this
    /// especially bad because every micro-glissement bumps focus.
    @State private var selectionDebounce: Task<Void, Never>?

    enum CategoryEntry: Hashable {
        case favorites
        case all
        case epg
        case category(Category)

        var id: String {
            switch self {
            case .favorites: return "__favorites__"
            case .all: return "__all__"
            case .epg: return "__epg__"
            case .category(let c): return c.categoryId
            }
        }

        var title: String {
            switch self {
            case .favorites: return "Favoris"
            case .all: return "Toutes les chaînes"
            case .epg: return "Guide TV"
            case .category(let c): return c.categoryName
            }
        }

        var icon: String {
            switch self {
            case .favorites: return "heart.fill"
            case .all: return "tv.fill"
            case .epg: return "calendar.badge.clock"
            case .category: return "folder.fill"
            }
        }
    }

    private var filteredCategories: [Category] {
        appState.parentalService.filterCategories(viewModel.categories, contentType: .live)
    }

    private var favoriteCount: Int {
        appState.syncService.favorites.values.filter { $0.isLive }.count
    }

    private var canUseEPG: Bool {
        FeatureAccess.canUse(.catchupReplay, account: appState.authService.cachedAccountInfo)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 520)
                    .focusSection()
                    .prefersDefaultFocus(in: splitFocus)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focusSection()
            }
            .focusScope(splitFocus)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Canvas: vertical gradient from pure black at the top
            // (where channel logos sit — they pop on full black) down
            // to DS.Colour.surface (+6% white) in the bottom third
            // where LiveFocusedPreview lives. Without that lift at
            // the bottom, the panel's own fade-to-black gradient
            // blends into a black canvas and the whole info strip
            // reads as one indistinguishable dark mass. Pure black
            // top half preserves consistency with Films / Séries.
            .background(
                LinearGradient(
                    stops: [
                        .init(color: DS.Colour.background, location: 0.0),
                        .init(color: DS.Colour.background, location: 0.55),
                        .init(color: DS.Colour.surface, location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            // Focus-driven preview — when the user moves the focus
            // engine across sidebar entries, the right-hand grid
            // updates immediately, no tap required. Tap then just
            // locks focus into the grid. Without this hook the user
            // had to confirm every category with Select before
            // seeing what's inside.
            //
            // Debounced ~250ms so a fast scroll (especially Siri
            // Remote trackpad, which fires many onChange ticks per
            // second) doesn't thrash the grid. Selection only
            // commits once focus has stabilised on a category.
            .onChange(of: focusedEntry) { _, newValue in
                selectionDebounce?.cancel()
                guard let newValue, newValue != selection else { return }
                selectionDebounce = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 350_000_000)
                    guard !Task.isCancelled else { return }
                    selection = newValue
                }
            }
            .task {
                await viewModel.loadCategories()
                await viewModel.loadAllChannels()
                // Pick a sensible initial selection — only the first time, so that
                // returning to this tab (e.g. after exiting a stream) keeps the
                // user's current category instead of snapping back to Favoris.
                guard !didInitSelection else { return }
                didInitSelection = true
                if favoriteCount > 0 {
                    selection = .favorites
                } else if !filteredCategories.isEmpty {
                    selection = .category(filteredCategories.first!)
                } else {
                    selection = .all
                }
            }
        }
        // Outer opaque canvas — kills the cross-dissolve flash when
        // tabbing between Live / Films / Séries (system grey would
        // otherwise bleed through during the brief moment when
        // neither old-tab nor new-tab content has full opacity).
        .background(DS.Colour.background.ignoresSafeArea())
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    // Special entries
                    if favoriteCount > 0 {
                        sidebarButton(entry: .favorites, count: favoriteCount)
                    }
                    sidebarButton(
                        entry: .all,
                        count: viewModel.allChannels.isEmpty ? nil : viewModel.allChannels.count
                    )
                    if canUseEPG {
                        sidebarButton(entry: .epg, count: nil)
                    }

                    // Section header
                    Text("Catégories")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    // Real categories
                    ForEach(filteredCategories, id: \.id) { cat in
                        sidebarButton(
                            entry: .category(cat),
                            count: viewModel.channelCounts[cat.categoryId]
                        )
                    }
                }
                .padding(.vertical, 20)
            }
        }
    }

    @ViewBuilder
    private func sidebarButton(entry: CategoryEntry, count: Int?) -> some View {
        Button {
            selection = entry
        } label: {
            CategoryRowLabel(
                icon: entry.icon,
                title: entry.title,
                count: count,
                isSelected: selection == entry
            )
        }
        .buttonStyle(.plain)
        .focused($focusedEntry, equals: entry)
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .favorites:
            ChannelGridView(
                category: Category(categoryId: "__favorites__", categoryName: "Favoris"),
                viewModel: viewModel,
                showFavoritesOnly: true
            )
        case .all:
            ChannelGridView(
                category: Category(categoryId: "__all__", categoryName: "Toutes les chaînes"),
                viewModel: viewModel,
                isAllChannels: true
            )
        case .epg:
            // The grid drives its own category + day selection from
            // the LiveViewModel + EPGCache directly — no need to
            // pre-slice channels here. The ranger callback gives the
            // user an explicit "← Catégories" exit.
            EPGGridView(
                liveViewModel: viewModel,
                epgCache: appState.epgCache,
                onBackToCategories: {
                    if favoriteCount > 0 {
                        selection = .favorites
                    } else if let first = filteredCategories.first {
                        selection = .category(first)
                    } else {
                        selection = .all
                    }
                }
            )
        case .category(let cat):
            ChannelGridView(category: cat, viewModel: viewModel)
        }
    }
}

