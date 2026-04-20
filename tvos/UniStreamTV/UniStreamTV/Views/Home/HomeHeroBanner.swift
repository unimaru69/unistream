import SwiftUI
import Kingfisher

/// Featured hero banner at the top of the Home screen.
/// Picks a high-rated movie or series, shows a cinematic backdrop with
/// poster + title + plot + Play button.
struct HomeHeroBanner: View {
    @Environment(AppState.self) private var appState
    @State private var items: [RecentlyAddedItem] = []
    @State private var currentIndex: Int = 0
    @State private var hasLoaded = false

    // Hero height — enough to breathe, not so tall it eats the next row.
    private let heroHeight: CGFloat = 460
    // Auto-rotate period.
    private let rotationInterval: TimeInterval = 8

    private var currentItem: RecentlyAddedItem? {
        guard !items.isEmpty else { return nil }
        return items[currentIndex % items.count]
    }

    var body: some View {
        ZStack {
            if let currentItem {
                // Keyed on the item id so backdrop + foreground crossfade together.
                Group {
                    backdrop(for: currentItem)
                    foreground(for: currentItem)
                }
                .id(currentItem.id)
                .transition(.opacity)

                // Page dots at the bottom.
                if items.count > 1 {
                    pageDots
                }
            } else {
                placeholder
            }
        }
        .frame(height: heroHeight)
        .clipped()
        .animation(.easeInOut(duration: 0.6), value: currentIndex)
        // The hero is a section on its own for focus navigation.
        .focusSection()
        .task(id: appState.api.isAuthenticated) { await load() }
        .task(id: items.count) { await autoRotate() }
    }

    private var pageDots: some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                ForEach(0..<items.count, id: \.self) { i in
                    Capsule()
                        .fill(i == currentIndex % items.count ? Color.white : Color.white.opacity(0.3))
                        .frame(width: i == currentIndex % items.count ? 22 : 8, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: currentIndex)
                }
            }
            .padding(.bottom, 16)
        }
    }

    @MainActor
    private func autoRotate() async {
        guard items.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(rotationInterval * 1_000_000_000))
            if Task.isCancelled { return }
            currentIndex = (currentIndex + 1) % items.count
        }
    }

    private func plotOf(_ item: RecentlyAddedItem) -> String? {
        switch item {
        case .vod(let v): return v.plot ?? v.description
        case .series(let s): return s.plot ?? s.description
        }
    }

    private func ratingOf(_ item: RecentlyAddedItem) -> String? {
        switch item {
        case .vod(let v): return v.rating
        case .series(let s): return s.rating
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private func backdrop(for item: RecentlyAddedItem) -> some View {
        // Use a per-slide TMDB lookup so each featured item picks up its own
        // wide backdrop. Falls back to the source poster while loading or on
        // a miss — matches Flutter's home-hero behaviour.
        HeroSlideBackdrop(item: item)
    }

    @ViewBuilder
    private func legacyBackdrop(for item: RecentlyAddedItem) -> some View {
        ZStack {
            DS.Colour.background

            KFImage(URL(string: item.displayIcon))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 22, opaque: true)
                .scaleEffect(1.1)
                .opacity(0.90)

            // Leading darken so left-side text is legible.
            LinearGradient(
                colors: [
                    DS.Colour.background.opacity(0.88),
                    DS.Colour.background.opacity(0.55),
                    DS.Colour.background.opacity(0.15),
                    .clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Fade the bottom into the next row.
            LinearGradient(
                colors: [.clear, DS.Colour.background],
                startPoint: .center,
                endPoint: .bottom
            )

            // Brand accent wash.
            RadialGradient(
                colors: [DS.Colour.accent.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 80,
                endRadius: 900
            )
        }
    }

    // MARK: - Foreground

    @ViewBuilder
    private func foreground(for item: RecentlyAddedItem) -> some View {
        HStack(alignment: .center, spacing: 40) {
            // Poster on the left — sharp, not blurred.
            KFImage(URL(string: item.displayIcon))
                .resizable()
                .placeholder {
                    RoundedRectangle(cornerRadius: DS.Radius.hero)
                        .fill(DS.Colour.surface)
                        .overlay {
                            Image(systemName: item.badgeLabel == "SÉRIE" ? "tv.inset.filled" : "film")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.3))
                        }
                }
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 210)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.hero))
                .shadow(color: .black.opacity(0.6), radius: 20, y: 8)

            // Info column + CTA.
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("À LA UNE")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DS.Colour.accent, in: Capsule())
                    Text(item.badgeLabel)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                }

                Text(item.name)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 2)

                if let rating = ratingOf(item), !rating.isEmpty, rating != "0" {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill").foregroundColor(.yellow)
                        Text(rating).foregroundColor(.white.opacity(0.9))
                    }
                    .font(.body)
                }

                if let plot = plotOf(item), !plot.isEmpty {
                    Text(plot)
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.80))
                        .lineLimit(3)
                        .frame(maxWidth: 720, alignment: .leading)
                        .shadow(color: .black.opacity(0.5), radius: 6, y: 1)
                }

                heroPrimaryButton(for: item)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private func heroPrimaryButton(for item: RecentlyAddedItem) -> some View {
        switch item {
        case .vod(let vod):
            Button {
                guard let url = appState.api.vodStreamUrl(
                    streamId: vod.streamId,
                    extension: vod.containerExtension
                ) else { return }
                PlayerPresenter.playVOD(
                    url: url,
                    title: vod.name,
                    contentKey: "vod_\(vod.streamId)"
                )
            } label: {
                Label("Regarder", systemImage: "play.fill")
            }
            .buttonStyle(HeroCTAButtonStyle())

        case .series(let series):
            if let seriesVM = appState.seriesVM {
                NavigationLink {
                    SeriesDetailView(series: series, viewModel: seriesVM, api: appState.api)
                } label: {
                    Label("Voir la série", systemImage: "play.fill")
                }
                .buttonStyle(HeroCTAButtonStyle())
            }
        }
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [DS.Colour.accent.opacity(0.35), DS.Colour.background],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 16) {
                Image("Logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 140, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: DS.Colour.accent.opacity(0.4), radius: 16, y: 6)
                Text("Bienvenue sur UniStream")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("Parcourez Live, Films et Séries")
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    // MARK: - CTA Style

    /// Compact pill-shaped CTA for the hero — much smaller than the default
    /// tvOS `.card` style which blows the button up to card-sized.
    private struct HeroCTAButtonStyle: ButtonStyle {
        @Environment(\.isFocused) private var isFocused
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .font(.callout.weight(.semibold))
                .foregroundColor(isFocused ? .black : .white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(
                    isFocused
                    ? AnyShapeStyle(Color.white)
                    : AnyShapeStyle(DS.Colour.accent)
                )
                .clipShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.05 : 1.0))
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }

    // MARK: - Data

    @MainActor
    private func load() async {
        // Reload when authentication flips to true — don't latch on the first
        // call if the API wasn't ready yet.
        let api = appState.api
        guard api.isAuthenticated else { return }
        guard !hasLoaded else { return }
        hasLoaded = true

        async let vodResult = api.getVodStreams()
        async let seriesResult = api.getSeries()

        let vods = (try? await vodResult) ?? []
        let seriesList = (try? await seriesResult) ?? []

        // Prefer items that have an actual poster + a description to display.
        func vodScore(_ v: VodItem) -> Double {
            let r = Double(v.rating ?? "") ?? 0
            let hasPoster = !v.displayIcon.isEmpty ? 1.0 : 0.0
            let hasPlot = ((v.plot ?? v.description)?.isEmpty == false) ? 1.0 : 0.0
            return r + hasPoster * 3 + hasPlot * 2
        }
        func seriesScore(_ s: SeriesItem) -> Double {
            let r = Double(s.rating ?? "") ?? 0
            let hasPoster = !s.displayIcon.isEmpty ? 1.0 : 0.0
            let hasPlot = ((s.plot ?? s.description)?.isEmpty == false) ? 1.0 : 0.0
            return r + hasPoster * 3 + hasPlot * 2
        }

        // Rotate among the top N films + top N series — interleaved so the
        // carousel alternates formats.
        let topVods = vods.sorted { vodScore($0) > vodScore($1) }.prefix(5).map { RecentlyAddedItem.vod($0) }
        let topSeries = seriesList.sorted { seriesScore($0) > seriesScore($1) }.prefix(5).map { RecentlyAddedItem.series($0) }

        var interleaved: [RecentlyAddedItem] = []
        let maxCount = max(topVods.count, topSeries.count)
        for i in 0..<maxCount {
            if i < topVods.count { interleaved.append(topVods[i]) }
            if i < topSeries.count { interleaved.append(topSeries[i]) }
        }

        items = interleaved
        // Start at a random index so successive launches don't always begin with
        // the same item.
        currentIndex = items.isEmpty ? 0 : Int.random(in: 0..<items.count)
    }
}

