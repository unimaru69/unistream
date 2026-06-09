import Foundation

/// Video-on-demand item — mirrors Flutter's `VodItem`.
struct VodItem: Identifiable, Hashable {
    let streamId: String
    var name: String
    var streamIcon: String?
    var cover: String?
    var containerExtension: String
    var categoryId: String?
    var categoryName: String?
    var rating: String?
    var streamType: String?
    var plot: String?
    var description: String?
    var added: String?
    var lastModified: String?

    var id: String { streamId }
    var displayIcon: String { streamIcon ?? cover ?? "" }

    init(json: [String: Any]) {
        streamId = "\(json["stream_id"] ?? "")"
        name = coerceString(json["name"])
        streamIcon = coerceStringOrNull(json["stream_icon"])
        cover = coerceStringOrNull(json["cover"])
        containerExtension = coerceStringOrNull(json["container_extension"]) ?? "mp4"
        categoryId = coerceStringOrNull(json["category_id"])
        categoryName = coerceStringOrNull(json["category_name"])
        rating = coerceStringOrNull(json["rating"])
        streamType = coerceStringOrNull(json["stream_type"])
        plot = coerceStringOrNull(json["plot"])
        description = coerceStringOrNull(json["description"])
        added = coerceStringOrNull(json["added"])
        lastModified = coerceStringOrNull(json["last_modified"])
    }
}
