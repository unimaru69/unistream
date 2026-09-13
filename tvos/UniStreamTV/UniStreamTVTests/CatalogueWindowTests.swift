import XCTest
@testable import UniStreamTV

final class CatalogueWindowTests: XCTestCase {

    /// Stand-in for a Channel / VodItem / SeriesItem: all the window cares
    /// about is a stable string id per row.
    private func ids(_ n: Int) -> [String] {
        (0..<n).map { "id\($0)" }
    }

    private let pageSize = CatalogueWindow.pageSize
    private let threshold = CatalogueWindow.extendThreshold

    // MARK: - applied(to:)

    func testShortListIsRenderedWhole() {
        let window = CatalogueWindow()
        let items = ids(10)
        XCTAssertEqual(window.applied(to: items), items)
    }

    func testListExactlyOnePageIsRenderedWhole() {
        let window = CatalogueWindow()
        let items = ids(pageSize)
        XCTAssertEqual(window.applied(to: items).count, pageSize)
    }

    func testLongListIsCappedToOnePage() {
        let window = CatalogueWindow()
        XCTAssertEqual(window.applied(to: ids(5000)).count, pageSize)
    }

    // MARK: - extendIfNeeded

    func testFocusEarlyInWindowDoesNotExtend() {
        var window = CatalogueWindow()
        let items = ids(5000)
        window.extendIfNeeded(focusedId: "id0", in: items, identifiedBy: { $0 })
        XCTAssertEqual(window.applied(to: items).count, pageSize)
    }

    /// The last card *outside* the trigger zone must still not extend —
    /// this is the boundary the threshold is defined by.
    func testFocusJustOutsideThresholdDoesNotExtend() {
        var window = CatalogueWindow()
        let items = ids(5000)
        window.extendIfNeeded(focusedId: "id\(pageSize - threshold - 1)",
                              in: items, identifiedBy: { $0 })
        XCTAssertEqual(window.applied(to: items).count, pageSize)
    }

    func testFocusAtStartOfThresholdExtends() {
        var window = CatalogueWindow()
        let items = ids(5000)
        window.extendIfNeeded(focusedId: "id\(pageSize - threshold)",
                              in: items, identifiedBy: { $0 })
        XCTAssertEqual(window.applied(to: items).count, pageSize * 2)
    }

    func testFocusOnLastRenderedCardExtends() {
        var window = CatalogueWindow()
        let items = ids(5000)
        window.extendIfNeeded(focusedId: "id\(pageSize - 1)",
                              in: items, identifiedBy: { $0 })
        XCTAssertEqual(window.applied(to: items).count, pageSize * 2)
    }

    /// Walking to the end of each successive page should keep paging, and
    /// stop exactly at the catalogue size rather than overshooting it.
    func testRepeatedExtensionsClampToCatalogueSize() {
        var window = CatalogueWindow()
        let total = pageSize * 3 + 17
        let items = ids(total)

        for _ in 0..<10 {
            let last = window.applied(to: items).count - 1
            window.extendIfNeeded(focusedId: "id\(last)", in: items, identifiedBy: { $0 })
        }

        XCTAssertEqual(window.applied(to: items).count, total)
    }

    func testExtendIsNoOpOnceEverythingIsRendered() {
        var window = CatalogueWindow()
        let items = ids(20)
        window.extendIfNeeded(focusedId: "id19", in: items, identifiedBy: { $0 })
        XCTAssertEqual(window.applied(to: items).count, 20)
    }

    /// A focus id that isn't in the list at all (stale `@FocusState` after
    /// the list changed under it) must not move the window.
    func testUnknownFocusIdDoesNotExtend() {
        var window = CatalogueWindow()
        let items = ids(5000)
        window.extendIfNeeded(focusedId: "nope", in: items, identifiedBy: { $0 })
        XCTAssertEqual(window.applied(to: items).count, pageSize)
    }

    // MARK: - reset

    func testResetReturnsToOnePage() {
        var window = CatalogueWindow()
        let items = ids(5000)
        window.extendIfNeeded(focusedId: "id\(pageSize - 1)", in: items, identifiedBy: { $0 })
        XCTAssertEqual(window.applied(to: items).count, pageSize * 2)

        window.reset()
        XCTAssertEqual(window.applied(to: items).count, pageSize)
    }
}
