import XCTest
import Sentry
@testable import UniStreamTV

/// Mirrors `test/core/log_redaction_test.dart` on the Flutter side — the
/// two implementations have to agree, because they report into the same
/// Sentry project and a gap on one platform is a gap outright.
final class LogRedactionTests: XCTestCase {

    private let user = "testuser"
    private let pass = "sup3rs3cret"

    override func setUp() {
        super.setUp()
        LogRedaction.setCredentials(username: user, password: pass)
    }

    override func tearDown() {
        LogRedaction.clearCredentials()
        super.tearDown()
    }

    // MARK: - Query string

    func testMasksCredentialsOnApiUrl() {
        let redacted = LogRedaction.redact(
            "GET failed for http://test.server:8080/player_api.php"
            + "?username=\(user)&password=\(pass)&action=get_live_streams"
        )

        XCTAssertEqual(
            redacted,
            "GET failed for http://test.server:8080/player_api.php"
            + "?username=***&password=***&action=get_live_streams"
        )
    }

    func testIsCaseInsensitiveAndStopsAtParameterBoundary() {
        XCTAssertEqual(
            LogRedaction.redact("?USERNAME=bob&PASSWORD=hunter2&action=x"),
            "?USERNAME=***&PASSWORD=***&action=x"
        )
    }

    /// Regression: a bare query string with no leading `?` — the exact
    /// shape of a Sentry HTTP breadcrumb's `http.query` and of
    /// `SentryRequest.queryString`. Anchoring only on `?`/`&` left the
    /// first parameter, i.e. the username, in the clear.
    func testMasksTheFirstParameterOfABareQueryString() {
        XCTAssertEqual(
            LogRedaction.redact("username=u&password=p&action=get_short_epg"),
            "username=***&password=***&action=get_short_epg"
        )
    }

    /// The anchor must not turn into a wildcard: a parameter that merely
    /// ends in `user` is not a credential.
    func testDoesNotMaskASimilarlyNamedParameter() {
        XCTAssertEqual(
            LogRedaction.redact("?superuser=bob&action=x"),
            "?superuser=bob&action=x"
        )
        XCTAssertEqual(
            LogRedaction.redact("superuser=bob"),
            "superuser=bob"
        )
    }

    // MARK: - Stream paths

    /// Built from the real URL builders, so the test fails if a future
    /// stream shape stops matching the pattern.
    @MainActor
    func testMasksCredentialSegmentsOfEveryStreamShape() {
        let api = XtreamAPIService()
        api.configure(serverUrl: "http://test.server:8080", username: user, password: pass)

        let urls = [
            api.liveStreamUrl(streamId: "42"),
            api.vodStreamUrl(streamId: "456", extension: "mkv"),
            api.seriesStreamUrl(episodeId: "789", extension: "ts"),
        ].compactMap { $0?.absoluteString }

        XCTAssertEqual(urls.count, 3, "all three builders should produce a URL")

        for url in urls {
            let redacted = LogRedaction.redact("playback error on \(url)")
            XCTAssertFalse(redacted.contains(pass), url)
            XCTAssertFalse(redacted.contains(user), url)
            XCTAssertTrue(redacted.contains("/***/***/"), url)
        }
    }

    func testMasksTimeshiftUrlAndKeepsTheRestOfThePath() {
        XCTAssertEqual(
            LogRedaction.redact(
                "http://test.server:8080/timeshift/\(user)/\(pass)/60/2026-01-02:20-30/42.ts"
            ),
            "http://test.server:8080/timeshift/***/***/60/2026-01-02:20-30/42.ts"
        )
    }

    // MARK: - Literal fallback

    func testCatchesAPasswordInAShapeThePatternsDoNotKnow() {
        XCTAssertEqual(
            LogRedaction.redact("auth rejected for \(user) / \(pass)"),
            "auth rejected for *** / ***"
        )
    }

    func testLeavesAVeryShortCredentialAloneRatherThanShreddingText() {
        LogRedaction.setCredentials(username: "ab", password: "cd")
        XCTAssertEqual(
            LogRedaction.redact("abcd: cannot decode subtitle track"),
            "abcd: cannot decode subtitle track"
        )
    }

    func testLeavesOrdinaryDiagnosticsUntouched() {
        let msg = "VLCKit: connection reset by peer, port = 51234"
        XCTAssertEqual(LogRedaction.redact(msg), msg)
    }

