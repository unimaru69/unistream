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
        name = coerceString(json["name"])
        cover = coerceStringOrNull(json["cover"])
        streamIcon = coerceStringOrNull(json["stream_icon"])
        categoryId = coerceStringOrNull(json["category_id"])
        categoryName = coerceStringOrNull(json["category_name"])
        numSeasons = coerceStringOrNull(json["num_seasons"])
        rating = coerceStringOrNull(json["rating"])
        plot = coerceStringOrNull(json["plot"])
        description = coerceStringOrNull(json["description"])
        added = coerceStringOrNull(json["added"])
        lastModified = coerceStringOrNull(json["last_modified"])
    }
}
