import Foundation
import os

/// Manages EPG data — loads only for selected channels, max 50 at a time.
@MainActor @Observable
final class EPGViewModel {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "EPG")

    // MARK: - Public State

    private(set) var epgData: [String: [EpgProgram]] = [:]
    private(set) var isLoading = false
    private(set) var loadedCount = 0
    private(set) var totalCount = 0

    private let api: XtreamAPIService
    private static let maxChannels = 50
    private static let batchSize = 6

    init(api: XtreamAPIService) {
        self.api = api
    }

    // MARK: - Loading

    /// Load EPG for a limited set of channels (max 50).
    func loadEPG(for channels: [Channel]) async {
        let limited = Array(channels.prefix(Self.maxChannels))
        totalCount = limited.count
        loadedCount = 0
        isLoading = true
        epgData = [:]

        for batchStart in stride(from: 0, to: limited.count, by: Self.batchSize) {
            let batchEnd = min(batchStart + Self.batchSize, limited.count)
            let batch = Array(limited[batchStart..<batchEnd])

            for channel in batch {
                do {
                    let programs = try await api.getShortEpg(streamId: channel.streamId, limit: 10)
                    epgData[channel.streamId] = programs
                } catch {
                    epgData[channel.streamId] = []
                }
                loadedCount += 1
            }
        }

        isLoading = false
        logger.info("EPG loaded for \(self.loadedCount) channels")
    }

    /// Load full-day EPG for a single channel (for catch-up program list).
    func loadFullDayEpg(for channel: Channel) async -> [EpgProgram] {
        do {
            let programs = try await api.getFullDayEpg(streamId: channel.streamId)
            return programs
        } catch {
            logger.error("Failed to load full-day EPG for \(channel.name): \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Queries

    func currentProgram(for channelId: String) -> EpgProgram? {
        epgData[channelId]?.first(where: { $0.isCurrent })
    }

    func upcomingPrograms(for channelId: String) -> [EpgProgram] {
        let now = Date()
        return epgData[channelId]?
            .filter { ($0.start ?? .distantPast) >= now || $0.isCurrent }
            .sorted { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }
            .prefix(8)
            .map { $0 } ?? []
    }

    /// Past programs eligible for catch-up replay (ended within last 24h).
    func pastPrograms(for channelId: String) -> [EpgProgram] {
        let now = Date()
        let cutoff = now.addingTimeInterval(-24 * 3600) // Last 24h
        return epgData[channelId]?
            .filter { program in
                guard let end = program.end else { return false }
                return program.isPast && end > cutoff && program.durationMinutes > 0
            }
            .sorted { ($0.start ?? .distantPast) > ($1.start ?? .distantPast) } // newest first
            ?? []
    }
}
