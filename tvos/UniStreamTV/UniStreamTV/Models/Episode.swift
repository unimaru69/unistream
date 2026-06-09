import Foundation

/// Single episode within a series — mirrors Flutter's `Episode`.
struct Episode: Identifiable, Hashable {
    let episodeId: String
    var title: String?
    var containerExtension: String
    var episodeNum: Int?

    var id: String { episodeId }
    var displayTitle: String { title ?? "Épisode \(episodeNum ?? 0)" }

    init(json: [String: Any]) {
        episodeId = "\(json["id"] ?? "")"
        title = coerceStringOrNull(json["title"])
        containerExtension = coerceStringOrNull(json["container_extension"]) ?? "mp4"
        if let n = json["episode_num"] as? Int {
            episodeNum = n
        } else if let s = json["episode_num"] as? String {
            episodeNum = Int(s)
        }
    }
}
