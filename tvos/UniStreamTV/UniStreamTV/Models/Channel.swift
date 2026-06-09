import Foundation

/// Live TV channel — mirrors Flutter's `Channel`.
/// Uses manual JSON parsing (like Flutter's `dynamic`) to handle mixed int/string types.
struct Channel: Identifiable, Hashable {
    let streamId: String
    var name: String
    var streamIcon: String?
    var cover: String?
    var categoryId: String?
    var categoryName: String?
    var num: Int?
    var tvArchive: String?
    var tvArchiveDuration: String?
    var added: String?
    var lastModified: String?

    var id: String { streamId }
    var displayIcon: String { streamIcon ?? cover ?? "" }
    var hasCatchup: Bool { tvArchive == "1" }
    var archiveDays: Int { Int(tvArchiveDuration ?? "0") ?? 0 }

    /// Parse from a JSON dictionary — tolerant of int/string mixing.
    init(json: [String: Any]) {
        streamId = "\(json["stream_id"] ?? "")"
        name = coerceString(json["name"])
        streamIcon = coerceStringOrNull(json["stream_icon"])
        cover = coerceStringOrNull(json["cover"])
        categoryId = coerceStringOrNull(json["category_id"])
        categoryName = coerceStringOrNull(json["category_name"])
        if let n = json["num"] as? Int {
            num = n
        } else if let s = json["num"] as? String {
            num = Int(s)
        }
        tvArchive = "\(json["tv_archive"] ?? "0")"
        tvArchiveDuration = "\(json["tv_archive_duration"] ?? "0")"
        added = coerceStringOrNull(json["added"])
        lastModified = coerceStringOrNull(json["last_modified"])
    }
}
