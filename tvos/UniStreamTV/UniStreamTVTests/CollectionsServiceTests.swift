import XCTest
@testable import UniStreamTV

@MainActor
final class CollectionsServiceTests: XCTestCase {

    private func freshService() -> CollectionsService {
        let svc = CollectionsService()
        svc.configure(profilePrefix: "test_\(UUID().uuidString)")
        return svc
    }

    private func sampleItem(key: String = "item_1", name: String = "Item", mode: String = "live") -> FavoriteItem {
        FavoriteItem(key: key, name: name, mode: mode)
    }

    // MARK: - Create

    func testCreateCollectionAddsToList() {
        let svc = freshService()
        let col = svc.createCollection(name: "My List")
        XCTAssertEqual(svc.collections.count, 1)
        XCTAssertEqual(col.name, "My List")
        XCTAssertTrue(col.items.isEmpty)
    }

    func testCreateCollectionWithMode() {
        let svc = freshService()
        let col = svc.createCollection(name: "Films", mode: "movie")
        XCTAssertEqual(col.mode, "movie")
    }

    // MARK: - Delete

    func testDeleteCollectionRemovesIt() {
        let svc = freshService()
        let col = svc.createCollection(name: "Temp")
        svc.deleteCollection(id: col.id)
        XCTAssertTrue(svc.collections.isEmpty)
    }

    func testDeleteNonExistentIsNoOp() {
        let svc = freshService()
        _ = svc.createCollection(name: "Keep")
        svc.deleteCollection(id: "nonexistent")
        XCTAssertEqual(svc.collections.count, 1)
    }

    // MARK: - Add Items

    func testAddItemToCollection() {
        let svc = freshService()
        let col = svc.createCollection(name: "Favs")
        svc.addToCollection(collectionId: col.id, item: sampleItem())
        XCTAssertEqual(svc.collections.first?.items.count, 1)
    }

    func testAddDuplicateItemIsIgnored() {
        let svc = freshService()
        let col = svc.createCollection(name: "Favs")
        let item = sampleItem()
        svc.addToCollection(collectionId: col.id, item: item)
        svc.addToCollection(collectionId: col.id, item: item)
        XCTAssertEqual(svc.collections.first?.items.count, 1)
    }

    // MARK: - Remove Items

    func testRemoveItemFromCollection() {
        let svc = freshService()
        let col = svc.createCollection(name: "List")
        svc.addToCollection(collectionId: col.id, item: sampleItem(key: "a"))
        svc.addToCollection(collectionId: col.id, item: sampleItem(key: "b"))
        svc.removeFromCollection(collectionId: col.id, itemKey: "a")
        XCTAssertEqual(svc.collections.first?.items.count, 1)
        XCTAssertEqual(svc.collections.first?.items.first?.key, "b")
    }

    // MARK: - Rename

    func testRenameCollection() {
        let svc = freshService()
        let col = svc.createCollection(name: "Old")
        svc.renameCollection(id: col.id, newName: "New")
        XCTAssertEqual(svc.collections.first?.name, "New")
    }

    // MARK: - Filter by Mode

    func testFilterByMode() {
        let svc = freshService()
        _ = svc.createCollection(name: "Live", mode: "live")
        _ = svc.createCollection(name: "Films", mode: "movie")
        _ = svc.createCollection(name: "All")

        let liveOnly = svc.collections(for: "live")
        XCTAssertEqual(liveOnly.count, 2) // "Live" + "All" (nil mode matches)

        let all = svc.collections(for: nil)
        XCTAssertEqual(all.count, 3)
    }
}
