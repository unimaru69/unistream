import Foundation
import os

/// Manages live TV categories and channel lists.
@MainActor @Observable
final class LiveViewModel {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Live")

    private(set) var categories: [Category] = []
    private(set) var channels: [Channel] = []
    private(set) var epgData: [String: [EpgProgram]] = [:]
    var isLoadingCategories = false
    var isLoadingChannels = false
    var error: String?

    /// Cached channel counts per category (categoryId -> count).
    private(set) var channelCounts: [String: Int] = [:]

    /// All channels across all categories (for favorites filter).
    private(set) var allChannels: [Channel] = []
    var isLoadingAllChannels = false

    /// Category the grid is currently showing. Remembered so a catalogue
    /// refresh can re-pull exactly what the user is looking at instead of
    /// leaving them on a stale list.
    private(set) var currentCategory: Category?

    private let api: XtreamAPIService

    init(api: XtreamAPIService) {
        self.api = api
    }

    /// Load all live categories (no auto-select).
    func loadCategories() async {
        isLoadingCategories = true
        error = nil

        do {
            categories = try await api.getLiveCategories()
            logger.info("Loaded \(self.categories.count) live categories")
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to load categories: \(error.localizedDescription)")
        }

        isLoadingCategories = false
    }

    /// Load channels for a specific category.
    func loadChannels(for category: Category, force: Bool = false) async {
        isLoadingChannels = true
        error = nil
        currentCategory = category
        channels = [] // Clear previous
        epgData = [:] // Clear previous EPG

        do {
            channels = try await api.getLiveStreams(categoryId: category.categoryId, force: force)
            logger.info("Loaded \(self.channels.count) channels for '\(category.categoryName)'")
            // Load EPG in background after channels are ready
            await loadEpgForChannels(channels)
        } catch {
            self.error = error.localizedDescription
            logger.error("Failed to load channels: \(error.localizedDescription)")
        }

        isLoadingChannels = false
    }

    /// Load all channels (for favorites filtering and channel counts).
    func loadAllChannels(force: Bool = false) async {
        guard allChannels.isEmpty || force else { return }
        isLoadingAllChannels = true

        do {
            allChannels = try await api.getLiveStreams(force: force)
            logger.info("Loaded \(self.allChannels.count) total channels")

            // Compute channel counts per category
            var counts: [String: Int] = [:]
            for ch in allChannels {
                if let catId = ch.categoryId {
                    counts[catId, default: 0] += 1
                }
            }
            channelCounts = counts
        } catch {
            logger.error("Failed to load all channels: \(error.localizedDescription)")
        }

        isLoadingAllChannels = false
    }

    /// Load EPG data for a list of channels in batches of 6.
    func loadEpgForChannels(_ channels: [Channel]) async {
        let batchSize = 6
        let batches = stride(from: 0, to: channels.count, by: batchSize).map {
            Array(channels[$0..<min($0 + batchSize, channels.count)])
        }

        for batch in batches {
            await withTaskGroup(of: (String, [EpgProgram]).self) { group in
                for channel in batch {
                    group.addTask { [api] in
                        do {
                            let programs = try await api.getShortEpg(streamId: channel.streamId, limit: 2)
                            return (channel.streamId, programs)
                        } catch {
                            return (channel.streamId, [])
                        }
                    }
                }
                for await (streamId, programs) in group {
                    epgData[streamId] = programs
                }
            }
        }
    }

    /// Get the current program for a stream.
    func currentProgram(for streamId: String) -> EpgProgram? {
        guard let programs = epgData[streamId] else { return nil }
        return programs.first(where: { $0.isCurrent }) ?? programs.first
    }

    /// Get the next-up programme — the first one that hasn't started
    /// yet — for the LiveFocusedPreview "Ensuite : …" line.
    func nextProgram(for streamId: String) -> EpgProgram? {
        guard let programs = epgData[streamId] else { return nil }
        let now = Date()
        return programs.first { ($0.start ?? .distantPast) > now }
    }

    /// Set channels directly (used when showing favorites or "all channels").
    func setChannels(_ newChannels: [Channel]) {
        channels = newChannels
        epgData = [:]
    }

    /// Re-pull whatever this view-model currently holds, bypassing the
    /// API cache. Driven by `CatalogRefreshService` — only the lists that
    /// were already loaded are re-fetched, so a refresh never turns into
    /// a full catalogue download the user didn't ask for.
    func reloadAfterCatalogRefresh() async {
        if !categories.isEmpty {
            await loadCategories()
        }
        if !allChannels.isEmpty {
            await loadAllChannels(force: true)
        }
        if let category = currentCategory {
            await loadChannels(for: category, force: true)
        }
    }
}
