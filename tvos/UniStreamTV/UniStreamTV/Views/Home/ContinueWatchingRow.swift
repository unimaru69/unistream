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

    private var entries: [(key: String, entry: WatchEntry)] {
        appState.syncService.watchProgress
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
            .prefix(10)
            .map { (key: $0.key, entry: $0.value) }
    }

    var body: some View {
        if entries.isEmpty && !showsPlaceholder {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reprendre")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, horizontalPadding)

                if entries.isEmpty {
                    emptyPlaceholder
                        .padding(.horizontal, horizontalPadding)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(entries, id: \.key) { item in
                                ContinueWatchingCard(contentKey: item.key, entry: item.entry)
                            }
                        }
                        .padding(.horizontal, horizontalPadding)
                    }
                }
            }
        }
    }

    private var emptyPlaceholder: some View {
        HStack(spacing: 16) {
            Image(systemName: "play.circle")
                .font(.title2)
                .foregroundColor(.white.opacity(0.4))
            VStack(alignment: .leading, spacing: 2) {
                Text("Rien en cours pour le moment")
                    .foregroundColor(.white.opacity(0.75))
                    .font(.body)
                Text("Les films et épisodes que tu regardes apparaîtront ici.")
                    .foregroundColor(.white.opacity(0.5))
                    .font(.caption)
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

    /// Try to find the matching favorite to get name/cover.
    private var favoriteInfo: FavoriteItem? {
        appState.syncService.favorites[contentKey]
    }

    var body: some View {
        Button {
            resume()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomLeading) {
                    if let cover = favoriteInfo?.displayIcon, let url = URL(string: cover), !cover.isEmpty {
                        KFImage(url)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fill)
                            .frame(width: 280, height: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(hex: 0x161230))
                            .frame(width: 280, height: 160)
                            .overlay {
                                Image(systemName: "play.circle")
                                    .font(.largeTitle)
                                    .foregroundColor(.white.opacity(0.3))
                            }
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
                                    .fill(entry.isWatched ? Color.green : Color(hex: 0x1B6B8A))
                                    .frame(width: geo.size.width * entry.progress, height: 4)
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 8)
                        }
                    }

                    // "Vu" badge for watched episodes still kept in the row —
                    // pinned to the top-right.
                    if entry.isWatched {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                            Text("Vu")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.85), in: Capsule())
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }
                .frame(width: 280, height: 160)

                Text(entry.title ?? favoriteInfo?.name ?? contentKey)
                    .font(.caption)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: 280, alignment: .leading)
            }
        }
        .buttonStyle(.tvCard)
    }

    private func resume() {
        let api = appState.api
        let title = entry.title ?? favoriteInfo?.name ?? contentKey

        // Prefer contentKey prefix (vod_, ep_, live_) for reliable routing.
        if contentKey.hasPrefix("vod_") {
            let sid = String(contentKey.dropFirst("vod_".count))
            if let url = api.vodStreamUrl(streamId: sid, extension: favoriteInfo?.containerExtension ?? "mp4") {
                PlayerPresenter.playVOD(url: url, title: title, resumeFromMs: entry.positionMs, contentKey: contentKey)
            }
            return
        }
        if contentKey.hasPrefix("ep_") {
            let eid = String(contentKey.dropFirst("ep_".count))
            if let url = api.seriesStreamUrl(episodeId: eid, extension: favoriteInfo?.containerExtension ?? "mp4") {
                PlayerPresenter.playVOD(url: url, title: title, resumeFromMs: entry.positionMs, contentKey: contentKey)
            }
            return
        }
        if contentKey.hasPrefix("live_") {
            let sid = String(contentKey.dropFirst("live_".count))
            if let url = api.liveStreamUrl(streamId: sid) {
                PlayerPresenter.playLive(url: url, title: title, contentKey: contentKey)
            }
            return
        }
    }
}
