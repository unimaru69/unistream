import Foundation

/// A favorited or watchlisted item — synced to Supabase `user_favorites`.
/// JSON structure must match Flutter's FavoriteItem exactly for cross-platform sync.
struct FavoriteItem: Codable, Identifiable, Hashable {
    var key: String
    var name: String
    var cover: String?
    var mode: String  // "live", "movie", "series"
    var streamId: String?
    var seriesId: String?
    var categoryId: String?
    var containerExtension: String?
    var streamIcon: String?
    var rating: String?

    var id: String { key }
    var displayIcon: String { cover ?? streamIcon ?? "" }

    enum CodingKeys: String, CodingKey {
        case key, name, cover, mode
        case streamId = "stream_id"
        case seriesId = "series_id"
        case categoryId = "category_id"
        case containerExtension = "container_extension"
        case streamIcon = "stream_icon"
        case rating
    }

    /// Create from a Channel.
    static func from(channel: Channel) -> FavoriteItem {
        FavoriteItem(
            key: channel.streamId,
            name: channel.name,
            cover: channel.cover,
            mode: "live",
            streamId: channel.streamId,
            categoryId: channel.categoryId,
            streamIcon: channel.streamIcon
        )
    }

    /// Create from a VodItem.
    static func from(vod: VodItem) -> FavoriteItem {
        FavoriteItem(
            key: vod.streamId,
            name: vod.name,
            cover: vod.cover,
            mode: "movie",
            streamId: vod.streamId,
            categoryId: vod.categoryId,
            containerExtension: vod.containerExtension,
            streamIcon: vod.streamIcon,
            rating: vod.rating
        )
    }

    /// Create from a SeriesItem.
    static func from(series: SeriesItem) -> FavoriteItem {
        FavoriteItem(
            key: series.seriesId,
            name: series.name,
            cover: series.cover,
            mode: "series",
            seriesId: series.seriesId,
            categoryId: series.categoryId,
            streamIcon: series.streamIcon,
            rating: series.rating
        )
    }

    // MARK: - Cross-platform mode normalisation
    //
    // Flutter writes `mode: 'vod'` when the user favorites a movie; tvOS
    // writes `mode: 'movie'`. Both shapes coexist in Supabase
    // `user_favorites.item_json` and we have to tolerate either side
    // when filtering.

    var isLive: Bool { mode == "live" }
    var isMovie: Bool { mode == "movie" || mode == "vod" }
    var isSeries: Bool { mode == "series" }

    /// Stream id that survives the legacy `"live:STREAMID"` key format —
    /// some older entries carry the prefix in `key` but the bare id in
    /// `streamId`. Prefer `streamId`, fall back to stripping the prefix.
    var resolvedStreamId: String? {
        if let s = streamId, !s.isEmpty { return s }
        if key.hasPrefix("live:") { return String(key.dropFirst("live:".count)) }
        if key.hasPrefix("vod:") { return String(key.dropFirst("vod:".count)) }
        return key
    }
}
