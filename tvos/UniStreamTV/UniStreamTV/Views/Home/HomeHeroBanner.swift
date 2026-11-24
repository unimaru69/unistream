import SwiftUI
import Kingfisher

/// Featured hero banner at the top of the Home screen.
/// Picks a high-rated movie or series, shows a cinematic backdrop with
/// poster + title + plot + Play button.
struct HomeHeroBanner: View {
    @Environment(AppState.self) private var appState
    @State private var items: [RecentlyAddedItem] = []
    @State private var currentIndex: Int = 0
    /// Catalogue generation the current `items` were built from. `nil`
    /// until the first successful load. Replaces a plain `hasLoaded`
    /// latch so a catalogue refresh re-opens the gate exactly once.
    @State private var loadedGeneration: Int?
    /// True once a load has run to completion. Tells "still loading" (keep
    /// the skeleton, the hero is about to appear) from "nothing to feature"
    /// (collapse, so Home doesn't open on a 640pt black void).
    @State private var didFinishLoading = false
    /// TMDB lookups resolved during `load()` so the foreground can fall
    /// back on `result.overview` when the IPTV provider gives us no
    /// plot of its own. Keyed on `RecentlyAddedItem.id`.
    @State private var tmdbCache: [String: TMDBResult] = [:]
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

    /// Identity for the load task: re-fetch when auth flips to true and
    /// after every catalogue refresh.
    private var loadKey: String {
        "\(appState.api.isAuthenticated)-\(appState.catalogRefresh.generation)"
    }

    private var currentItem: RecentlyAddedItem? {
        guard !items.isEmpty else { return nil }
        return items[currentIndex % items.count]
    }

