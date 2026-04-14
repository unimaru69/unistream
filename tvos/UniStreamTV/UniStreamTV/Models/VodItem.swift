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
        name = json["name"] as? String ?? ""
        streamIcon = json["stream_icon"] as? String
        cover = json["cover"] as? String
        containerExtension = json["container_extension"] as? String ?? "mp4"
        categoryId = json["category_id"].map { "\($0)" }
        categoryName = json["category_name"] as? String
        rating = json["rating"] as? String
        streamType = json["stream_type"] as? String
        plot = json["plot"] as? String
        description = json["description"] as? String
        added = json["added"] as? String
        lastModified = json["last_modified"] as? String
    }
}
