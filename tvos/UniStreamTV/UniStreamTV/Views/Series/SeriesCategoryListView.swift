import SwiftUI

/// Series category grid — spacious visual cards.
struct SeriesCategoryListView: View {
    @Bindable var viewModel: SeriesViewModel
    let api: XtreamAPIService
    @Environment(AppState.self) private var appState

    private let columns = [
        GridItem(.adaptive(minimum: 340, maximum: 460), spacing: 30)
    ]

    private let categoryColors: [Color] = [
        .teal, .purple, .orange, .blue, .pink, .green, .red, .indigo, .mint, .cyan
    ]

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
                    ScrollView {
                        HStack {
                            Text("Séries")
                                .font(.largeTitle).bold()
                                .padding(.horizontal, 50)
                                .padding(.top, 20)
                            Spacer()
                        }
                        LazyVGrid(columns: columns, spacing: 30) {
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
            // Titre inline dans le ScrollView
            .navigationDestination(for: Category.self) { category in
                SeriesGridView(category: category, viewModel: viewModel, api: api)
            }
            .navigationDestination(for: SeriesItem.self) { series in
                SeriesDetailView(series: series, viewModel: viewModel, api: api)
            }
        }
        .task {
            if viewModel.categories.isEmpty {
                await viewModel.loadCategories()
            }
        }
    }

    private var filteredCategories: [Category] {
        appState.parentalService.filterCategories(viewModel.categories, contentType: .series)
    }

    @ViewBuilder
    private func categoryCard(_ category: Category, colorIndex: Int) -> some View {
        let color = categoryColors[colorIndex % categoryColors.count]

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

                Image(systemName: categoryIcon(category.categoryName))
                    .font(.system(size: 36))
                    .foregroundColor(color)
            }
            .frame(height: 110)

            Text(category.categoryName)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
        }
        .frame(height: 170)
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
        if lower.contains("policier") || lower.contains("crime") { return "shield.fill" }
        if lower.contains("music") || lower.contains("musique") { return "music.note" }
        return "tv.inset.filled"
    }
}
