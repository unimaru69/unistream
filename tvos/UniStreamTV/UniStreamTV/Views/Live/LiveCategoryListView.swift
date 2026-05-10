import SwiftUI

/// Live TV categories — visual grid with special entries at top.
struct LiveCategoryListView: View {
    @Bindable var viewModel: LiveViewModel
    @Environment(AppState.self) private var appState

    /// Sentinel categories for special entries.
    private static let allChannelsCategory = Category(
        categoryId: "__all__",
        categoryName: "Toutes les chaînes"
    )
    private static let favoritesCategory = Category(
        categoryId: "__favorites__",
        categoryName: "Favoris"
    )

    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 460), spacing: 30)
    ]

    private let categoryColors: [Color] = [
        .teal, .blue, .purple, .green, .orange, .pink, .red, .indigo, .mint, .cyan
    ]

    private var favoriteCount: Int {
        appState.syncService.favorites.values.filter { $0.isLive }.count
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingCategories && viewModel.categories.isEmpty {
                    ProgressView("Chargement des catégories…")
                } else if let error = viewModel.error, viewModel.categories.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text(error)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Réessayer") {
                            Task { await viewModel.loadCategories() }
                        }
                    }
                } else {
                    ScrollView {
                        HStack {
                            Text("Live TV")
                                .font(.largeTitle).bold()
                                .padding(.horizontal, 50)
                                .padding(.top, 20)
                            Spacer()
                        }
                        LazyVGrid(columns: columns, spacing: 30) {
                            // Special entries
                            NavigationLink(value: Self.allChannelsCategory) {
                                specialCard(
                                    name: "Toutes les chaînes",
                                    icon: "tv.fill",
                                    color: Color(hex: 0x1B6B8A),
                                    count: viewModel.allChannels.isEmpty ? nil : viewModel.allChannels.count
                                )
                            }
                            .buttonStyle(.tvCard)

                            if favoriteCount > 0 {
                                NavigationLink(value: Self.favoritesCategory) {
                                    specialCard(
                                        name: "Favoris",
                                        icon: "heart.fill",
                                        color: Color(red: 1.0, green: 0.84, blue: 0.0),
                                        count: favoriteCount
                                    )
                                }
                                .buttonStyle(.tvCard)
                            }

                            // Regular categories (filtered by parental controls)
                            ForEach(Array(filteredCategories.enumerated()), id: \.element.id) { index, category in
                                NavigationLink(value: category) {
                                    categoryCard(category, colorIndex: index)
                                }
                                .buttonStyle(.tvCard)
                            }
                        }
                        .padding(50)
                    }
                }
            }
            // Titre inline dans le ScrollView (évite le grand titre persistant)
            .navigationDestination(for: Category.self) { category in
                if category.categoryId == "__favorites__" {
                    ChannelGridView(
                        category: category,
                        viewModel: viewModel,
                        showFavoritesOnly: true
                    )
                } else if category.categoryId == "__all__" {
                    ChannelGridView(
                        category: category,
                        viewModel: viewModel,
                        isAllChannels: true
                    )
                } else {
                    ChannelGridView(
                        category: category,
                        viewModel: viewModel
                    )
                }
            }
            .task {
                await viewModel.loadCategories()
                await viewModel.loadAllChannels()
            }
        }
    }

    private var filteredCategories: [Category] {
        appState.parentalService.filterCategories(viewModel.categories, contentType: .live)
    }

    // MARK: - Card Views

    @ViewBuilder
    private func specialCard(name: String, icon: String, color: Color, count: Int?) -> some View {
        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.5), color.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(color)
            }
            .frame(height: 110)

            HStack {
                Text(name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer()

                if let count {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(height: 60)
        }
        .frame(height: 170)
    }

    @ViewBuilder
    private func categoryCard(_ category: Category, colorIndex: Int) -> some View {
        let color = categoryColors[colorIndex % categoryColors.count]
        let (iconName, _) = categoryIcon(for: category.categoryName)

        VStack(spacing: 0) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.4), color.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: iconName)
                    .font(.system(size: 36))
                    .foregroundColor(color)
            }
            .frame(height: 110)

            HStack {
                Text(category.categoryName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)

                Spacer()

                if let count = viewModel.channelCounts[category.categoryId], count > 0 {
                    Text("\(count)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(height: 60)
        }
        .frame(height: 170)
    }

    // MARK: - Helpers

    private func categoryIcon(for name: String) -> (String, Color) {
        let lower = name.lowercased()
        if lower.contains("sport") { return ("sportscourt.fill", Color.green) }
        if lower.contains("news") || lower.contains("info") || lower.contains("actual") { return ("newspaper.fill", Color.blue) }
        if lower.contains("film") || lower.contains("ciné") || lower.contains("movie") { return ("film.fill", Color.purple) }
        if lower.contains("music") || lower.contains("musique") { return ("music.note.tv.fill", Color.pink) }
        if lower.contains("enfant") || lower.contains("kid") || lower.contains("jeunesse") { return ("figure.and.child.holdinghands", Color.orange) }
        if lower.contains("document") || lower.contains("découverte") { return ("globe.europe.africa.fill", Color.teal) }
        if lower.contains("divertissement") || lower.contains("entertainment") { return ("sparkles.tv.fill", Color.yellow) }
        if lower.contains("cuisine") || lower.contains("food") { return ("fork.knife", Color.red) }
        if lower.contains("local") || lower.contains("région") { return ("mappin.and.ellipse", Color.mint) }
        if lower.contains("religieux") || lower.contains("relig") { return ("building.columns.fill", Color.indigo) }
        return ("folder.fill", Color(hex: 0x1B6B8A))
    }
}
