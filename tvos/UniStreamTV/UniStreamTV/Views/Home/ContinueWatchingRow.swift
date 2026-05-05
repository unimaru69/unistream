import SwiftUI
import Kingfisher

/// Which kinds of entries to include in a ContinueWatchingRow.
enum ContinueWatchingFilter {
    /// VOD (films) + episodes (séries) — default for Home tab.
    case vodAndEpisodes
    /// VOD only — for the Films tab.
    case vodOnly
    /// Episodes only — for the Séries tab.
    case episodesOnly

    fileprivate func matches(_ key: String) -> Bool {
        switch self {
        case .vodAndEpisodes: return key.hasPrefix("vod_") || key.hasPrefix("ep_")
        case .vodOnly: return key.hasPrefix("vod_")
        case .episodesOnly: return key.hasPrefix("ep_")
        }
    }
}

/// Horizontal row of items the user was watching — shown at the top of Home,
/// Films and Séries tabs (with an appropriate filter).
struct ContinueWatchingRow: View {
    @Environment(AppState.self) private var appState

    var filter: ContinueWatchingFilter = .vodAndEpisodes
    var horizontalPadding: CGFloat = 50

    /// Show a placeholder panel when there's nothing in progress (instead of
    /// hiding the whole section). Default: true — caller can opt out.
    var showsPlaceholder: Bool = true
    /// Optional — when supplied, the row pushes the focused entry up to
    /// the parent so the home wallpaper can crossfade to that item.
    var rowFocused: Binding<BackdropTarget?>? = nil

    @FocusState private var focusedKey: String?

    private var entries: [(key: String, entry: WatchEntry)] {
        let raw = appState.syncService.watchProgress
            .filter { filter.matches($0.key) }
            .filter { pair in
                let p = pair.value.progress
                // Films: a finished film isn't "in progress" — cap at 95%.
                // Episodes: keep them in the row even when finished so a series
                // with at least one watched episode stays visible. The card
                // shows a "Vu" badge and, if we know the next episode, the
                // button resumes the next one.
                if pair.key.hasPrefix("ep_") {
                    return p > 0.005
                }
                return p > 0.005 && p < 0.95
            }
            .sorted { $0.value.updatedAt > $1.value.updatedAt }

        // Collapse multiple episodes of the same series down to the
        // single most-recently-played one — otherwise watching five
        // Drag Race episodes fills the row with five identical-looking
        // tiles. Movies (`vod_*`) and live (`live_*`) entries are
        // never deduped.
        var seenSeries = Set<String>()
        var deduped: [(key: String, entry: WatchEntry)] = []
        for pair in raw {
            if pair.key.hasPrefix("ep_"), let sid = pair.value.seriesId {
                if seenSeries.contains(sid) { continue }
                seenSeries.insert(sid)
            }
            deduped.append((key: pair.key, entry: pair.value))
            if deduped.count >= 10 { break }
        }
        return deduped
    }

    var body: some View {
        if entries.isEmpty && !showsPlaceholder {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Reprendre")
                    .font(DS.Typography.title1)
                    .foregroundColor(DS.Colour.textPrimary)
                    .padding(.horizontal, horizontalPadding)

                if entries.isEmpty {
                    emptyPlaceholder
                        .padding(.horizontal, horizontalPadding)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.lg) {
                            ForEach(entries, id: \.key) { item in
                                ContinueWatchingCard(contentKey: item.key, entry: item.entry)
                                    .focused($focusedKey, equals: item.key)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                    .onChange(of: focusedKey) { _, newKey in
                        // Focus left the row entirely (e.g. moved up to
                        // the hero or down to another shelf). Clear the
                        // override so the wallpaper can fall back to the
                        // hero's current item — otherwise `rowFocused`
                        // stays sticky on the last focused card and the
                        // hero loses its backdrop.
                        guard let key = newKey else {
                            rowFocused?.wrappedValue = nil
                            return
                        }
                        guard let entry = entries.first(where: { $0.key == key })?.entry else { return }
                        // Map to TMDB kind — live entries skip the
                        // wallpaper update (no useful backdrop). Episode
                        // and VOD both look up against TMDB; episode
                        // titles match poorly so we fall back on the
                        // series id when known.
                        if key.hasPrefix("live_") {
                            rowFocused?.wrappedValue = nil
                            return
                        }
                        let kind: TMDBKind = key.hasPrefix("vod_") ? .movie : .tv
                        let title = entry.title ?? key
                        rowFocused?.wrappedValue = BackdropTarget(
                            id: "cw_\(key)",
                            title: title,
                            kind: kind
                        )
                    }
                }
            }
        }
    }

