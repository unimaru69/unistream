import UIKit
import VLCKitSPM

/// The "Synchronisation" sheet shared by the film and live players: nudge
/// the sound, and the subtitles on films, earlier or later.
///
/// Each press re-opens the sheet so several steps can be applied in a row
/// while watching lips or reading a line.
@MainActor
enum PlaybackDelayMenu {
    static let subtitleStepMs = 250

    static func present(from host: UIViewController, player: VLCMediaPlayer, includeSubtitles: Bool) {
        let audio = PlaybackPreferences.audioDelayMs
        let subtitles = Int(player.currentVideoSubTitleDelay / 1000)
        var message = "Son : \(PlaybackPreferences.delayLabel(audio))"
        if includeSubtitles {
            message += " · Sous-titres : \(PlaybackPreferences.delayLabel(subtitles))"
        }
        let alert = UIAlertController(title: "Synchronisation", message: message, preferredStyle: .actionSheet)

        func again() { present(from: host, player: player, includeSubtitles: includeSubtitles) }
        func setAudio(_ ms: Int) {
            PlaybackPreferences.audioDelayMs = ms
            player.currentAudioPlaybackDelay = PlaybackPreferences.audioDelayMs * 1000
            again()
        }
        func setSubtitles(_ ms: Int) {
            player.currentVideoSubTitleDelay = ms * 1000
            again()
        }

        let step = PlaybackPreferences.audioDelayStepMs
        alert.addAction(UIAlertAction(title: "Son plus tôt (−\(step) ms)", style: .default) { _ in setAudio(audio - step) })
        alert.addAction(UIAlertAction(title: "Son plus tard (+\(step) ms)", style: .default) { _ in setAudio(audio + step) })
        if includeSubtitles {
            alert.addAction(UIAlertAction(title: "Sous-titres plus tôt (−\(subtitleStepMs) ms)", style: .default) { _ in
                setSubtitles(subtitles - subtitleStepMs)
            })
            alert.addAction(UIAlertAction(title: "Sous-titres plus tard (+\(subtitleStepMs) ms)", style: .default) { _ in
                setSubtitles(subtitles + subtitleStepMs)
            })
        }
        if audio != 0 || subtitles != 0 {
            alert.addAction(UIAlertAction(title: "Remettre à zéro", style: .destructive) { _ in
                PlaybackPreferences.audioDelayMs = 0
                player.currentAudioPlaybackDelay = 0
                player.currentVideoSubTitleDelay = 0
                again()
            })
        }
        alert.addAction(UIAlertAction(title: "Fermer", style: .cancel))
        host.present(alert, animated: true)
    }
}
