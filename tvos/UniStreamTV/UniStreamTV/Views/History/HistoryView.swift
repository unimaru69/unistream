import SwiftUI
import Kingfisher

/// Watch history screen — poster grid with resume / delete actions.
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false

    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 320), spacing: 32),
    ]

    private var entries: [(key: String, value: WatchEntry)] {
        appState.syncService.watchProgress
            .filter { $0.value.durationMs > 0 }
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                EmptyStateView(
                    icon: "clock.arrow.circlepath",
                    title: "Aucun historique",
                    description: "Les films, séries et chaînes que tu regardes apparaîtront ici.",
                    actionLabel: "Retour",
                    action: { dismiss() }
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 32) {
                        ForEach(entries, id: \.key) { item in
                            HistoryCard(
                                contentKey: item.key,
                                entry: item.value,
                                displayName: displayName(for: item.key, entry: item.value),
                                onTap: { resumePlayback(contentKey: item.key, entry: item.value) }
                            )
                        }
                    }
                    .padding(.horizontal, 60)
                    .padding(.top, 20)

                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Effacer tout l'historique", systemImage: "trash")
                            .font(.subheadline)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 40)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Historique")
        .task { await resolveTitles() }
        .alert("Effacer l'historique ?", isPresented: $showClearConfirm) {
            Button("Annuler", role: .cancel) {}
            Button("Effacer", role: .destructive) {
                appState.syncService.clearAllProgress()
            }
        } message: {
            Text("Tout l'historique de lecture sera supprimé.")
        }
    }

    // MARK: - Title Resolution

    private func resolveTitles() async {
        let sync = appState.syncService
        let needsResolution = sync.watchProgress.values.contains { $0.title == nil || $0.title?.isEmpty == true }
        guard needsResolution else { return }

        let api = appState.api
        let keys = Set(sync.watchProgress.keys)
        let needVod = keys.contains { $0.hasPrefix("vod_") }
        let needEp = keys.contains { $0.hasPrefix("ep_") }
        let needLive = keys.contains { $0.hasPrefix("live_") }

        var channels: [Channel] = []
        var vodItems: [VodItem] = []
        var episodes: [(id: String, title: String)] = []

        if needLive { channels = (try? await api.getLiveStreams()) ?? [] }
        if needVod { vodItems = (try? await api.getVodStreams()) ?? [] }
        if needEp {
            let epIds = keys.filter { $0.hasPrefix("ep_") }.map { String($0.dropFirst(3)) }
            if let seriesVM = appState.seriesVM {
                for (_, eps) in seriesVM.episodes {
                    for ep in eps where epIds.contains(ep.episodeId) {
                        episodes.append((id: ep.episodeId, title: ep.displayTitle))
                    }
                }
            }
        }

        sync.resolveMissingTitles(channels: channels, vodItems: vodItems, episodes: episodes)
    }

    // MARK: - Helpers

    private func displayName(for key: String, entry: WatchEntry) -> String {
        if let title = entry.title, !title.isEmpty { return title }
        if let fav = appState.syncService.favorites[key] { return fav.name }
        return key
            .replacingOccurrences(of: "live_", with: "Chaîne ")
            .replacingOccurrences(of: "vod_", with: "Film ")
            .replacingOccurrences(of: "ep_", with: "Épisode ")
            .replacingOccurrences(of: "series_", with: "Série ")
    }

    // MARK: - Resume

    private func resumePlayback(contentKey: String, entry: WatchEntry) {
        let api = appState.api
        let title = displayName(for: contentKey, entry: entry)
        let resume = entry.positionMs > 0 ? entry.positionMs : nil

        var url: URL?
        var isLive = false

        if contentKey.hasPrefix("vod_") {
            let sid = String(contentKey.dropFirst(4))
            let ext = appState.syncService.favorites[contentKey]?.containerExtension ?? "mp4"
            url = api.vodStreamUrl(streamId: sid, extension: ext)
        } else if contentKey.hasPrefix("ep_") {
            let eid = String(contentKey.dropFirst(3))
            url = api.seriesStreamUrl(episodeId: eid)
        } else if contentKey.hasPrefix("live_") {
            let sid = String(contentKey.dropFirst(5))
            url = api.liveStreamUrl(streamId: sid)
            isLive = true
        }

        guard let url else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if isLive {
                PlayerPresenter.playLive(url: url, title: title, contentKey: contentKey)
            } else {
                PlayerPresenter.playVOD(url: url, title: title, resumeFromMs: resume, contentKey: contentKey)
            }
        }
    }
}

// MARK: - History Card

private struct HistoryCard: View {
    let contentKey: String
    let entry: WatchEntry
    let displayName: String
    let onTap: () -> Void

    @Environment(AppState.self) private var appState

    private var favoriteInfo: FavoriteItem? {
        appState.syncService.favorites[contentKey]
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topTrailing) {
                    // Poster / thumbnail
                    Group {
                        if let cover = favoriteInfo?.displayIcon,
                           let url = URL(string: cover), !cover.isEmpty {
                            KFImage(url)
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                        } else {
                            Color(hex: 0x161230)
                                .overlay {
                                    Image(systemName: modeIcon)
                                        .font(.system(size: 40))
                                        .foregroundColor(.white.opacity(0.25))
                                }
                        }
                    }
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Mode badge top-right
                    Text(modeLabel)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(modeColor.opacity(0.9), in: Capsule())
                        .padding(10)

                    // Progress overlay at bottom
                    VStack {
                        Spacer()
                        progressBar
                    }
                    .padding(10)
                }
                .frame(height: 160)

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(relativeDate(entry.updatedAt))
                        if entry.progress > 0.005 && !entry.isWatched {
                            Text("•")
                            Text("\(Int(entry.progress * 100))%")
                                .foregroundColor(Color(hex: 0x1B6B8A))
                                .fontWeight(.semibold)
                        } else if entry.isWatched {
                            Text("•")
                            Text("Vu")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                }
            }
        }
        .buttonStyle(.tvCard)
        .contextMenu {
            Button(role: .destructive) {
                appState.syncService.removeProgress(contentKey: contentKey)
            } label: {
                Label("Supprimer de l'historique", systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private var progressBar: some View {
        if entry.progress > 0.005 {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                    Capsule()
                        .fill(entry.isWatched ? Color.green : Color(hex: 0x1B6B8A))
                        .frame(width: geo.size.width * entry.progress)
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Mode metadata

    private var modeKey: String {
        if contentKey.hasPrefix("live_") { return "live" }
        if contentKey.hasPrefix("vod_") { return "vod" }
        if contentKey.hasPrefix("ep_") || contentKey.hasPrefix("series_") { return "series" }
        return "other"
    }

    private var modeLabel: String {
        switch modeKey {
        case "live": "DIRECT"
        case "vod": "FILM"
        case "series": "SÉRIE"
        default: "—"
        }
    }

    private var modeColor: Color {
        switch modeKey {
        case "live": .red
        case "vod": .purple
        case "series": .teal
        default: .gray
        }
    }

    private var modeIcon: String {
        switch modeKey {
        case "live": "antenna.radiowaves.left.and.right"
        case "vod": "film.fill"
        case "series": "tv.inset.filled"
        default: "play.fill"
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "à l'instant" }
        if interval < 3600 { return "il y a \(Int(interval / 60)) min" }
        if interval < 86400 { return "il y a \(Int(interval / 3600))h" }
        if interval < 604800 {
            let d = Int(interval / 86400)
            return d == 1 ? "hier" : "il y a \(d) j"
        }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.locale = Locale(identifier: "fr_FR")
        return f.string(from: date)
    }
}
