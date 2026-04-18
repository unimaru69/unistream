import SwiftUI
import Kingfisher

/// Split-view layout for Live TV: fixed-width sidebar of categories on the
/// left, channel grid on the right. Replaces NavigationSplitView which
/// doesn't behave correctly on tvOS (takes full width, hides detail).
struct LiveSplitView: View {
    @Bindable var viewModel: LiveViewModel
    @Environment(AppState.self) private var appState

    @State private var selection: CategoryEntry = .all
    @FocusState private var focusedEntry: CategoryEntry?

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
        NavigationStack {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 520)
                    .focusSection()

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focusSection()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                await viewModel.loadCategories()
                await viewModel.loadAllChannels()
                // Pick a sensible initial selection
                if favoriteCount > 0 {
                    selection = .favorites
                } else if !filteredCategories.isEmpty {
                    selection = .category(filteredCategories.first!)
                } else {
                    selection = .all
                }
            }
        }
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
            SidebarRowLabel(
                entry: entry,
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
            let catNames = Dictionary(uniqueKeysWithValues: viewModel.categories.map {
                ($0.categoryId, $0.categoryName)
            })
            EPGView(channels: viewModel.allChannels, categoryNames: catNames)
        case .category(let cat):
            ChannelGridView(category: cat, viewModel: viewModel)
        }
    }
}

// MARK: - Sidebar Row (focus-aware)

private struct SidebarRowLabel: View {
    let entry: LiveSplitView.CategoryEntry
    let count: Int?
    let isSelected: Bool

    @Environment(\.isFocused) private var isFocused

    private var accent: Color { Color(hex: 0x1B6B8A) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .font(.body)
                .foregroundColor(iconColor)
                .frame(width: 26)

            Text(entry.title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(textColor)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let count {
                Text("\(count)")
                    .font(.caption)
                    .foregroundColor(textColor.opacity(0.6))
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
        .scaleEffect(isFocused ? 1.04 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isFocused)
    }

    private var iconColor: Color {
        if isFocused { return .black }
        return isSelected ? accent : .secondary
    }

    private var textColor: Color {
        if isFocused { return .black }
        return isSelected ? .white : .white.opacity(0.75)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isFocused {
            Color.white
        } else if isSelected {
            accent.opacity(0.25)
        } else {
            Color.clear
        }
    }
}
