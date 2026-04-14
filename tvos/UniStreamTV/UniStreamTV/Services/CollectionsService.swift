import Foundation
import os

/// Custom user collections — group favorites into named lists.
@MainActor @Observable
final class CollectionsService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Collections")

    private(set) var collections: [CollectionData] = []
    private var profilePrefix = ""

    // MARK: - Setup

    func configure(profilePrefix: String) {
        self.profilePrefix = profilePrefix
        loadCollections()
    }

    // MARK: - CRUD

    func createCollection(name: String, mode: String? = nil) -> CollectionData {
        let collection = CollectionData(
            id: "\(Int(Date().timeIntervalSince1970 * 1000))",
            name: name,
            items: [],
            mode: mode
        )
        collections.append(collection)
        saveCollections()
        logger.info("Created collection '\(name)'")
        return collection
    }

    func deleteCollection(id: String) {
        collections.removeAll { $0.id == id }
        saveCollections()
    }

    func addToCollection(collectionId: String, item: FavoriteItem) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        // Deduplicate by key
        if !collections[index].items.contains(where: { $0.key == item.key }) {
            collections[index].items.append(item)
            saveCollections()
        }
    }

    func removeFromCollection(collectionId: String, itemKey: String) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        collections[index].items.removeAll { $0.key == itemKey }
        saveCollections()
    }

    func renameCollection(id: String, newName: String) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].name = newName
        saveCollections()
    }

    /// Collections filtered by content mode.
    func collections(for mode: String?) -> [CollectionData] {
        guard let mode else { return collections }
        return collections.filter { $0.mode == nil || $0.mode == mode }
    }

    // MARK: - Persistence

    private func loadCollections() {
        guard let data = UserDefaults.standard.data(forKey: "\(profilePrefix)_collections"),
              let decoded = try? JSONDecoder().decode([CollectionData].self, from: data)
        else { return }
        collections = decoded
    }

    private func saveCollections() {
        guard let data = try? JSONEncoder().encode(collections) else { return }
        UserDefaults.standard.set(data, forKey: "\(profilePrefix)_collections")
    }
}

// MARK: - Model

struct CollectionData: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var items: [FavoriteItem]
    var mode: String?  // Optional scope: "live", "movie", "series"
}
