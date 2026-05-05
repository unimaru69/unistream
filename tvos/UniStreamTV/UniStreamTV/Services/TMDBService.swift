import Foundation
import Observation

/// The Movie Database kind (movie or TV series).
enum TMDBKind: String, Codable {
    case movie
    case tv
}

// MARK: - Models

struct TMDBResult: Codable, Identifiable, Equatable {
    let id: Int
    let kind: TMDBKind
    let title: String
    let overview: String?
    let tagline: String?
    let year: Int?
    let rating: Double?
    let posterPath: String?
    let backdropPath: String?
    let cast: [TMDBCast]
    let videos: [TMDBVideo]

    /// Best-resolution backdrop URL for a given image size. TMDB serves the
    /// original asset behind `original`; we use that for hero banners.
    func backdropURL(size: String = "original") -> URL? {
        TMDBService.imageURL(path: backdropPath, size: size)
    }

    func posterURL(size: String = "w780") -> URL? {
        TMDBService.imageURL(path: posterPath, size: size)
    }
}

struct TMDBCast: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let character: String
    let profilePath: String?

    func profileURL(size: String = "w185") -> URL? {
        TMDBService.imageURL(path: profilePath, size: size)
    }
}

struct TMDBVideo: Codable, Identifiable, Equatable {
    var id: String { key }
    let key: String
    let name: String
    let type: String

    var youtubeURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(key)")
    }
}

// MARK: - Service

/// Thin TMDB client. Stateless except for the API key; caching lives in
/// `TMDBCache`, settings are managed by `TMDBConfig`.
///
/// `@unchecked Sendable`: the service itself has no mutable state. It reads
/// config on every call via `TMDBConfig.shared`.
final class TMDBService: @unchecked Sendable {
    static let shared = TMDBService()

    private let base = URL(string: "https://api.themoviedb.org/3")!
    private static let imageBase = URL(string: "https://image.tmdb.org/t/p")!

    private init() {}

    /// Best-effort enrichment. Returns nil on disabled / unreachable /
    /// no-match. Errors are swallowed by design — this is an enhancement,
    /// never a blocker.
    func enrich(rawTitle: String, kind: TMDBKind) async -> TMDBResult? {
        let cfg = TMDBConfig.shared
        guard cfg.isActive else { return nil }
        let parsed = TitleYearParser.parse(rawTitle)
        guard parsed.isUsable else { return nil }

        // Cache hit first.
        if let cached = TMDBCache.shared.get(kind: kind, title: parsed.title, year: parsed.year) {
            return cached.negative ? nil : cached.result
        }

        // Network.
        do {
            guard let id = try await search(parsed: parsed, kind: kind, apiKey: cfg.apiKey) else {
                TMDBCache.shared.putNegative(kind: kind, title: parsed.title, year: parsed.year)
                return nil
            }
            guard let result = try await details(id: id, kind: kind, apiKey: cfg.apiKey) else {
                TMDBCache.shared.putNegative(kind: kind, title: parsed.title, year: parsed.year)
                return nil
            }
            TMDBCache.shared.put(result, title: parsed.title, year: parsed.year)
            return result
        } catch {
            // Networking errors are silent — we retry on next view.
            return nil
        }
    }

    /// Kicks off a fetch without awaiting — used by grid/hero tap handlers to
    /// warm the cache before the detail screen mounts.
    func prefetch(rawTitle: String, kind: TMDBKind) {
        Task.detached(priority: .utility) {
            _ = await self.enrich(rawTitle: rawTitle, kind: kind)
        }
    }

    // MARK: - Private