/// Per-slide backdrop that fetches its TMDB result lazily. We keep the
/// Kingfisher image + gradients identical to the legacy backdrop, we just
/// swap the URL once TMDB settles.
private struct HeroSlideBackdrop: View {
    let item: RecentlyAddedItem
    @State private var tmdbVM = TMDBViewModel()

    private var imageURL: URL? {
        if let b = tmdbVM.result?.backdropURL(size: "original") { return b }
        if tmdbVM.isLoading || !tmdbVM.hasFetched { return nil }
        return URL(string: item.displayIcon)
    }

    private var kind: TMDBKind {
        // RecentlyAddedItem doesn't expose its kind — inspect by hostname of
        // the id since vod and series use the same prefix scheme.
        return item.id.hasPrefix("vod_") ? .movie : .tv
    }

    var body: some View {
        ZStack {
            DS.Colour.background

            if let url = imageURL {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .blur(radius: 18, opaque: true)
                    .scaleEffect(1.15)
                    .opacity(0.9)
                    .transition(.opacity)
            }

            // Left darken — keeps title area readable.
            LinearGradient(
                colors: [
                    DS.Colour.background.opacity(0.85),
                    DS.Colour.background.opacity(0.50),
                    DS.Colour.background.opacity(0.15),
                    .clear,
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Bottom fade into the next row.
            LinearGradient(
                colors: [.clear, DS.Colour.background],
                startPoint: .center,
                endPoint: .bottom
            )

            // Brand accent wash.
            RadialGradient(
                colors: [DS.Colour.accent.opacity(0.22), .clear],
                center: .topLeading,
                startRadius: 80,
                endRadius: 900
            )
        }
        .clipped()
        .animation(.easeInOut(duration: 0.4), value: tmdbVM.result?.id)
        .task {
            await tmdbVM.load(rawTitle: item.name, kind: kind)
        }
    }
}
