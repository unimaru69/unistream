import Foundation
import Sentry

/// Redaction of Xtream credentials on anything leaving the device as
/// diagnostics — the tvOS counterpart to Flutter's `log_redaction.dart`.
///
/// Every call the app makes to a panel carries the subscription login and
/// password: in the query string for the API
/// (`player_api.php?username=X&password=Y`) and in the path for streams
/// (`{server}/live/{user}/{pass}/{id}.m3u8`). The Cocoa SDK attaches an
/// HTTP breadcrumb per request with both the URL and its query, so those
/// credentials are on their way out of the device by default — a live
/// event's `http.query` reads `username=…&password=…` verbatim before
/// anything scrubs it.
///
/// Until this existed, the only thing between that and stored credentials
/// was Sentry's *server-side* default scrubber: one project setting, not
/// ours, silently load-bearing. Scrub at the exit instead, the same way
/// the Flutter app does.
///
/// `sendDefaultPii = false` does not cover this: it governs what the SDK
/// itself attaches (IP, user), not what our own strings contain.
enum LogRedaction {

    static let mask = "***"

    /// Query parameters whose value is a credential.
    ///
    /// The leading `(^|[?&])` is load-bearing: Sentry's HTTP breadcrumbs
    /// carry the query on its own, with no `?` in front of it
    /// (`username=…&password=…`), as does `SentryRequest.queryString`.
    /// Anchoring only on `?` or `&` — as the first version of this did,
    /// and as the Dart original still does — masks every parameter except
    /// the first, which is exactly where `username` sits.
    private static let credentialQueryParam = try! NSRegularExpression(
        pattern: #"(^|[?&])((?:username|password|pass|user)=)([^&\s"']+)"#,
        options: [.caseInsensitive]
    )

    /// Stream paths: `/live/<user>/<pass>/…`, and the movie / series /
    /// timeshift variants, which all put the credentials in the same two
    /// segments.
    private static let credentialPathSegments = try! NSRegularExpression(
        pattern: #"(/(?:live|movie|series|timeshift)/)([^/\s]+)/([^/\s]+)/"#,
        options: [.caseInsensitive]
    )

    /// Minimum length before a credential is replaced by literal match.
    ///
    /// A one- or two-character password would otherwise turn every
    /// incidental occurrence of those characters into `***` and shred the
    /// diagnostics we went to Sentry for in the first place. Short
    /// credentials are still covered by the two patterns above, which is
    /// where they realistically appear.
    private static let minLiteralLength = 4

    /// The live credentials, for shapes the patterns don't anticipate — a
    /// bare password logged on its own, a provider using a different URL
    /// layout.
    ///
    /// `beforeSend` runs on whatever thread Sentry is on, never the main
    /// actor, so this can't read `XtreamAPIService` directly. A lock keeps
    /// it honest instead.
    private static let lock = NSLock()
    nonisolated(unsafe) private static var literals: [String] = []

    /// Hand the redactor the credentials now in use. Called from
    /// `XtreamAPIService.configure(serverUrl:username:password:)`, so it
    /// tracks profile switches rather than only the first login.
    static func setCredentials(username: String, password: String) {
        lock.lock()
        defer { lock.unlock() }
        // Password first: it is the one worth masking even if it happens
        // to be a substring of something else.
        literals = [password, username].filter { $0.count >= minLiteralLength }
    }

    /// Drop the credentials — on sign-out, so a later event can't be
    /// masked against a subscription that is no longer the user's.
    static func clearCredentials() {
        lock.lock()
        defer { lock.unlock() }
        literals = []
    }

    // MARK: - Scrubbing

    /// Strip credentials out of an arbitrary diagnostic string.
    static func redact(_ input: String) -> String {
        guard !input.isEmpty else { return input }

        var out = input
        out = credentialQueryParam.stringByReplacingMatches(
            in: out,
            range: NSRange(out.startIndex..., in: out),
            withTemplate: "$1$2\(mask)"
        )
        out = credentialPathSegments.stringByReplacingMatches(
            in: out,
            range: NSRange(out.startIndex..., in: out),
            withTemplate: "$1\(mask)/\(mask)/"
        )

        lock.lock()
        let secrets = literals
        lock.unlock()
        for secret in secrets {
            out = out.replacingOccurrences(of: secret, with: mask)
        }
        return out
    }

    /// Recursively scrub the free-form `data` / `extra` bags, whose call
    /// sites pass whatever the caller had at hand.
    static func redactValue(_ value: Any) -> Any {
        if let string = value as? String { return redact(string) }
        if let dict = value as? [String: Any] { return dict.mapValues(redactValue) }
        if let array = value as? [Any] { return array.map(redactValue) }
        return value
    }

    // MARK: - Sentry hooks

    /// `beforeBreadcrumb` hook — breadcrumbs carry both a message and a
    /// free `data` map. The SDK's own HTTP breadcrumbs land here, which is
    /// the path that actually leaked.
    static func redactBreadcrumb(_ crumb: Breadcrumb) -> Breadcrumb {
        if let message = crumb.message {
            crumb.message = redact(message)
        }
        if let data = crumb.data {
            crumb.data = data.mapValues(redactValue)
        }
        return crumb
    }

    /// `beforeSend` hook — covers the message, every exception value, the
    /// request URL and query, the `extra` bag, and any breadcrumb already
    /// attached to the event.
    static func redactEvent(_ event: Event) -> Event {
        if let message = event.message {
            // `formatted` is read-only, so the message is rebuilt rather
            // than edited in place.
            let redacted = SentryMessage(formatted: redact(message.formatted))
            redacted.message = message.message.map(redact)
            redacted.params = message.params?.map(redact)
            event.message = redacted
        }

        for exception in event.exceptions ?? [] {
            exception.value = redact(exception.value)
        }

        if let request = event.request {
            request.url = request.url.map(redact)
            request.queryString = request.queryString.map(redact)
        }

        if let extra = event.extra {
            event.extra = extra.mapValues(redactValue)
        }

        for crumb in event.breadcrumbs ?? [] {
            _ = redactBreadcrumb(crumb)
        }

        return event
    }
}
