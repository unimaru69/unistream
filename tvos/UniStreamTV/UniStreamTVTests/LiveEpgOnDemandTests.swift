import XCTest
@testable import UniStreamTV

/// Covers the on-demand short-EPG path behind the focused channel card.
///
/// What matters here is how *often* the panel gets asked: pulling the EPG
/// for a whole category is what produced the request storms and the 2 s+
/// App Hangs Sentry recorded, so the guarantees worth pinning down are
/// "one request per channel" and "never twice for the same one".
@MainActor
final class LiveEpgOnDemandTests: XCTestCase {

    // MARK: - Stub transport

    /// Answers every request from `StubURLProtocol.body` and counts how
    /// many actually went out.
    final class StubURLProtocol: URLProtocol {
        nonisolated(unsafe) static var body: Data = Data()
        nonisolated(unsafe) static var status: Int = 200
        nonisolated(unsafe) static var requestCount = 0
        private static let lock = NSLock()

        static func reset(body: Data, status: Int = 200) {
            lock.lock()
            defer { lock.unlock() }
            Self.body = body
            Self.status = status
            Self.requestCount = 0
        }

        static var count: Int {
            lock.lock()
            defer { lock.unlock() }
            return requestCount
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.lock.lock()
            Self.requestCount += 1
            let body = Self.body
            let status = Self.status
            Self.lock.unlock()

            let response = HTTPURLResponse(
                url: request.url!, statusCode: status,
                httpVersion: nil, headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }

        override func stopLoading() {}
    }

    private func makeViewModel() -> LiveViewModel {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        let api = XtreamAPIService(session: URLSession(configuration: config))
        api.configure(serverUrl: "http://panel.test:8080", username: "u", password: "p")
        return LiveViewModel(api: api)
    }

    private let epgJSON = Data("""
    {"epg_listings":[
      {"id":"1","title":"TmV3cyBhdCBTaXg=","start":"2026-09-13 18:00:00","end":"2026-09-13 18:30:00"}
    ]}
    """.utf8)

    // MARK: - Tests

    func testFetchesOnceAndPopulatesEpg() async {
        StubURLProtocol.reset(body: epgJSON)
        let vm = makeViewModel()

        await vm.loadEpgIfNeeded(for: "42")

        XCTAssertEqual(StubURLProtocol.count, 1, "one focused channel, one request")
        XCTAssertNotNil(vm.currentProgram(for: "42"))
    }

    /// Focus leaving a card and coming back must not cost a second request —
    /// this is the guard that keeps remote-wandering off the panel.
    func testSecondRequestForSameChannelIsServedFromCache() async {
        StubURLProtocol.reset(body: epgJSON)
        let vm = makeViewModel()

        await vm.loadEpgIfNeeded(for: "42")
        await vm.loadEpgIfNeeded(for: "42")
        await vm.loadEpgIfNeeded(for: "42")

        XCTAssertEqual(StubURLProtocol.count, 1, "cached after the first fetch")
    }

    func testDifferentChannelsEachCostOneRequest() async {
        StubURLProtocol.reset(body: epgJSON)
        let vm = makeViewModel()

        await vm.loadEpgIfNeeded(for: "1")
        await vm.loadEpgIfNeeded(for: "2")
        await vm.loadEpgIfNeeded(for: "3")

        XCTAssertEqual(StubURLProtocol.count, 3)
    }

    /// A panel with no EPG answers an empty listing. That answer is cached
    /// deliberately: without it every pass of the focus over a channel on
    /// an EPG-less panel would re-ask, which is the storm again.
    func testEmptyAnswerIsCachedAndNotRefetched() async {
        StubURLProtocol.reset(body: Data(#"{"epg_listings":[]}"#.utf8))
        let vm = makeViewModel()

        await vm.loadEpgIfNeeded(for: "42")
        await vm.loadEpgIfNeeded(for: "42")

        XCTAssertEqual(StubURLProtocol.count, 1)
        XCTAssertNil(vm.currentProgram(for: "42"), "no programme, but no re-ask either")
    }

    /// Concurrent calls for the same channel — two views asking at once —
    /// must collapse into a single request.
    func testConcurrentCallsForSameChannelCollapse() async {
        StubURLProtocol.reset(body: epgJSON)
        let vm = makeViewModel()

        async let a: Void = vm.loadEpgIfNeeded(for: "42")
        async let b: Void = vm.loadEpgIfNeeded(for: "42")
        _ = await (a, b)

        XCTAssertEqual(StubURLProtocol.count, 1)
    }
}
