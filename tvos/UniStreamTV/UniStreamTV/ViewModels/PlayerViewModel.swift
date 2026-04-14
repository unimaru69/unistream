import Foundation
import AVKit
import os

/// Manages AVPlayer playback for live streams and VOD.
@MainActor @Observable
final class PlayerViewModel {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Player")

    let player = AVPlayer()
    private(set) var currentChannel: Channel?
    private(set) var isPlaying = false
    private(set) var error: String?

    private let api: XtreamAPIService
    private var progressTimer: Timer?
    var syncService: SyncService?

    init(api: XtreamAPIService) {
        self.api = api
    }

    /// Start playing a live channel.
    func play(channel: Channel) {
        currentChannel = channel
        error = nil

        guard let url = api.liveStreamUrl(streamId: channel.streamId) else {
            error = "Invalid stream URL"
            return
        }

        logger.info("Playing: \(channel.name)")
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
        isPlaying = true
    }

    /// Stop playback and save progress.
    func stop() {
        saveCurrentProgress()
        stopProgressTimer()
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentChannel = nil
        isPlaying = false
    }

    /// Switch to the next channel in a list.
    func playNext(in channels: [Channel]) {
        guard let current = currentChannel,
              let index = channels.firstIndex(where: { $0.id == current.id }),
              index + 1 < channels.count
        else { return }
        play(channel: channels[index + 1])
    }

    /// Switch to the previous channel in a list.
    func playPrevious(in channels: [Channel]) {
        guard let current = currentChannel,
              let index = channels.firstIndex(where: { $0.id == current.id }),
              index > 0
        else { return }
        play(channel: channels[index - 1])
    }

    // MARK: - Watch Progress

    /// Start periodic progress saving (for VOD content).
    func startProgressTracking(contentKey: String) {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.saveProgress(contentKey: contentKey)
            }
        }
    }

    func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func saveProgress(contentKey: String) {
        guard let item = player.currentItem else { return }
        let posMs = Int(CMTimeGetSeconds(player.currentTime()) * 1000)
        let durMs = Int(CMTimeGetSeconds(item.duration) * 1000)
        guard durMs > 0 else { return }

        syncService?.saveProgress(contentKey: contentKey, positionMs: posMs, durationMs: durMs)
    }

    private func saveCurrentProgress() {
        guard let channel = currentChannel else { return }
        saveProgress(contentKey: channel.streamId)
    }

    /// Resume from saved position.
    func seekToSavedPosition(contentKey: String) {
        guard let entry = syncService?.getProgress(contentKey: contentKey) else { return }
        let time = CMTime(seconds: Double(entry.positionMs) / 1000.0, preferredTimescale: 600)
        player.seek(to: time)
        logger.info("Resumed at \(entry.positionMs)ms for \(contentKey)")
    }
}