    private var emptyPlaceholder: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "play.circle")
                .font(.title2)
                .foregroundColor(DS.Colour.textTertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Rien en cours pour le moment")
                    .foregroundColor(DS.Colour.textSecondary)
                    .font(DS.Typography.body)
                Text("Les films et épisodes que tu regardes apparaîtront ici.")
                    .foregroundColor(DS.Colour.textTertiary)
                    .font(DS.Typography.caption)
            }
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
        .frame(maxWidth: 720, alignment: .leading)
    }
}

struct ContinueWatchingCard: View {
    let contentKey: String
    let entry: WatchEntry
    @Environment(AppState.self) private var appState
    /// True while the user is choosing between resume and start-over.
    /// Live channels skip the prompt — there's no position to resume to.
    @State private var showResumeChoice = false

    /// Try to find the matching favorite to get name/cover.
    private var favoriteInfo: FavoriteItem? {
        appState.syncService.favorites[contentKey]
    }

    /// Whether to ask "Reprendre à xx:xx" / "Démarrer du début" before
    /// playing. Watched items skip the prompt and start over (the user
    /// already saw them); live channels skip it (no position).
    private var shouldPromptResume: Bool {
        guard !contentKey.hasPrefix("live_") else { return false }
        return entry.positionMs > 10_000 && !entry.isWatched
    }

    /// Cover URL preference order: the entry's own meta (works even for
    /// items the user never favorited — synced from Flutter via
    /// `meta_json.cover`), then the favorite store's cover. Falls through
    /// to the placeholder branch when neither is available.
    private var coverUrl: String? {
        if let c = entry.coverUrl, !c.isEmpty { return c }
        if let c = favoriteInfo?.displayIcon, !c.isEmpty { return c }
        return nil
    }

    var body: some View {
        Button {
            if shouldPromptResume {
                showResumeChoice = true
            } else {
                resume(fromMs: nil)
            }
        } label: {
            CardContent(
                contentKey: contentKey,
                entry: entry,
                coverUrl: coverUrl,
                favoriteInfo: favoriteInfo
            )
        }
        .buttonStyle(.tvCard)
        .confirmationDialog(
            "Reprendre la lecture ?",
            isPresented: $showResumeChoice,
            titleVisibility: .visible
        ) {
            Button("Reprendre à \(Self.formatTime(entry.positionMs))") {
                resume(fromMs: entry.positionMs)
            }
            Button("Reprendre depuis le début") {
                resume(fromMs: nil)
            }
            Button("Annuler", role: .cancel) {}
        }
    }

