import SwiftUI
import Kingfisher

/// A unified wrapper for recently added VOD or series items, sorted by date.
enum RecentlyAddedItem: Identifiable {
    case vod(VodItem)
    case series(SeriesItem)

    var id: String {
        switch self {
        case .vod(let v): "vod_\(v.streamId)"
        case .series(let s): "series_\(s.seriesId)"
        }
    }

    var name: String {
        switch self {
        case .vod(let v): v.name
        case .series(let s): s.name
        }
    }

    var displayIcon: String {
        switch self {
        case .vod(let v): v.displayIcon
        case .series(let s): s.displayIcon
        }
    }

    /// Max of `added` and `lastModified` as a unix timestamp.
    var sortTimestamp: TimeInterval {
        let strings: [String?]
        switch self {
        case .vod(let v): strings = [v.added, v.lastModified]
        case .series(let s): strings = [s.added, s.lastModified]
        }
        return strings
            .compactMap { $0.flatMap { Double($0) } }
            .max() ?? 0
    }

    var badgeLabel: String {
        switch self {
        case .vod: "FILM"
        case .series: "SÉRIE"
        }
    }
}

/// Horizontal row of recently added movies and series — shown on the Home tab.
struct RecentlyAddedRow: View {
    @Environment(AppState.self) private var appState
    @State private var items: [RecentlyAddedItem] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                loadingView
            } else if !items.isEmpty {
                contentView
            }
        }
        .task { await loadData() }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Ajoutés récemment")
                .font(DS.Typography.title2)
                .foregroundColor(DS.Colour.textPrimary)
                .padding(.horizontal, DS.Padding.screenHorizontal)

            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.lg)
        }
    }

    private var contentView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Ajoutés récemment")
                .font(DS.Typography.title2)
                .foregroundColor(DS.Colour.textPrimary)
                .padding(.horizontal, DS.Padding.screenHorizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    ForEach(items) { item in
                        RecentlyAddedCard(item: item)
                    }
                }
                .padding(.horizontal, 50)
            }
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadData() async {
        guard items.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }

        let api = appState.api
        guard api.isAuthenticated else { return }

        async let vodResult = api.getVodStreams()
        async let seriesResult = api.getSeries()

        let vods = (try? await vodResult) ?? []
        let seriesList = (try? await seriesResult) ?? []

        var combined: [RecentlyAddedItem] = []
        combined.reserveCapacity(vods.count + seriesList.count)
        for v in vods { combined.append(.vod(v)) }
        for s in seriesList { combined.append(.series(s)) }

        items = combined
            .sorted { $0.sortTimestamp > $1.sortTimestamp }
            .prefix(20)
            .map { $0 }
    }
}

/// Individual poster card for a recently added item.
struct RecentlyAddedCard: View {
    let item: RecentlyAddedItem
    @Environment(AppState.self) private var appState

    private let cardWidth: CGFloat = 150
    private let posterAspect: CGFloat = 2.0 / 3.0

    var body: some View {
        switch item {
        case .vod(let vod):
            Button { playVOD(vod) } label: { cardLabel }
                .buttonStyle(.tvCard)
        case .series(let series):
            if let seriesVM = appState.seriesVM {
                NavigationLink {
                    SeriesDetailView(
                        series: series,
                        viewModel: seriesVM,
                        api: appState.api
                    )
                } label: { cardLabel }
                    .buttonStyle(.tvCard)
            }
        }
    }

    private var cardLabel: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                posterImage
                badgeView
            }
            .frame(width: cardWidth, height: cardWidth / posterAspect)

            Text(item.name)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
                .frame(width: cardWidth, alignment: .leading)
        }
    }

    @ViewBuilder
    private var posterImage: some View {
        if let url = URL(string: item.displayIcon), !item.displayIcon.isEmpty {
            KFImage(url)
                .placeholder { posterPlaceholder }
                .resizable()
                .aspectRatio(posterAspect, contentMode: .fill)
                .frame(width: cardWidth, height: cardWidth / posterAspect)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else {
            posterPlaceholder
        }
    }

    private var posterPlaceholder: some View {
        RoundedRectangle(cornerRadius: DS.Radius.card)
            .fill(DS.Colour.surface)
            .frame(width: cardWidth, height: cardWidth / posterAspect)
            .overlay {
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundColor(DS.Colour.textTertiary)
            }
    }

    private var badgeView: some View {
        Text(item.badgeLabel)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: 0x1B6B8A).opacity(0.85), in: RoundedRectangle(cornerRadius: 4))
            .padding(6)
    }

    private func playVOD(_ vod: VodItem) {
        guard let url = appState.api.vodStreamUrl(
            streamId: vod.streamId,
            extension: vod.containerExtension
        ) else { return }
        PlayerPresenter.playVOD(url: url, title: vod.name, contentKey: "vod_\(vod.streamId)")
    }
}
