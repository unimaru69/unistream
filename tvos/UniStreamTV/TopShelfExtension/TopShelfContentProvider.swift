import TVServices
import Foundation

@objc(TopShelfContentProvider)
final class TopShelfContentProvider: TVTopShelfContentProvider {

    private static let appGroupId = "group.fr.unimaru.unistream.tv"
    private static let favoritesKey = "topshelf.favorites.v1"

    override func loadTopShelfContent(completionHandler: @escaping (TVTopShelfContent?) -> Void) {
        NSLog("[UniStreamTopShelf] loadTopShelfContent invoked")

        let hasDefaults = UserDefaults(suiteName: Self.appGroupId) != nil
        var items: [TVTopShelfSectionedItem] = loadFavoriteItems()
        NSLog("[UniStreamTopShelf] group=%@ favs=%d", hasDefaults ? "yes" : "no", items.count)

        // Always show at least a diagnostic tile so we can tell the extension is alive.
        let probe = TVTopShelfSectionedItem(identifier: "__probe__")
        probe.title = "UniStream OK (g=\(hasDefaults ? "y" : "n"), f=\(items.count))"
        probe.imageShape = .square
        if let url = URL(string: "unistream://play?key=__probe__") {
            probe.displayAction = TVTopShelfAction(url: url)
        }
        items.insert(probe, at: 0)

        let section = TVTopShelfItemCollection(items: items)
        section.title = "UniStream"
        let content = TVTopShelfSectionedContent(sections: [section])
        completionHandler(content)
    }

    private func loadFavoriteItems() -> [TVTopShelfSectionedItem] {
        guard let defaults = UserDefaults(suiteName: Self.appGroupId),
              let data = defaults.data(forKey: Self.favoritesKey),
              let payload = try? JSONDecoder().decode([SharedFavorite].self, from: data)
        else {
            return []
        }

        return payload.prefix(12).map { fav in
            let item = TVTopShelfSectionedItem(identifier: fav.key)
            item.title = fav.name
            item.imageShape = .square
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

private struct SharedFavorite: Codable {
    let key: String
    let name: String
    let imageUrl: String?
}
