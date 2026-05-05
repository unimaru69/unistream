import SwiftUI

/// Split-view layout for Films: fixed-width sidebar of categories on the
/// left, VOD grid on the right.
struct VODSplitView: View {
    @Bindable var viewModel: VODViewModel
    let api: XtreamAPIService
    @Environment(AppState.self) private var appState

    @State private var selection: Category?
    @FocusState private var focusedCategory: Category?
    /// Focused item lifted from the grid — see SeriesSplitView for the
    /// rationale (full-screen backdrop, behind sidebar + tab bar).
    @State private var focusedVod: VodItem?

    private var filteredCategories: [Category] {
        appState.parentalService.filterCategories(viewModel.categories, contentType: .vod)
    }

    var body: some View {
        NavigationStack {
            Group {
                // Show a loading indicator whenever the sidebar would be empty —
                // not just while the view-model's `isLoading` flag is set, because
                // there's a small window before the task fires where both are false
                // and the screen looks black.
                if viewModel.categories.isEmpty && viewModel.error == nil {
                    ProgressView("Chargement…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.error, viewModel.categories.isEmpty {
                    ErrorRetryView(error: error) {
                        Task { await viewModel.loadCategories() }
                    }
                } else {
                    // See SeriesSplitView for the rationale: the "Reprendre"
                    // row now lives inside the sidebar so it stops eating
                    // a full-width band above the grid.
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
                    .background(splitBackdrop)
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
            // See SeriesSplitView for the rationale: force the TabView
            // tab bar visible so it survives the push/pop into
            // VODDetailView.
            .toolbar(.visible, for: .tabBar)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ContinueWatchingRow(
                    filter: .vodOnly,
                    horizontalPadding: 24,
                    showsPlaceholder: false
                )

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

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let cat = selection {
            VODGridView(category: cat, viewModel: viewModel, api: api, focusedItem: $focusedVod)
        } else {
            Text("Sélectionne une catégorie")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private var splitBackdrop: some View {
        if let item = focusedVod {
            PlexBackdrop(imageUrl: item.displayIcon)
                .id(item.streamId)
                .ignoresSafeArea()
                .transition(.opacity.animation(.easeInOut(duration: 0.4)))
                .animation(.easeInOut(duration: 0.4), value: item.streamId)
        } else {
            DS.Colour.background.ignoresSafeArea()
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
        if lower.contains("western") { return "sun.dust.fill" }
        if lower.contains("guerre") || lower.contains("war") { return "shield.fill" }
        if lower.contains("music") || lower.contains("musique") { return "music.note" }
        if lower.contains("sport") { return "sportscourt.fill" }
        return "film.fill"
    }
}
