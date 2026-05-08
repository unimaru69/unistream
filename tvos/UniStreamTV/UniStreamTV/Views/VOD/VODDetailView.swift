import SwiftUI
@preconcurrency import AVKit
import Kingfisher

/// VOD movie detail — Apple TV+ style full-bleed backdrop with a hero
/// info block in the upper-left, primary CTA pill, secondary actions,
/// and the cast row underneath.
///
/// Player is launched via `PlayerPresenter.playVOD` (UIKit-backed
/// `AVPlayerViewController` for proper tvOS chrome).
struct VODDetailView: View {
    let item: VodItem
    let api: XtreamAPIService

    @Environment(AppState.self) private var appState
    @State private var tmdbVM = TMDBViewModel()

    private var contentKey: String { "vod_\(item.streamId)" }

    private var sourceSynopsis: String {
        item.plot ?? item.description ?? ""
    }
    private var effectiveSynopsis: String {
        if !sourceSynopsis.isEmpty { return sourceSynopsis }
        return tmdbVM.result?.overview ?? ""
    }
    private var backdropURL: String {
        if let b = tmdbVM.result?.backdropURL(size: "original") {
            return b.absoluteString
        }
        // While TMDB is loading, keep the backdrop empty so PlexBackdrop
        // stays plain dark — avoids flashing the low-res source poster.
        if tmdbVM.isLoading || !tmdbVM.hasFetched { return "" }
        return item.displayIcon
    }

    private var isFav: Bool {
        appState.syncService.isFavorite(item.streamId)
    }
    private var isInWatchlist: Bool {
        appState.syncService.isInWatchlist(item.streamId)
    }
    private var isWatched: Bool {
        appState.syncService.isWatched(contentKey: contentKey)
    }
    private var savedProgress: WatchEntry? {
        appState.syncService.getProgress(contentKey: contentKey)
    }

    /// Year used in the metadata strip — TMDB first, then a parse of
    /// the title's trailing "(YYYY)" if any (so we still know the year
    /// when TMDB hasn't resolved yet, even though the title now hides
    /// it via `cleanedTitleNoYear`).
    private var displayYear: String {
        if let y = tmdbVM.result?.year { return "\(y)" }
        return parseTrailingYear(from: item.name) ?? ""
    }

    private func parseTrailingYear(from title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6, trimmed.hasSuffix(")") else { return nil }
        let close = trimmed.index(before: trimmed.endIndex)
        let open = trimmed.index(close, offsetBy: -5)
        guard open >= trimmed.startIndex, trimmed[open] == "(" else { return nil }
        let yearStart = trimmed.index(after: open)
        let year = trimmed[yearStart..<close]
        return year.allSatisfy(\.isNumber) ? String(year) : nil
    }

    /// Primary CTA copy reflects the user's progress.
    private var primaryCTACopy: String {
        if isWatched { return "Revoir" }
        if savedProgress != nil { return "Reprendre" }
        return "Regarder"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Padding.sectionGap) {
                hero
                castRow
            }
            .padding(.bottom, DS.Padding.contentBottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Sharp backdrop (blurRadius: 0) for the same cinematic feel
        // as the home hero — the user pointed out the previous default
        // 28pt blur made detail views look soft / muddy compared to
        // the Accueil shelf header. PlexBackdrop's gradients still
        // run for legibility (left-darken + bottom-fade + brand tint).
        .background(PlexBackdrop(imageUrl: backdropURL, blurRadius: 0).ignoresSafeArea())
        .ignoresSafeArea()
        .task {
            await tmdbVM.load(rawTitle: item.name, kind: .movie)
        }
    }

    // MARK: - Hero block

    private var hero: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(item.name.cleanedTitleNoYear)
                .font(DS.Typography.displayHero)
                .foregroundColor(DS.Colour.textPrimary)
                .lineLimit(2)
                .shadow(color: .black.opacity(0.6), radius: 12, y: 4)

            metadataStrip

