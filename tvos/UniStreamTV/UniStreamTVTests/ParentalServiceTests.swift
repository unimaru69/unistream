import XCTest
@testable import UniStreamTV

@MainActor
final class ParentalServiceTests: XCTestCase {

    private func freshService() -> ParentalService {
        let svc = ParentalService()
        svc.configure(profilePrefix: "test_\(UUID().uuidString)")
        return svc
    }

    // MARK: - PIN

    func testSetPinEnablesAndUnlocks() {
        let svc = freshService()
        svc.setPin("1234")
        XCTAssertTrue(svc.isEnabled)
        XCTAssertTrue(svc.isUnlocked)
    }

    func testVerifyCorrectPin() {
        let svc = freshService()
        svc.setPin("5678")
        svc.lock()
        XCTAssertFalse(svc.isUnlocked)
        XCTAssertTrue(svc.verifyPin("5678"))
        XCTAssertTrue(svc.isUnlocked)
    }

    func testVerifyWrongPin() {
        let svc = freshService()
        svc.setPin("1234")
        svc.lock()
        XCTAssertFalse(svc.verifyPin("0000"))
        XCTAssertFalse(svc.isUnlocked)
    }

    func testVerifyPinWithNoPin() {
        let svc = freshService()
        XCTAssertFalse(svc.verifyPin("1234"))
    }

    func testClearPinResetsEverything() {
        let svc = freshService()
        svc.setPin("1234")
        svc.toggleBlockedCategory("cat_1", contentType: .live)
        svc.clearPin()
        XCTAssertFalse(svc.isEnabled)
        XCTAssertFalse(svc.isUnlocked)
        XCTAssertEqual(svc.totalBlockedCount, 0)
    }

    // MARK: - Category Blocking

    func testToggleBlocksAndUnblocks() {
        let svc = freshService()
        svc.setPin("1234")
        svc.toggleBlockedCategory("adult", contentType: .live)
        XCTAssertTrue(svc.isCategoryBlocked("adult", contentType: .live))
        XCTAssertFalse(svc.isCategoryBlocked("adult", contentType: .vod))

        svc.toggleBlockedCategory("adult", contentType: .live)
        XCTAssertFalse(svc.isCategoryBlocked("adult", contentType: .live))
    }

    func testBlockingPerContentType() {
        let svc = freshService()
        svc.setPin("1234")
        svc.toggleBlockedCategory("a", contentType: .live)
        svc.toggleBlockedCategory("b", contentType: .vod)
        svc.toggleBlockedCategory("c", contentType: .series)
        XCTAssertEqual(svc.totalBlockedCount, 3)
    }

    func testDisabledServiceNeverBlocks() {
        let svc = freshService()
        XCTAssertFalse(svc.isCategoryBlocked("anything", contentType: .live))
    }

    // MARK: - Filter

    func testFilterRemovesBlockedWhenLocked() {
        let svc = freshService()
        svc.setPin("1234")
        svc.toggleBlockedCategory("blocked_cat", contentType: .live)
        svc.lock()

        let categories = [
            Category(categoryId: "ok_cat", categoryName: "OK"),
            Category(categoryId: "blocked_cat", categoryName: "Blocked"),
        ]
        let filtered = svc.filterCategories(categories, contentType: .live)
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.categoryId, "ok_cat")
    }

    func testFilterReturnsAllWhenUnlocked() {
        let svc = freshService()
        svc.setPin("1234")
        svc.toggleBlockedCategory("blocked_cat", contentType: .live)
        // Still unlocked after setPin
        let categories = [
            Category(categoryId: "ok_cat"),
            Category(categoryId: "blocked_cat"),
        ]
        let filtered = svc.filterCategories(categories, contentType: .live)
        XCTAssertEqual(filtered.count, 2)
    }
}
