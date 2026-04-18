import SwiftUI

/// Split-view layout for Séries: fixed-width sidebar of categories on the
/// left, series grid on the right.
struct SeriesSplitView: View {
    @Bindable var viewModel: SeriesViewModel
    let api: XtreamAPIService
    @Environment(AppState.self) private var appState

    @State private var selection: Category?
    @FocusState private var focusedCategory: Category?

    private var filteredCategories: [Category] {
        appState.parentalService.filterCategories(viewModel.categories, contentType: .series)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoadingCategories && viewModel.categories.isEmpty {
                    ProgressView("Chargement…")
                } else if let error = viewModel.error, viewModel.categories.isEmpty {
                    ErrorRetryView(error: error) {
                        Task { await viewModel.loadCategories() }
                    }
                } else {
                    VStack(spacing: 0) {
                        // Continue watching row (episodes in progress) — hidden if empty
                        ContinueWatchingRow(filter: .episodesOnly, horizontalPadding: 40)
                            .focusSection()

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
                    }
                }
            }
            .task {
                if viewModel.categories.isEmpty {
                    await viewModel.loadCategories()
                }
                if selection == nil {
                    selection = filteredCategories.first
                }
            }
        }
    }

    private var sidebar: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                Text("Catégories")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 4)

                ForEach(filteredCategories, id: \.id) { cat in
                    Button {
                        selection = cat
                    } label: {
                        CategoryRowLabel(
                            icon: categoryIcon(cat.categoryName),
                            title: cat.categoryName,
                            isSelected: selection?.categoryId == cat.categoryId
                        )
                    }
                    .buttonStyle(.plain)
                    .focused($focusedCategory, equals: cat)
                }
            }
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let cat = selection {
            SeriesGridView(category: cat, viewModel: viewModel, api: api)
        } else {
            Text("Sélectionne une catégorie")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func categoryIcon(_ name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("action") { return "flame.fill" }
        if lower.contains("comédie") || lower.contains("comedy") { return "face.smiling.fill" }
        if lower.contains("drame") || lower.contains("drama") { return "theatermasks.fill" }
        if lower.contains("horreur") || lower.contains("horror") { return "moon.stars.fill" }
        if lower.contains("sci") || lower.contains("fiction") { return "sparkles" }
        if lower.contains("anim") { return "bubbles.and.sparkles.fill" }
        if lower.contains("document") { return "globe.europe.africa.fill" }
        if lower.contains("enfant") || lower.contains("kid") || lower.contains("family") { return "figure.and.child.holdinghands" }
        if lower.contains("thriller") { return "bolt.fill" }
        if lower.contains("romance") || lower.contains("amour") { return "heart.fill" }
        return "tv.inset.filled"
    }
}
