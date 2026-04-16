import SwiftUI

/// Watch history screen — shows recently watched items with resume & delete.
struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirm = false

    private var entries: [(key: String, value: WatchEntry)] {
        appState.syncService.watchProgress
            .filter { $0.value.durationMs > 0 }
            .sorted { $0.value.updatedAt > $1.value.updatedAt }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(entries, id: \.key) { item in
                        Button {
                            resumePlayback(contentKey: item.key, entry: item.value)
                        } label: {
                            HistoryRowView(
                                key: item.key,
                                entry: item.value,
                                displayName: displayName(for: item.key, entry: item.value)
                            )
                        }
                    }
                    .onDelete { indexSet in
                        for i in indexSet {
                            appState.syncService.removeProgress(contentKey: entries[i].key)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Effacer tout l'historique", systemImage: "trash")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                    }
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

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.3))
            Text("Aucun historique")
                .font(.title3)
                .fontWeight(.bold)
            Text("Vos lectures récentes apparaîtront ici")
                .foregroundColor(.secondary)
            // Focusable button so the Menu button on the remote pops this view
            // instead of exiting the app.
            Button {
                dismiss()
            } label: {
                Label("Retour", systemImage: "chevron.left")
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Title Resolution

    /// Resolves missing titles by fetching VOD/series/channel lists from the API.
    private func resolveTitles() async {
        let sync = appState.syncService
        // Check if any entries need title resolution
        let needsResolution = sync.watchProgress.values.contains { $0.title == nil || $0.title?.isEmpty == true }
        guard needsResolution else { return }

        let api = appState.api
        // Determine which types of data we need
        let keys = Set(sync.watchProgress.keys)
        let needVod = keys.contains { $0.hasPrefix("vod_") }
        let needEp = keys.contains { $0.hasPrefix("ep_") }
        let needLive = keys.contains { $0.hasPrefix("live_") }

        var channels: [Channel] = []
        var vodItems: [VodItem] = []
        var episodes: [(id: String, title: String)] = []

        // Fetch only what's needed
        if needLive { channels = (try? await api.getLiveStreams()) ?? [] }
        if needVod { vodItems = (try? await api.getVodStreams()) ?? [] }
        if needEp {
            // Collect episode IDs we need
            let epIds = keys.filter { $0.hasPrefix("ep_") }.map { String($0.dropFirst(3)) }
            // Try to find episodes from series already loaded
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

        // Build URL from contentKey prefix
        var url: URL?
        var isLive = false

        if contentKey.hasPrefix("vod_") {
            let sid = String(contentKey.dropFirst(4))
            // Check favorites for container extension
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

        // Small delay to let tvOS focus system settle before presenting modal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if isLive {
                PlayerPresenter.playLive(url: url, title: title, contentKey: contentKey)
            } else {
                PlayerPresenter.playVOD(url: url, title: title, resumeFromMs: resume, contentKey: contentKey)
            }
        }
    }
}

// MARK: - History Row (focus-aware)

/// Separate struct so we can use @Environment(\.isFocused) for tvOS focus adaptation.
private struct HistoryRowView: View {
    let key: String
    let entry: WatchEntry
    let displayName: String

    @Environment(\.isFocused) private var isFocused

    private var primaryColor: Color { isFocused ? .black : .white }
    private var secondaryColor: Color { isFocused ? .black.opacity(0.6) : .gray }
    private var accentColor: Color { isFocused ? .black.opacity(0.8) : Color(hex: 0x1B6B8A) }

    var body: some View {
        HStack(spacing: 20) {
            // Mode icon
            modeBadge

            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(displayName)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryColor)
                    .lineLimit(1)

                // Info line
                HStack(spacing: 8) {
                    if entry.progress > 0.01 {
                        Text("\(Int(entry.progress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(progressColor)

                        Text("—")
                            .foregroundColor(secondaryColor.opacity(0.5))
                    }

                    if entry.positionMs > 0 {
                        Text("\(entry.elapsedFormatted) sur \(entry.durationFormatted)")
                            .font(.caption)
                            .foregroundColor(secondaryColor)
                    } else {
                        Text(entry.durationFormatted)
                            .font(.caption)
                            .foregroundColor(secondaryColor)
                    }
                }

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isFocused ? Color.black.opacity(0.15) : Color.white.opacity(0.15))
                            .frame(height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(progressColor)
                            .frame(width: max(geo.size.width * entry.progress, 0), height: 4)
                    }
                }
                .frame(height: 4)
                .frame(maxWidth: 300)
            }

            Spacer()

            // Date + play icon
            VStack(alignment: .trailing, spacing: 4) {
                Text(relativeDate(entry.updatedAt))
                    .font(.caption2)
                    .foregroundColor(secondaryColor.opacity(0.7))

                Image(systemName: "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(accentColor)
            }
        }
        .padding(.vertical, 4)
    }

    private var progressColor: Color {
        if isFocused {
            return entry.progress > 0.8 ? .green.opacity(0.8) : .black.opacity(0.7)
        }
        return entry.progress > 0.8 ? .green : Color(hex: 0x1B6B8A)
    }

    @ViewBuilder
    private var modeBadge: some View {
        let mode = detectMode(key)
        let (icon, color): (String, Color) = switch mode {
        case "live": ("antenna.radiowaves.left.and.right", .red)
        case "vod": ("film.fill", .purple)
        case "series": ("tv.inset.filled", .teal)
        default: ("play.fill", .gray)
        }

        Image(systemName: icon)
            .font(.title3)
            .foregroundColor(isFocused ? color : color)
            .frame(width: 44, height: 44)
            .background(color.opacity(isFocused ? 0.2 : 0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    private func detectMode(_ key: String) -> String {
        if key.hasPrefix("live_") { return "live" }
        if key.hasPrefix("vod_") { return "vod" }
        if key.hasPrefix("series_") || key.hasPrefix("ep_") { return "series" }
        return "unknown"
    }

    private func relativeDate(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        guard interval > 0 else { return "à l'instant" }
        if interval < 60 { return "à l'instant" }
        if interval < 3600 {
            let min = Int(interval / 60)
            return "il y a \(min) min"
        }
        if interval < 86400 {
            let h = Int(interval / 3600)
            return "il y a \(h)h"
        }
        if interval < 604800 {
            let d = Int(interval / 86400)
            return d == 1 ? "hier" : "il y a \(d) j"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: date)
    }
}
