import Foundation
import VLCKitSPM

/// Applies `PlaybackPreferences` to a VLC player once its tracks are known.
@MainActor
enum VLCPreferredTracks {

    /// Selects the preferred audio and subtitle tracks, if any are set and
    /// available. Returns false while VLC has not listed its tracks yet —
    /// call again shortly; it is cheap and idempotent.
    @discardableResult
    static func apply(to player: VLCMediaPlayer) -> Bool {
        let audio = tracks(
            names: player.audioTrackNames, indexes: player.audioTrackIndexes,
            in: player, type: VLCMediaTracksInformationTypeAudio)
        guard !audio.isEmpty else { return false }

        if let wanted = PlaybackPreferences.preferredTrack(
            in: audio, language: PlaybackPreferences.audioLanguage),
           player.currentAudioTrackIndex != wanted.id {
            player.currentAudioTrackIndex = wanted.id
        }

        let subtitleLanguage = PlaybackPreferences.subtitleLanguage
        if subtitleLanguage == PlaybackPreferences.subtitlesOff {
            if player.currentVideoSubTitleIndex != -1 {
                player.currentVideoSubTitleIndex = -1
            }
        } else {
            let subtitles = tracks(
                names: player.videoSubTitlesNames, indexes: player.videoSubTitlesIndexes,
                in: player, type: VLCMediaTracksInformationTypeText)
            if let wanted = PlaybackPreferences.preferredTrack(in: subtitles, language: subtitleLanguage),
               player.currentVideoSubTitleIndex != wanted.id {
                player.currentVideoSubTitleIndex = wanted.id
            }
        }
        return true
    }

    /// Keeps trying for a few seconds: on a live stream the track list can
    /// arrive well after playback starts. Cancel the returned task when the
    /// media changes or the player goes away.
    static func applyWhenReady(to player: VLCMediaPlayer, attempts: Int = 8) -> Task<Void, Never> {
        Task { @MainActor [weak player] in
            for _ in 0..<attempts {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled, let player else { return }
                if apply(to: player) { return }
            }
        }
    }

    private static func tracks(
        names: [Any]?, indexes: [Any]?, in player: VLCMediaPlayer, type: String
    ) -> [PlaybackPreferences.Track] {
        let names = names as? [String] ?? []
        let ids = (indexes as? [NSNumber] ?? []).map(\.int32Value)
        let info = player.media?.tracksInformation as? [[String: Any]] ?? []
        return zip(names, ids).map { name, id in
            let language = info.first {
                ($0[VLCMediaTracksInformationType] as? String) == type
                    && ($0[VLCMediaTracksInformationId] as? NSNumber)?.int32Value == id
            }?[VLCMediaTracksInformationLanguage] as? String
            return PlaybackPreferences.Track(id: id, name: name, language: language)
        }
    }
}
