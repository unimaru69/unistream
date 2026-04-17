import SwiftUI
import Kingfisher

/// Split-view layout for Live TV: sidebar of categories on the left, grid of
/// channels on the right. Aligns with the Flutter UX.
struct LiveSplitView: View {
    @Bindable var viewModel: LiveViewModel
    @Environment(AppState.self) private var appState

    @State private var selection: CategoryEntry = .favorites

    /// Sidebar entries — special entries + real categories.
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
        appState.syncService.favorites.values.filter { $0.mode == "live" }.count
    }

    private var canUseEPG: Bool {
        FeatureAccess.canUse(.catchupReplay, account: appState.authService.cachedAccountInfo)
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await viewModel.loadCategories()
            await viewModel.loadAllChannels()
            // Auto-pick first useful entry
            if favoriteCount > 0 {
                selection = .favorites
            } else if let first = filteredCategories.first {
                selection = .category(first)
            } else {
                selection = .all
            }
        }
    }

    // MARK: - Sidebar

    @ViewBuilder
    private var sidebar: some View {
        List {
            Section {
                if favoriteCount > 0 {
                    sidebarRow(entry: .favorites, count: favoriteCount)
                }
                sidebarRow(entry: .all, count: viewModel.allChannels.isEmpty ? nil : viewModel.allChannels.count)
                if canUseEPG {
                    sidebarRow(entry: .epg, count: nil)
                }
            }

            Section("Catégories") {
                ForEach(filteredCategories, id: \.id) { cat in
                    sidebarRow(
                        entry: .category(cat),
                        count: viewModel.channelCounts[cat.categoryId]
                    )
                }
            }
        }
        .navigationTitle("Live")
    }

    @ViewBuilder
    private func sidebarRow(entry: CategoryEntry, count: Int?) -> some View {
        Button {
            selection = entry
        } label: {
            HStack(spacing: 10) {
                Image(systemName: entry.icon)
                    .foregroundColor(selection == entry ? Color(hex: 0x1B6B8A) : .secondary)
                    .frame(width: 28)
                Text(entry.title)
                    .fontWeight(selection == entry ? .semibold : .regular)
                Spacer()
                if let count {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
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
            let catNames = Dictionary(uniqueKeysWithValues: viewModel.categories.map {
                ($0.categoryId, $0.categoryName)
            })
            EPGView(channels: viewModel.allChannels, categoryNames: catNames)
        case .category(let cat):
            ChannelGridView(category: cat, viewModel: viewModel)
        }
    }
}