    /// Loaded, and the catalogue has nothing worth featuring — an empty
    /// or unreachable panel, or only titles below the quality bar.
    private var isCollapsed: Bool { items.isEmpty && didFinishLoading }

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
            } else if !didFinishLoading {
                placeholder
            }
        }
        .frame(height: isCollapsed ? 0 : heroHeight)
        .animation(DS.Motion.spring, value: currentIndex)
        .animation(DS.Motion.spring, value: isCollapsed)
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
        // Re-runs when auth flips to true, and again after every
        // catalogue refresh so the hero can surface titles the provider
        // added while the app was suspended.
        .task(id: loadKey) { await load() }
        .task(id: items.count) { await autoRotate() }
        // Mirror the auto-rotated item to the parent so it can render a
        // full-screen wallpaper synced with the hero.
        //
        // `initial: true` is critical: SwiftUI's `onChange` doesn't fire
        // for the *first* value, only subsequent transitions. Without
        // it, when `load()` populates `items` and the very first hero
        // item appears, we'd fire `currentItem?.id` from `nil` to `id`
        // — but only if SwiftUI considered nil the "previous" value at
        // observation time. In practice this race left `displayedItem`
        // nil through the first render → the parent's wallpaper stayed
        // empty until the user manually advanced or another row took
        // focus. Forcing an initial fire pushes the first item up as
        // soon as it resolves.
        .onChange(of: currentItem?.id, initial: true) { _, _ in
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
        // Prefer the IPTV-provided plot (closest to provider's own
        // copy); fall back to TMDB overview for items where the
        // provider gives us nothing — the hero block reads "richer"
        // and the page never feels like a one-line title floating
        // alone on a backdrop.
        let providerPlot: String? = {
            switch item {
            case .vod(let v): return v.plot ?? v.description
            case .series(let s): return s.plot ?? s.description
            }
        }()
        if let p = providerPlot, !p.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return p
        }
        return tmdbCache[item.id]?.overview
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

            Text(item.name.strippingProviderTag)
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
        // Quiet skeleton — used to be a "Bienvenue sur UniStream" wall
        // (logo + welcome copy) that the user perceived as a slow
        // welcome screen even though the rows below were already
        // loading. Now we render a near-flat dark block so the eye
        // drifts straight to Continuer à regarder / Favoris while the hero pops in
        // as soon as `load()` resolves the first item with a TMDB
        // backdrop. No copy, no logo — the brand lives in the hero
        // artwork itself the moment it's ready.
        DS.Colour.background
            .overlay(
                LinearGradient(
                    colors: [
                        DS.Colour.accent.opacity(0.10),
                        DS.Colour.background.opacity(0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
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
        // Demo mode serves its catalogue without a panel session.
        guard api.isAuthenticated || DemoMode.isActive else { return }
        let generation = appState.catalogRefresh.generation
        guard loadedGeneration != generation else { return }
        loadedGeneration = generation

        async let vodResult = api.getVodStreams()
        async let seriesResult = api.getSeries()

        let vods = (try? await vodResult) ?? []
        let seriesList = (try? await seriesResult) ?? []

        // Scoring walks the whole catalogue (tens of thousands of titles):
        // keep it off the main actor. See `HeroCandidates`.
        let primaryLang = Locale.current.language.languageCode?.identifier.uppercased() ?? "FR"
        let picked = await Task.detached(priority: .userInitiated) {
            HeroCandidates.pick(vods: vods, series: seriesList, primaryLang: primaryLang)
        }.value
        let candidateVods = picked.vods
        let candidateSeries = picked.series

        // Final quality gate: only keep candidates for which TMDB has a
        // proper backdrop image. The home wallpaper is sharp (no blur)
        // and renders at 1920×1080 — the IPTV provider's poster
        // would look pixelated stretched there. Items without a TMDB
        // backdrop simply don't deserve to be À la une.
        //
        // Run all the lookups in parallel so total wait time is a
        // single TMDB roundtrip instead of N. `TMDBService.enrich`
        // caches across calls, so subsequent launches resolve from
        // memory.
        let enrichedVods = await filterByTMDBBackdrop(candidateVods)
        let enrichedSeries = await filterByTMDBBackdrop(candidateSeries)

        var interleaved: [RecentlyAddedItem] = []
        var cache: [String: TMDBResult] = [:]

        if enrichedVods.isEmpty && enrichedSeries.isEmpty {
            // Resilience fallback: TMDB returned no usable backdrop for ANY
            // candidate — feature disabled, no API key in this build, or a
            // network/key failure. Don't leave the hero a dark void at the
            // top of Home (the regression after build 74 wiped the
            // long-lived TMDB cache the hero had been coasting on). Fall back
            // to the top-scored candidates rendered with the provider's own
            // artwork: HeroSlideBackdrop already drops to item.displayIcon
            // when TMDB has no backdrop, and plotOf() uses the provider plot.
            let topVods = Array(candidateVods.prefix(5))
            let topSeries = Array(candidateSeries.prefix(5))
            let maxCount = max(topVods.count, topSeries.count)
            for i in 0..<maxCount {
                if i < topVods.count { interleaved.append(topVods[i]) }
                if i < topSeries.count { interleaved.append(topSeries[i]) }
            }
        } else {
            let topVods = Array(enrichedVods.prefix(5))
            let topSeries = Array(enrichedSeries.prefix(5))
            let maxCount = max(topVods.count, topSeries.count)
            for i in 0..<maxCount {
                if i < topVods.count {
                    interleaved.append(topVods[i].item)
                    cache[topVods[i].item.id] = topVods[i].tmdb
                }
                if i < topSeries.count {
                    interleaved.append(topSeries[i].item)
                    cache[topSeries[i].item.id] = topSeries[i].tmdb
                }
            }
        }

        items = interleaved
        tmdbCache = cache
        didFinishLoading = true
        // Start at a random index so successive launches don't always begin with
        // the same item.
        currentIndex = items.isEmpty ? 0 : Int.random(in: 0..<items.count)
    }

    /// Drops candidates with no TMDB `backdrop_path` and returns the
    /// surviving items paired with their TMDB result, so the caller
    /// can cache the result for downstream use (overview text fallback).
    /// Runs lookups concurrently via a TaskGroup so the wall time is
    /// one TMDB roundtrip rather than `candidates.count` × one.
    private func filterByTMDBBackdrop(
        _ candidates: [RecentlyAddedItem]
    ) async -> [(item: RecentlyAddedItem, tmdb: TMDBResult)] {
        guard !candidates.isEmpty else { return [] }
        let results: [(Int, RecentlyAddedItem, TMDBResult)?] = await withTaskGroup(
            of: (Int, RecentlyAddedItem, TMDBResult)?.self
        ) { group in
            for (idx, item) in candidates.enumerated() {
                group.addTask {
                    let kind: TMDBKind = {
                        switch item {
                        case .vod: return .movie
                        case .series: return .tv
                        }
                    }()
                    guard let result = await TMDBService.shared.enrich(rawTitle: item.name, kind: kind),
                          result.backdropURL(size: "original") != nil
                    else { return nil }
                    return (idx, item, result)
                }
            }
            var collected: [(Int, RecentlyAddedItem, TMDBResult)?] = []
            for await value in group {
                collected.append(value)
            }
            return collected
        }
        return results
            .compactMap { $0 }
            .sorted { $0.0 < $1.0 }
            .map { (item: $0.1, tmdb: $0.2) }
    }
}

/// Picks the titles worth featuring in the hero from the full catalogue.
///
/// Pure and nonisolated so it runs off the main actor: filtering, scoring
/// and sorting every film and series on the main thread hung the app for
/// seconds when Home loaded (Sentry App Hangs in `HomeHeroBanner.load`).
enum HeroCandidates {
    /// Languages never featured, whatever their rating.
    static let dispreferredPrefixes: Set<String> = ["AR", "TR", "RU", "HI", "BN", "FA"]
    /// Below this score a title has no poster, no plot or no rating.
    static let qualityThreshold: Double = 5.0
    static let limit = 15

    /// IPTV providers tag titles and categories with a language prefix
    /// ("FR|", "AR|", "EN|"…). Until the settings expose a language picker,
    /// prefer the system language.
    static func preferredPrefixes(for primaryLang: String) -> Set<String> {
        switch primaryLang {
        case "FR": return ["FR", "FRA", "VF"]
        case "EN": return ["EN", "US", "UK", "ENG"]
        default:   return [primaryLang]
        }
    }

    /// The leading "XX|" provider tag of a title or category name,
    /// uppercased, or "" when there is none. Only looks at the first few
    /// characters: a tag is at most four long, and this runs twice per
    /// title over the whole catalogue.
    static func providerTag(_ s: String) -> String {
        let head = s.prefix(5)
        guard let bar = head.firstIndex(of: "|") else { return "" }
        return head[..<bar].trimmingCharacters(in: .whitespaces).uppercased()
    }

    /// Prefix match — providers write "AR|" but also "ARI|" or "ARTV|".
    static func tagMatches(_ tag: String, _ candidates: Set<String>) -> Bool {
        candidates.contains { tag.hasPrefix($0) }
    }

    /// Hard filter, applied before scoring: a penalty alone can be cancelled
    /// by a high rating plus poster plus plot, which is how well-documented
    /// foreign films kept reaching the rotation.
    static func isDispreferred(name: String, category: String) -> Bool {
        for tag in [providerTag(name), providerTag(category)] where !tag.isEmpty {
            if tagMatches(tag, dispreferredPrefixes) { return true }
        }
        return false
    }

    /// Rating, plus a bonus for a real poster and a plot, plus a boost when
    /// the title (first) or its category carries the user's language tag.
    static func score(name: String, category: String, rating: String?,
                      hasPoster: Bool, hasPlot: Bool, preferred: Set<String>) -> Double {
        var total = (Double(rating ?? "") ?? 0) + (hasPoster ? 3.0 : -2.0) + (hasPlot ? 2.0 : 0.0)
        for tag in [providerTag(name), providerTag(category)] where tagMatches(tag, preferred) {
            total += 5.0
            break
        }
        return total
    }

    static func pick(vods: [VodItem], series: [SeriesItem], primaryLang: String)
        -> (vods: [RecentlyAddedItem], series: [RecentlyAddedItem]) {
        let preferred = preferredPrefixes(for: primaryLang)
        func top<Item>(_ items: [Item], name: (Item) -> String, category: (Item) -> String?,
                       score: (Item) -> Double, wrap: (Item) -> RecentlyAddedItem) -> [RecentlyAddedItem] {
            items
                .filter { !isDispreferred(name: name($0), category: category($0) ?? "") }
                .map { (item: $0, score: score($0)) }
                .filter { $0.score >= qualityThreshold }
                .sorted { $0.score > $1.score }
                .prefix(limit)
                .map { wrap($0.item) }
        }
        let topVods = top(vods, name: \.name, category: \.categoryName, score: { v in
            HeroCandidates.score(
                name: v.name, category: v.categoryName ?? "", rating: v.rating,
                hasPoster: !v.displayIcon.isEmpty,
                hasPlot: (v.plot ?? v.description)?.isEmpty == false, preferred: preferred)
        }, wrap: RecentlyAddedItem.vod)
        let topSeries = top(series, name: \.name, category: \.categoryName, score: { s in
            HeroCandidates.score(
                name: s.name, category: s.categoryName ?? "", rating: s.rating,
                hasPoster: !s.displayIcon.isEmpty,
                hasPlot: (s.plot ?? s.description)?.isEmpty == false, preferred: preferred)
        }, wrap: RecentlyAddedItem.series)
        return (topVods, topSeries)
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
