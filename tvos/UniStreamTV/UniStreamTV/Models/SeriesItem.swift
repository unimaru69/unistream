import Foundation

/// TV series — mirrors Flutter's `SeriesItem`.
struct SeriesItem: Identifiable, Hashable {
    let seriesId: String
    var name: String
    var cover: String?
    var streamIcon: String?
    var categoryId: String?
    var categoryName: String?
    var numSeasons: String?
    var rating: String?
    var plot: String?
    var description: String?
    var added: String?
    var lastModified: String?

    var id: String { seriesId }
    var displayIcon: String { cover ?? streamIcon ?? "" }

    init(json: [String: Any]) {
        seriesId = "\(json["series_id"] ?? "")"
        name = json["name"] as? String ?? ""
        cover = json["cover"] as? String
        streamIcon = json["stream_icon"] as? String
        categoryId = json["category_id"].map { "\($0)" }
        categoryName = json["category_name"] as? String
        numSeasons = json["num_seasons"].map { "\($0)" }
        rating = json["rating"] as? String
        plot = json["plot"] as? String
        description = json["description"] as? String
        added = json["added"] as? String
        lastModified = json["last_modified"] as? String
    }
}
