import TVServices
import Foundation

final class TopShelfContentProvider: TVTopShelfContentProvider {

    private static let appGroupId = "group.fr.unimaru.unistream.tv"
    private static let favoritesKey = "topshelf.favorites.v2"
    private static let continueKey = "topshelf.continue.v1"

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        NSLog("[TopShelf] loadTopShelfContent invoked")

        let defaults = UserDefaults(suiteName: Self.appGroupId)
        let hasGroup = defaults != nil
        let favRaw = defaults?.data(forKey: Self.favoritesKey)
        let contRaw = defaults?.data(forKey: Self.continueKey)
        NSLog("[TopShelf] group=%@ favBytes=%d contBytes=%d",
              hasGroup ? "ok" : "nil",
              favRaw?.count ?? -1,
              contRaw?.count ?? -1)

        let continueItems = loadContinueWatchingItems()
        let favoriteItems = loadFavoriteItems()

        // Build sections — only include non-empty ones.
        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []

        if !continueItems.isEmpty {
            let section = TVTopShelfItemCollection(items: continueItems)
            section.title = "Reprendre"
            sections.append(section)
        }

        if !favoriteItems.isEmpty {
            let section = TVTopShelfItemCollection(items: favoriteItems)
            section.title = "Favoris"
            sections.append(section)
        }

        // Diagnostic: always show at least one probe tile so we can tell the
        // extension is running. Can be removed once Top Shelf is confirmed working.
        let probe = TVTopShelfSectionedItem(identifier: "__probe__")
        probe.title = "Extension OK (g=\(hasGroup ? "y" : "n"), f=\(favoriteItems.count), c=\(continueItems.count))"
        probe.imageShape = .square
        if let url = URL(string: "unistream://play?key=__probe__") {
            probe.displayAction = TVTopShelfAction(url: url)
        }
        let diagSection = TVTopShelfItemCollection(items: [probe])
        diagSection.title = "Diagnostic"
        sections.insert(diagSection, at: 0)

        let content = TVTopShelfSectionedContent(sections: sections)
        completionHandler(content)
    }

    // MARK: - Continue Watching

    private func loadContinueWatchingItems() -> [TVTopShelfSectionedItem] {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = defaults.data(forKey: Self.continueKey),
              let payload = try? JSONDecoder().decode([SharedContinueItem].self, from: data)
        else {
            return []
        }

        return payload.prefix(10).map { entry in
            let item = TVTopShelfSectionedItem(identifier: entry.key)
            item.title = entry.name
            item.imageShape = .hdtv
            if let urlString = entry.imageUrl, let url = URL(string: urlString) {
                item.setImageURL(url, for: .screenScale1x)
                item.setImageURL(url, for: .screenScale2x)
            }
            if let deepLink = URL(string: "unistream://play?key=\(entry.key)") {
                item.playAction = TVTopShelfAction(url: deepLink)
                item.displayAction = TVTopShelfAction(url: deepLink)
            }
            return item
        }
    }

    // MARK: - Favorites

    private func loadFavoriteItems() -> [TVTopShelfSectionedItem] {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = defaults.data(forKey: Self.favoritesKey),
              let payload = try? JSONDecoder().decode([SharedFavorite].self, from: data)
        else {
            return []
        }

        return payload.prefix(20).map { fav in
            let item = TVTopShelfSectionedItem(identifier: fav.key)
            item.title = fav.name
            // Live channels → square logos; movies/series → poster shape.
            item.imageShape = fav.mode == "live" ? .square : .poster
            if let urlString = fav.imageUrl, let url = URL(string: urlString) {
                item.setImageURL(url, for: .screenScale1x)
                item.setImageURL(url, for: .screenScale2x)
            }
            if let deepLink = URL(string: "unistream://play?key=\(fav.key)") {
                item.playAction = TVTopShelfAction(url: deepLink)
                item.displayAction = TVTopShelfAction(url: deepLink)
            }
            return item
        }
    }
}

// MARK: - Shared Codable Types

private struct SharedFavorite: Codable {
    let key: String
    let name: String
    let imageUrl: String?
    let mode: String
}

private struct SharedContinueItem: Codable {
    let key: String
    let name: String
    let imageUrl: String?
    let progress: Double
    let updatedAt: TimeInterval
}