    private func search(parsed: TitleYearParser.Result, kind: TMDBKind, apiKey: String) async throws -> Int? {
        var components = URLComponents(url: base.appendingPathComponent(kind == .movie ? "search/movie" : "search/tv"),
                                       resolvingAgainstBaseURL: false)!
        var items: [URLQueryItem] = [
            .init(name: "api_key", value: apiKey),
            .init(name: "language", value: TMDBConfig.shared.language),
            .init(name: "query", value: parsed.title),
            .init(name: "include_adult", value: "false"),
        ]
        if let y = parsed.year {
            items.append(.init(name: kind == .movie ? "year" : "first_air_date_year", value: "\(y)"))
        }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 6
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]], !results.isEmpty else { return nil }

        // Prefer exact year match when we have one.
        let dateKey = kind == .movie ? "release_date" : "first_air_date"
        if let y = parsed.year {
            for r in results {
                if let date = r[dateKey] as? String, date.hasPrefix("\(y)") {
                    return r["id"] as? Int
                }
            }
        }
        return results.first?["id"] as? Int
    }

    private func details(id: Int, kind: TMDBKind, apiKey: String) async throws -> TMDBResult? {
        var components = URLComponents(url: base.appendingPathComponent(kind == .movie ? "movie/\(id)" : "tv/\(id)"),
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "api_key", value: apiKey),
            .init(name: "language", value: TMDBConfig.shared.language),
            .init(name: "append_to_response", value: "credits,videos,images"),
            .init(name: "include_image_language", value: "\(TMDBConfig.shared.language),en,null"),
        ]
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 6
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        let title = (kind == .movie ? json["title"] : json["name"]) as? String ?? ""
        let dateKey = kind == .movie ? "release_date" : "first_air_date"
        let yearStr = (json[dateKey] as? String) ?? ""
        let year = Int(yearStr.prefix(4))

        let creditsRaw = (json["credits"] as? [String: Any])?["cast"] as? [[String: Any]] ?? []
        let cast = creditsRaw.prefix(12).map { c -> TMDBCast in
            TMDBCast(
                id: c["id"] as? Int ?? 0,
                name: c["name"] as? String ?? "",
                character: c["character"] as? String ?? "",
                profilePath: c["profile_path"] as? String
            )
        }

        let videosRaw = (json["videos"] as? [String: Any])?["results"] as? [[String: Any]] ?? []
        let videos = videosRaw.compactMap { v -> TMDBVideo? in
            guard v["site"] as? String == "YouTube",
                  let type = v["type"] as? String,
                  (type == "Trailer" || type == "Teaser"),
                  let key = v["key"] as? String else { return nil }
            return TMDBVideo(key: key, name: v["name"] as? String ?? "", type: type)
        }

        return TMDBResult(
            id: json["id"] as? Int ?? 0,
            kind: kind,
            title: title,
            overview: cleanOptional(json["overview"] as? String),
            tagline: cleanOptional(json["tagline"] as? String),
            year: year,
            rating: json["vote_average"] as? Double,
            posterPath: json["poster_path"] as? String,
            backdropPath: json["backdrop_path"] as? String,
            cast: Array(cast),
            videos: videos
        )
    }

    private func cleanOptional(_ s: String?) -> String? {
        guard let v = s?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        return v
    }

    // MARK: - Image URL helpers

    static func imageURL(path: String?, size: String) -> URL? {
        guard let path = path, !path.isEmpty else { return nil }
        return imageBase.appendingPathComponent(size).appendingPathComponent(path)
    }

    // MARK: - Episode stills

    /// Fetch the per-episode "still" image (16:9 screenshot) — much
    /// more visual in a Continue Watching row than the show's static
    /// poster. Returns the absolute image URL or nil when the request
    /// fails / the episode has no still on TMDB.
    ///
    /// - Parameters:
    ///   - tmdbId: TMDB id of the SHOW (not the episode), as returned by
    ///             `enrich(rawTitle:kind:.tv)`.
    ///   - season: Season number (1-based).
    ///   - episode: Episode number within the season (1-based).
    ///   - size: TMDB image size ("w300", "w500", "original"). Defaults
    ///           to "w500" — sized for our 280×160 CW card without
    ///           wasting bandwidth on full-resolution stills.
    func fetchEpisodeStill(
        tmdbId: Int,
        season: Int,
        episode: Int,
        size: String = "w500"
    ) async -> URL? {
        let cfg = TMDBConfig.shared
        guard cfg.isActive else { return nil }
        let path = "tv/\(tmdbId)/season/\(season)/episode/\(episode)"
        var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            .init(name: "api_key", value: cfg.apiKey),
            .init(name: "language", value: cfg.language),
        ]
        guard let url = components.url else { return nil }

        var request = URLRequest(url: url)
        request.timeoutInterval = 6
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let stillPath = json["still_path"] as? String, !stillPath.isEmpty else { return nil }
            return Self.imageURL(path: stillPath, size: size)
        } catch {
            return nil
        }
    }
}