            // Synopsis — capped height with a fade so long blurbs read
            // as cinematic rather than wall-of-text.
            if !effectiveSynopsis.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(effectiveSynopsis)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colour.textSecondary)
                        .frame(maxHeight: 200, alignment: .topLeading)
                        .clipped()
                        .mask(
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.85),
                                    .init(color: .clear, location: 1.0),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    if sourceSynopsis.isEmpty {
                        TMDBBadge()
                    }
                }
            } else if tmdbVM.isLoading {
                ProgressView().tint(DS.Colour.textTertiary)
            }

            // Resume / watched indicators — sit above the CTA row so the
            // user reads "Reprendre à 1:34:22" before pressing the
            // primary button.
            if isWatched {
                watchedBadge
            } else if let progress = savedProgress {
                resumeProgressBar(progress)
            }

            primaryCTAs

            secondaryCTAs
        }
        .frame(maxWidth: 980, alignment: .leading)
        .padding(.horizontal, DS.Padding.screenHorizontal)
        // Push the hero block down to roughly the lower-middle of the
        // first viewport so the backdrop has room to breathe — the
        // Apple TV+ / Strimr feel the user asked for. The text reads
        // over the image's darker bottom-left zone (PlexBackdrop's
        // gradient takes care of legibility there).
        .padding(.top, 380)
    }

    private var metadataStrip: some View {
        HStack(spacing: DS.Spacing.sm) {
            if !formattedRating(tmdbVM.result?.rating).isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(DS.Colour.warning)
                    Text(formattedRating(tmdbVM.result?.rating))
                }
            } else if let raw = item.rating, !raw.isEmpty, raw != "0" {
                // Fallback: provider rating (string).
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundColor(DS.Colour.warning)
                    Text(raw)
                }
            }
            if !displayYear.isEmpty {
                separator
                Text(displayYear)
            }
            let runtime = formattedRuntime(minutes: tmdbVM.result?.runtime)
            if !runtime.isEmpty {
                separator
                Text(runtime)
            }
        }
        .font(DS.Typography.bodyEmphasised)
        .foregroundColor(DS.Colour.textSecondary)
    }

    private var separator: some View {
        Text("·").foregroundColor(DS.Colour.textTertiary)
    }

    private var watchedBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text("Déjà vu").font(DS.Typography.bodyEmphasised)
        }
        .foregroundColor(DS.Colour.success)
    }

    private func resumeProgressBar(_ progress: WatchEntry) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            ProgressView(value: progress.progress)
                .tint(DS.Colour.accent)
            Text("Reprendre à \(formatTime(progress.positionMs))")
                .font(DS.Typography.caption)
                .foregroundColor(DS.Colour.textTertiary)
        }
        .frame(maxWidth: 460)
    }

    // MARK: - CTA rows

    private var primaryCTAs: some View {
        HStack(spacing: DS.Spacing.md) {
            Button { play() } label: {
                Label(primaryCTACopy, systemImage: "play.fill")
            }
            .buttonStyle(PrimaryHeroButton())

            Button {
                appState.syncService.toggleFavorite(.from(vod: item))
            } label: {
                Label {
                    Text(isFav ? "Retirer" : "Favori")
                } icon: {
                    Image(systemName: isFav ? "heart.fill" : "heart")
                        .symbolEffect(.bounce, value: isFav)
                }
            }
            .buttonStyle(GhostHeroButton(activeTint: DS.Colour.accentWarm, isActive: isFav))

            Button {
                appState.syncService.toggleWatchlist(.from(vod: item))
            } label: {
                Label {
                    Text(isInWatchlist ? "Retirer" : "À regarder")
                } icon: {
                    Image(systemName: isInWatchlist ? "bookmark.fill" : "bookmark")
                        .symbolEffect(.bounce, value: isInWatchlist)
                }
            }
            .buttonStyle(GhostHeroButton(activeTint: DS.Colour.accent, isActive: isInWatchlist))
        }
        .padding(.top, DS.Spacing.md)
    }

    @ViewBuilder
    private var secondaryCTAs: some View {
        HStack(spacing: DS.Spacing.md) {
            Button {
                if isWatched {
                    appState.syncService.markAsUnwatched(contentKey: contentKey)
                } else {
                    appState.syncService.markAsWatched(contentKey: contentKey, title: item.name)
                }
            } label: {
                Label(
                    isWatched ? "Marquer non vu" : "Marquer vu",
                    systemImage: isWatched ? "xmark.circle" : "checkmark.circle"
                )
            }
            .buttonStyle(GhostHeroButton())

            if FeatureAccess.canUse(.collections, account: appState.authService.cachedAccountInfo) {
                Menu {
                    ForEach(appState.collectionsService.collections(for: "movie")) { collection in
                        Button {
                            appState.collectionsService.addToCollection(
                                collectionId: collection.id,
                                item: .from(vod: item)
                            )
                        } label: {
                            Label(collection.name, systemImage: "folder")
                        }
                    }
                } label: {
                    Label("Collection", systemImage: "folder.badge.plus")
                }
                .buttonStyle(GhostHeroButton())
                .disabled(appState.collectionsService.collections.isEmpty)
            }
        }
    }

    // MARK: - Cast row

    @ViewBuilder
    private var castRow: some View {
        if let tmdb = tmdbVM.result, !tmdb.cast.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: DS.Spacing.sm) {
                    Text("Distribution")
                        .font(DS.Typography.title1)
                        .foregroundColor(DS.Colour.textPrimary)
                    TMDBBadge()
                }
                .padding(.horizontal, DS.Padding.screenHorizontal)

                TMDBCastRow(cast: tmdb.cast)
            }
        }
    }

    // MARK: - Actions

    private func play() {
        guard let url = api.vodStreamUrl(streamId: item.streamId, extension: item.containerExtension) else { return }
        PlayerPresenter.playVOD(
            url: url,
            title: item.name,
            resumeFromMs: savedProgress?.positionMs,
            contentKey: contentKey,
            coverUrl: item.displayIcon
        )
    }

    private func formatTime(_ ms: Int) -> String {
        let totalSeconds = ms / 1000
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
