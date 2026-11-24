import Foundation
import VLCKitSPM

/// Stops and releases a `VLCMediaPlayer` away from the main thread.
///
/// Destroying a libvlc player joins its input and decoder threads
/// (`libvlc_media_player_destroy` → `pthread_join`). When the last reference
/// was dropped on the main thread — the view controller deallocating after a
/// dismiss — that join froze the UI for seconds; Sentry reported it as an
/// App Hang on leaving a film or a channel. `stop()` blocks the same way.
///
/// The player is kept alive here for a short while after stopping: VLCKit
/// posts its last state callbacks to the main queue, and each one retains
/// the player. Releasing only once they have drained makes this reference
/// the last one, so the destroy happens on this queue and not on main.
enum VLCPlayerDisposal {
    private static let queue = DispatchQueue(label: "fr.unimaru.unistream.tv.vlc-disposal", qos: .utility)

    /// VLCMediaPlayer is not Sendable; it is only ever touched from `queue`
    /// once handed over.
    private struct Handover: @unchecked Sendable {
        let player: VLCMediaPlayer
    }

    /// Call on the main thread once the player is detached from its view.
    /// Safe to call more than once for the same player.
    static func stopAndRelease(_ player: VLCMediaPlayer) {
        let handover = Handover(player: player)
        queue.async {
            handover.player.stop()
            queue.asyncAfter(deadline: .now() + 2) {
                _ = handover
            }
        }
    }
}
