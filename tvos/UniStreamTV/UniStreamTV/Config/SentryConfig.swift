import Foundation
import Sentry

/// Sentry crash + error monitoring for the tvOS app.
///
/// Until now only the Flutter app (macOS/iOS/Android) reported to Sentry —
/// the native tvOS Swift app was completely unmonitored, so device crashes
/// (the "app quits back to the tvOS home menu" reports) produced no event we
/// could inspect. This wires the Apple platform SDK into the same Sentry
/// project as Flutter (same DSN — events are separated by `release` /
/// `dist` / platform context).
///
/// We deliberately enable **watchdog-termination tracking**: on tvOS the most
/// common silent "return to home menu" is the system jetsam-killing the app
/// under memory pressure (lots of Kingfisher images in a grid + a VLCKit
/// decode buffer spike). Those aren't signals/exceptions, so SentryCrash
/// alone wouldn't see them; the watchdog integration reports them
/// heuristically as `WatchdogTermination` events, which is exactly the data
/// we need to tell an OOM apart from a genuine code crash.
enum SentryConfig {
    /// Same DSN as the Flutter app (`lib/core/sentry_config.dart`). Empty
    /// string disables Sentry entirely.
    static let dsn = "https://6bdfb99f88918c89b2cc54360f42932c@o4511139441016832.ingest.de.sentry.io/4511139448488016"

    static var isEnabled: Bool { !dsn.isEmpty }

    /// Start the SDK as early as possible (called from `UniStreamTVApp.init`).
    static func startIfEnabled() {
        guard isEnabled else { return }

        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "0"
        let build = info?["CFBundleVersion"] as? String ?? "0"

        SentrySDK.start { options in
            options.dsn = dsn
            // Matches the bundle id so tvOS releases line up with the
            // iOS/macOS records on the same Sentry project.
            options.releaseName = "fr.unimaru.unistream@\(version)+\(build)"
            options.dist = build
            #if DEBUG
            options.environment = "debug"
            options.debug = true
            #else
            options.environment = "production"
            #endif

            // Crash + error capture (default on, stated for clarity).
            options.enableCrashHandler = true
            // The key addition for our "silent quit to home menu" reports.
            options.enableWatchdogTerminationTracking = true
            // Light performance sampling, mirroring the Flutter side (0.2).
            options.tracesSampleRate = 0.2
            // No PII — same stance as Flutter (`sendDefaultPii = false`).
            options.sendDefaultPii = false
            // Breadcrumbs for view lifecycle + network give us the trail
            // leading up to a crash without us instrumenting by hand.
            options.enableAutoBreadcrumbTracking = true
        }
    }
}