    /// Launch playback. `fromMs == nil` means start over from 0.
    private func resume(fromMs: Int?) {
        let api = appState.api
        let title = entry.title ?? favoriteInfo?.name ?? contentKey
        // Cover preference: WatchEntry (most current — even works for
        // never-favorited items synced from Flutter), then favorite info.
        let cover = entry.coverUrl ?? favoriteInfo?.displayIcon

        // Prefer the URL captured at first playback: it embeds the correct
        // `containerExtension`, which the contentKey alone doesn't carry.
        // The MP4 fallback below silently returns 404 on .mkv / .ts streams,
        // which is what made Continue Watching look like "rien ne se passe"
        // for episodes saved by older builds (or by other devices).
        let savedUrl = entry.streamUrl.flatMap { URL(string: $0) }

        if contentKey.hasPrefix("vod_") {
            let sid = String(contentKey.dropFirst("vod_".count))
            let url = savedUrl ?? api.vodStreamUrl(streamId: sid, extension: favoriteInfo?.containerExtension ?? "mp4")
            if let url {
                PlayerPresenter.playVOD(url: url, title: title, resumeFromMs: fromMs, contentKey: contentKey, coverUrl: cover)
            }
            return
        }
        if contentKey.hasPrefix("ep_") {
            let eid = String(contentKey.dropFirst("ep_".count))
            let url = savedUrl ?? api.seriesStreamUrl(episodeId: eid, extension: favoriteInfo?.containerExtension ?? "mp4")
            if let url {
                PlayerPresenter.playVOD(url: url, title: title, resumeFromMs: fromMs, contentKey: contentKey, coverUrl: cover)
            }
            return
        }
        if contentKey.hasPrefix("live_") {
            let sid = String(contentKey.dropFirst("live_".count))
            let url = savedUrl ?? api.liveStreamUrl(streamId: sid)
            if let url {
                PlayerPresenter.playLive(url: url, title: title, contentKey: contentKey, coverUrl: cover)
            }
            return
        }
    }

    private static func formatTime(_ ms: Int) -> String {
        let total = ms / 1000
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Card content
//
// Lifted out of `ContinueWatchingCard.body` so we can read
// `\.isFocused` and apply the scale only on the artwork — see the
// matching pattern in `FocusableCardLabel`. Keeping the title block
// static prevents the focused card from clipping its own title.

private struct CardContent: View {
    let contentKey: String
    let entry: WatchEntry
    let coverUrl: String?
    let favoriteInfo: FavoriteItem?

    @Environment(\.isFocused) private var isFocused

    /// Reserved height for the title — fits a single line of
    /// `DS.Typography.title3` (20pt) so cards in a row stay aligned
    /// regardless of length.
    private var titleHeight: CGFloat { 28 }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            artwork
                .scaleEffect(isFocused ? DS.Focus.cardScale : 1.0)
                .shadow(
                    color: .black.opacity(isFocused ? DS.Focus.shadowOpacity : 0),
                    radius: DS.Focus.shadowRadius,
                    y: DS.Focus.shadowY
                )
                .animation(DS.Focus.animation, value: isFocused)

            Text((entry.title ?? favoriteInfo?.name ?? contentKey).strippingProviderTag)
                .font(DS.Typography.title3)
                .foregroundColor(DS.Colour.textPrimary)
                .lineLimit(1)
                .frame(width: 280, height: titleHeight, alignment: .leading)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    private var artwork: some View {
        ZStack(alignment: .bottomLeading) {
            if let cover = coverUrl, let url = URL(string: cover) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(16/9, contentMode: .fill)
                    .frame(width: 280, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            } else {
                // Richer fallback: brand-tinted gradient + the item's
                // title baked into the artwork. Replaces the flat grey
                // tile with a play icon that read as "broken card" on
                // a row that's otherwise visual.
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [
                            DS.Colour.accent.opacity(0.7),
                            DS.Colour.surface,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44, weight: .light))
                        .foregroundColor(DS.Colour.textPrimary.opacity(0.85))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                    Text((entry.title ?? favoriteInfo?.name ?? contentKey).strippingProviderTag)
                        .font(DS.Typography.label)
                        .foregroundColor(DS.Colour.textSecondary)
                        .lineLimit(2)
                        .padding(DS.Spacing.sm)
                        .padding(.bottom, DS.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: 280, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
            }

            // Progress bar
            GeometryReader { geo in
                VStack {
                    Spacer()
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        Capsule()
                            .fill(entry.isWatched ? DS.Colour.success : DS.Colour.accent)
                            .frame(width: geo.size.width * entry.progress, height: 4)
                    }
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.bottom, DS.Spacing.xs)
                }
            }

            // "Vu" badge
            if entry.isWatched {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                    Text("Vu")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
                .foregroundColor(DS.Colour.textPrimary)
                .padding(.horizontal, DS.Spacing.xs)
                .padding(.vertical, 3)
                .background(DS.Colour.success.opacity(0.85), in: Capsule())
                .padding(DS.Spacing.xs)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .frame(width: 280, height: 160)
    }
}
