import Foundation
import SwiftUI

/// Bridges the VLC VOD player's UIKit shell with its SwiftUI overlay.
///
/// The owning `VLCPlayerViewController` writes to the state fields on
/// every transport tick (and whenever the user fires an action), and
/// the SwiftUI `VLCVODOverlayView` reads from them to render the
/// drawer. Buttons in the SwiftUI overlay call back through the
/// closures, which the VC wires to its existing private helpers.
///
/// Why a model + closures instead of `@Bindable`-ing the VC: the VC
/// holds VLC, drawables, and timers, none of which are friendly to
/// `@Observable` instrumentation, and the SwiftUI overlay only needs
/// a small, stable surface — so pinning that surface here keeps the
/// VC free to evolve.
@MainActor
@Observable
final class VLCVODPlayerModel {

    // MARK: - State pushed from UIKit

    var title: String = ""
    var subtitle: String? = nil

    var isPlaying: Bool = true
    var positionSeconds: Double = 0
    var durationSeconds: Double = 0

    /// True when VLC is decoding but no frame has surfaced yet (initial
    /// buffer + heavy seeks) — drives a small spinner over the play
    /// button so it doesn't look frozen.
    var isBuffering: Bool = false

    /// Drawer visibility — UIKit toggles this on Select press, on the
    /// 5-second auto-hide timer, and on transient state changes
    /// (play/pause flash, aspect ratio change).
    var isDrawerVisible: Bool = false

    /// Aspect ratio label shown in the drawer button. Updated by the VC
    /// when it cycles through ratios.
    var aspectRatioLabel: String = "Auto"

    /// Whether VLC has detected ≥1 subtitle track on the current
    /// media. Hides the "Sous-titres" drawer button when false so the
    /// row reads cleaner on assets that don't carry subs.
    var hasSubtitleTracks: Bool = false
    /// Whether VLC has detected ≥2 audio tracks. Hides the "Audio"
    /// drawer button when only one track exists (no choice to offer).
    var hasMultipleAudioTracks: Bool = false

    // MARK: - Actions wired by UIKit

    var onPlayPause: () -> Void = {}
    /// Delta in seconds (negative = backward, positive = forward). The
    /// VC owns the actual VLC seek call.
    var onSeek: (Double) -> Void = { _ in }
    var onShowAudioPicker: () -> Void = {}
    var onShowSubtitlePicker: () -> Void = {}
    var onCycleAspect: () -> Void = {}
    var onShowMore: () -> Void = {}
    var onDismiss: () -> Void = {}

    /// Fires whenever the user shows activity inside the drawer
    /// (focus traversal, button invocation). The VC uses this to
    /// reset the 5-second auto-hide timer so the drawer stays put as
    /// long as the user is navigating it.
    var onUserActivity: () -> Void = {}
}
