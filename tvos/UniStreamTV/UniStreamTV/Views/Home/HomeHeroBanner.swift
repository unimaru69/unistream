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
    /// Optional binding so a parent can render a full-screen backdrop
    /// behind the entire home tab synced with the hero's auto-rotation.
    var displayedItem: Binding<RecentlyAddedItem?>? = nil

    // Hero height — tall enough to feel cinematic without trapping the
    // user inside it. 880pt left no room for the rows below to register
    // as focusable (TestFlight: "impossible de descendre"), so cap at
    // 640pt — the next row peeks ~120pt above the fold and the focus
    // engine sees there's somewhere to go on Down press.
    private let heroHeight: CGFloat = 640
    // Auto-rotate period.
    private let rotationInterval: TimeInterval = 8

    private var currentItem: RecentlyAddedItem? {
        guard !items.isEmpty else { return nil }
        return items[currentIndex % items.count]
    }

    var body: some View {
        ZStack {
            if let currentItem {
                // When a parent is rendering the full-screen wallpaper
                // (passed via `displayedItem`), suppress the in-hero
                // backdrop — otherwise we'd stack two PlexBackdrop
                // gradients and the title would lose contrast.
                Group {
                    if displayedItem == nil {
                        backdrop(for: currentItem)
                    }
                    foreground(for: currentItem)
                }
                .id(currentItem.id)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .trailing)),
                    removal: .opacity.combined(with: .move(edge: .leading))
                ))

                // Page dots at the bottom.
                if items.count > 1 {
                    pageDots
                }
            } else {
                placeholder
            }
        }
        .frame(height: heroHeight)
        .animation(DS.Motion.spring, value: currentIndex)
        // The hero is a section on its own for focus navigation. The
        // CTA is the only focusable inside, so pressing Left / Right
        // would otherwise bounce off the section edge — intercept it
        // and step the carousel manually.
        .focusSection()
        .onMoveCommand { direction in
            switch direction {
            case .left:
                advance(by: -1)
            case .right:
                advance(by: +1)
            default:
                break
            }
        }
        .task(id: appState.api.isAuthenticated) { await load() }
        .task(id: items.count) { await autoRotate() }
        // Mirror the auto-rotated item to the parent so it can render a
        // full-screen wallpaper synced with the hero.
        .onChange(of: currentIndex) { _, _ in
            displayedItem?.wrappedValue = currentItem
        }
        .onChange(of: items.count) { _, _ in
            displayedItem?.wrappedValue = currentItem
        }
    }

    /// Page dots at the lower edge of the hero. The active dot is wider
    /// and brand-coloured; the rest are translucent white pebbles. The
    /// width animation rides the same spring as the carousel transition
    /// so the dots glide between states instead of popping.
    private var pageDots: some View {
        VStack {
            Spacer()
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<items.count, id: \.self) { i in
                    let isActive = i == currentIndex % items.count
                    Capsule()
                        .fill(isActive ? DS.Colour.accentLight : Color.white.opacity(0.35))
                        .frame(width: isActive ? 28 : 8, height: 5)
                }
            }
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    /// Step the carousel manually. Wraps both ways so the user can spin
    /// past the last / first item without dead-ending. Resets the auto-
    /// rotate clock so the user-driven nav doesn't fight the timer.
    @MainActor
    private func advance(by step: Int) {
        guard items.count > 1 else { return }
        let newIndex = (currentIndex + step + items.count) % items.count
        currentIndex = newIndex
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
        // Bottom-left overlay on top of the full-bleed backdrop.
        // Apple TV / Strimr style: no separate poster tile, the backdrop
        // *is* the visual; the title block sits in the lower-left third.
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Spacer()

            // À LA UNE pill — uses the brand label type (smallcaps).
            HStack(spacing: DS.Spacing.sm) {
                Text("À la une")
                    .font(DS.Typography.label)
                    .foregroundColor(DS.Colour.textPrimary)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, DS.Spacing.xxs + 2)
                    .background(DS.Colour.accent, in: Capsule())
                Text(item.badgeLabel)
                    .font(DS.Typography.label)
                    .foregroundColor(DS.Colour.textSecondary)
            }

            Text(item.name)
                .font(DS.Typography.displayHero)
                .foregroundColor(DS.Colour.textPrimary)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.7), radius: 14, y: 3)

            if let rating = ratingOf(item), !rating.isEmpty, rating != "0" {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "star.fill")
                        .foregroundColor(DS.Colour.warning)
                    Text(rating)
                        .foregroundColor(DS.Colour.textSecondary)
                }
                .font(DS.Typography.caption)
            }

            if let plot = plotOf(item), !plot.isEmpty {
                Text(plot)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colour.textSecondary)
                    .lineLimit(3)
                    .frame(maxWidth: 900, alignment: .leading)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 1)
            }

            heroPrimaryButton(for: item)
                .padding(.top, DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.Padding.screenHorizontal + DS.Spacing.lg)
        .padding(.bottom, DS.Padding.contentBottom)
        .padding(.top, DS.Spacing.xxl)
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
                .font(DS.Typography.bodyEmphasised)
                .foregroundColor(isFocused ? .black : DS.Colour.textPrimary)
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    isFocused
                    ? AnyShapeStyle(Color.white)
                    : AnyShapeStyle(DS.Colour.accent)
                )
                .clipShape(Capsule())
                .scaleEffect(configuration.isPressed ? 0.97 : (isFocused ? 1.05 : 1.0))
                .animation(DS.Focus.animation, value: isFocused)
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

        // Heuristic preference for content matching the user's primary
        // language. IPTV providers tag categories with language prefixes
        // ("FR|", "AR|", "EN|", "DO|"…). Until the settings expose a
        // language picker, prefer the system locale's primary language —
        // and apply a soft de-prioritisation to obviously-foreign tags
        // so the À LA UNE rotation doesn't open on Arabic / Turkish
        // titles for a French user.
        let primaryLang = Locale.current.language.languageCode?.identifier.uppercased() ?? "FR"
        let preferredPrefixes: Set<String> = {
            switch primaryLang {
            case "FR": return ["FR", "FRA", "VF"]
            case "EN": return ["EN", "US", "UK", "ENG"]
            default:   return [primaryLang]
            }
        }()
        let dispreferredPrefixes: Set<String> = ["AR", "TR", "RU", "HI", "BN", "FA"]

        /// Extract the "XX|" provider tag from either an item title or a
        /// category name. Returns the uppercased prefix or "" if none.
        func providerTag(_ s: String) -> String {
            guard let prefix = s.split(separator: "|").first, prefix.count <= 4 else { return "" }
            return String(prefix).trimmingCharacters(in: .whitespaces).uppercased()
        }

        func languageBoost(name: String, category: String) -> Double {
            // Provider tags can appear on the title ("AR| Bhramam") or
            // the category ("FR| Films Premium"). Read both — title
            // first so a French film parked in a generic category still
            // wins.
            let titleTag = providerTag(name)
            let catTag = providerTag(category)
            for tag in [titleTag, catTag] where !tag.isEmpty {
                if preferredPrefixes.contains(tag) { return 5.0 }
                if dispreferredPrefixes.contains(tag) { return -8.0 }
            }
            return 0
        }

        // Prefer items that (a) match the user's language, (b) have an
        // actual poster + description, and (c) carry a TMDB-grade
        // rating. Penalise items without a real cover URL so the
        // carousel never opens on a placeholder.
        func vodScore(_ v: VodItem) -> Double {
            let r = Double(v.rating ?? "") ?? 0
            let hasPoster = !v.displayIcon.isEmpty ? 3.0 : -2.0
            let hasPlot = ((v.plot ?? v.description)?.isEmpty == false) ? 2.0 : 0.0
            return r + hasPoster + hasPlot + languageBoost(name: v.name, category: v.categoryName ?? "")
        }
        func seriesScore(_ s: SeriesItem) -> Double {
            let r = Double(s.rating ?? "") ?? 0
            let hasPoster = !s.displayIcon.isEmpty ? 3.0 : -2.0
            let hasPlot = ((s.plot ?? s.description)?.isEmpty == false) ? 2.0 : 0.0
            return r + hasPoster + hasPlot + languageBoost(name: s.name, category: s.categoryName ?? "")
        }

        // Rotate among the top N films + top N series — interleaved so the
        // carousel alternates formats. We score then drop anything below
        // a quality threshold so the user never lands on a hero with
        // empty plot + no poster.
        let qualityThreshold: Double = 5.0
        let topVods = vods
            .map { (item: $0, score: vodScore($0)) }
            .filter { $0.score >= qualityThreshold }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { RecentlyAddedItem.vod($0.item) }
        let topSeries = seriesList
            .map { (item: $0, score: seriesScore($0)) }
            .filter { $0.score >= qualityThreshold }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { RecentlyAddedItem.series($0.item) }

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
                    // Light blur so the backdrop reads as cinematic
                    // wallpaper rather than a poster — but not so much
                    // that we lose the imagery.
                    .blur(radius: 8, opaque: true)
                    .scaleEffect(1.06)
                    .opacity(0.95)
                    .transition(.opacity)
            }

            // Bottom-up darken so the title block sitting in the
            // lower-left third reads cleanly. No more left gradient —
            // the foreground no longer hugs the left edge.
            LinearGradient(
                colors: [
                    .clear,
                    DS.Colour.background.opacity(0.55),
                    DS.Colour.background.opacity(0.92),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Bottom fade into the next row.
            LinearGradient(
                colors: [.clear, DS.Colour.background],
                startPoint: UnitPoint(x: 0.5, y: 0.85),
                endPoint: .bottom
            )

            // Brand accent wash — much subtler than before.
            RadialGradient(
                colors: [DS.Colour.accent.opacity(0.12), .clear],
                center: .bottomLeading,
                startRadius: 120,
                endRadius: 1100
            )
        }
        .clipped()
        .animation(.easeInOut(duration: 0.4), value: tmdbVM.result?.id)
        .task {
            await tmdbVM.load(rawTitle: item.name, kind: kind)
        }
    }
}