    func testHandlesTheEmptyString() {
        XCTAssertEqual(LogRedaction.redact(""), "")
    }

    /// Sign-out has to stop the literal masking, or a later event gets
    /// scrubbed against a subscription that is no longer the user's.
    func testClearedCredentialsStopLiteralMasking() {
        LogRedaction.clearCredentials()
        XCTAssertEqual(
            LogRedaction.redact("auth rejected for \(user)"),
            "auth rejected for \(user)"
        )
        // The URL patterns are not credential-dependent and must still hold.
        XCTAssertEqual(
            LogRedaction.redact("?username=\(user)&password=\(pass)"),
            "?username=***&password=***"
        )
    }

    // MARK: - Breadcrumbs

    /// The path that actually leaked: the SDK's own HTTP breadcrumb, whose
    /// `data` carries the query string verbatim.
    func testScrubsHttpBreadcrumbData() {
        let crumb = Breadcrumb(level: .info, category: "http")
        crumb.message = "GET http://test.server:8080/player_api.php"
        crumb.data = [
            "url": "http://test.server:8080/player_api.php",
            "http.query": "username=\(user)&password=\(pass)&action=get_short_epg",
            "method": "GET",
            "status_code": 200,
        ]

        _ = LogRedaction.redactBreadcrumb(crumb)

        let query = crumb.data?["http.query"] as? String
        XCTAssertEqual(query, "username=***&password=***&action=get_short_epg")
        XCTAssertEqual(crumb.data?["method"] as? String, "GET",
                       "non-credential values pass through untouched")
        XCTAssertEqual(crumb.data?["status_code"] as? Int, 200,
                       "non-string values survive as themselves")
    }

    func testScrubsNestedBreadcrumbData() {
        let crumb = Breadcrumb(level: .error, category: "player")
        crumb.data = [
            "request": ["url": "http://s:8080/live/\(user)/\(pass)/42.m3u8"],
            "tried": ["http://s:8080/movie/\(user)/\(pass)/7.mkv"],
        ]

        _ = LogRedaction.redactBreadcrumb(crumb)

        let nested = (crumb.data?["request"] as? [String: Any])?["url"] as? String
        XCTAssertEqual(nested, "http://s:8080/live/***/***/42.m3u8")
        let tried = (crumb.data?["tried"] as? [Any])?.first as? String
        XCTAssertEqual(tried, "http://s:8080/movie/***/***/7.mkv")
    }

    // MARK: - Events

    func testScrubsMessageExceptionRequestAndAttachedBreadcrumbs() {
        let event = Event(level: .error)
        event.message = SentryMessage(formatted: "auth failed for \(user)/\(pass)")

        let exception = Exception(
            value: "XtreamError: rejected ?username=\(user)&password=\(pass)",
            type: "XtreamError"
        )
        event.exceptions = [exception]

        let request = SentryRequest()
        request.url = "http://test.server:8080/player_api.php?username=\(user)&password=\(pass)"
        request.queryString = "username=\(user)&password=\(pass)"
        event.request = request

        event.extra = ["last_url": "http://s:8080/series/\(user)/\(pass)/9.ts"]

        let crumb = Breadcrumb(level: .info, category: "http")
        crumb.message = "GET ?username=\(user)&password=\(pass)"
        event.breadcrumbs = [crumb]

        _ = LogRedaction.redactEvent(event)

        XCTAssertEqual(event.message?.formatted, "auth failed for ***/***")
        XCTAssertEqual(event.exceptions?.first?.value,
                       "XtreamError: rejected ?username=***&password=***")
        XCTAssertEqual(event.request?.url,
                       "http://test.server:8080/player_api.php?username=***&password=***")
        XCTAssertEqual(event.request?.queryString, "username=***&password=***")
        XCTAssertEqual(event.extra?["last_url"] as? String,
                       "http://s:8080/series/***/***/9.ts")
        XCTAssertEqual(event.breadcrumbs?.first?.message, "GET ?username=***&password=***")
    }

    /// An event with none of the optional parts set must come back intact
    /// rather than trip the hook.
    func testEmptyEventPassesThrough() {
        let event = Event(level: .info)
        let result = LogRedaction.redactEvent(event)
        XCTAssertNil(result.message)
        XCTAssertNil(result.exceptions)
        XCTAssertNil(result.request)
    }
}
