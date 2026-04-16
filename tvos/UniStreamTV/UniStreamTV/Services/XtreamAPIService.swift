import Foundation
import os

/// Xtream API client — mirrors Flutter's `xtream_api.dart` (live TV endpoints for MVP).
@MainActor @Observable
final class XtreamAPIService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "XtreamAPI")
    private let session: URLSession

    // Cache: key → (data, timestamp)
    private var streamCache: [String: (data: [Any], timestamp: Date)] = [:]

    /// Number of cached entries.
    var cacheEntryCount: Int { streamCache.count }

    /// Clear all API response caches.
    func clearStreamCache() {
        streamCache.removeAll()
    }

    private(set) var serverUrl: String = ""
    private(set) var username: String = ""
    private(set) var password: String = ""

    /// Server UTC offset for catch-up timeshift calculations.
    private var serverUtcOffset: TimeInterval = 0

    private var baseUrl: String {
        // Strip trailing slash and avoid doubling player_api.php
        var base = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !base.contains("player_api.php") {
            base += "/player_api.php"
        }
        // No percent encoding — matches Flutter behavior
        return "\(base)?username=\(username)&password=\(password)"
    }

    /// Whether authentication succeeded at least once.
    private(set) var isAuthenticated = false

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = Constants.httpTimeout
        config.timeoutIntervalForResource = 60
        // Match Flutter's User-Agent + close connections to avoid server session limits
        config.httpAdditionalHeaders = [
            "User-Agent": "Dart/3.5 (dart:io)",
            "Connection": "close",
        ]
        session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    func configure(serverUrl: String, username: String, password: String) {
        // Normalize: remove trailing slash, ensure http(s):// prefix
        var url = serverUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "http://\(url)"
        }
        self.serverUrl = url
        self.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
        streamCache.removeAll()
    }

    // MARK: - Authentication

    /// Authenticate and return server info. Throws on auth failure.
    func authenticate() async throws -> ServerInfo {
        guard let url = URL(string: baseUrl) else {
            throw XtreamError.invalidUrl
        }
        logger.info("Authenticating: \(url.absoluteString.prefix(80))…")
        let request = URLRequest(url: url)
        let (data, response) = try await session.dataWithRetry(for: request)
        logger.info("Response: \(data.count) bytes, status \((response as? HTTPURLResponse)?.statusCode ?? -1)")

        // Check HTTP status
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw XtreamError.httpError(http.statusCode)
        }

        // Empty body = likely wrong URL path or redirect
        if data.isEmpty {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw XtreamError.invalidResponse("Réponse vide (HTTP \(status)) — URL: \(url.absoluteString.prefix(100))")
        }

        // Try to parse JSON — show preview on failure
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let preview = String(data: data.prefix(500), encoding: .utf8) ?? "(binary data)"
            logger.error("Non-JSON response: \(preview)")
            throw XtreamError.invalidResponse(preview)
        }

        let userInfo = json["user_info"] as? [String: Any] ?? [:]
        let serverInfo = json["server_info"] as? [String: Any] ?? [:]

        // Check auth
        let auth = "\(userInfo["auth"] ?? "0")"
        guard auth == "1" else { throw XtreamError.authFailed }

        isAuthenticated = true

        // Parse server timezone offset
        loadTimezoneOffset(serverInfo: serverInfo)

        return ServerInfo(
            isAuthenticated: true,
            timeNow: serverInfo["time_now"] as? String ?? "",
            timestampNow: (serverInfo["timestamp_now"] as? Int) ?? 0
        )
    }

    private func loadTimezoneOffset(serverInfo: [String: Any]) {
        guard let timeNow = serverInfo["time_now"] as? String,
              let timestampNow = serverInfo["timestamp_now"] as? Int else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "UTC")

        guard let serverLocal = formatter.date(from: timeNow) else { return }
        let utc = Date(timeIntervalSince1970: TimeInterval(timestampNow))
        let offset = serverLocal.timeIntervalSince(utc)
        // Round to nearest 30 minutes
        serverUtcOffset = (offset / 1800).rounded() * 1800
    }

    // MARK: - Live TV

    func getLiveCategories() async throws -> [Category] {
        if DemoMode.isActive { return DemoData.liveCategories }
        guard let url = URL(string: "\(baseUrl)&action=get_live_categories") else {
            throw XtreamError.invalidUrl
        }
        let request = URLRequest(url: url)
        let (data, _) = try await session.dataWithRetry(for: request)

        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw XtreamError.invalidResponse("Format de catégories invalide")
        }
        return jsonArray.map { Category(json: $0) }
    }

    func getLiveStreams(categoryId: String? = nil) async throws -> [Channel] {
        if DemoMode.isActive {
            guard let catId = categoryId else { return DemoData.liveChannels }
            return DemoData.liveChannels.filter { $0.categoryId == catId }
        }
        let cacheKey = "get_live_streams:\(categoryId ?? "all")"

        // Check cache
        if let cached = streamCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < Constants.streamCacheTTL,
           let channels = cached.data as? [Channel] {
            return channels
        }

        var urlString = "\(baseUrl)&action=get_live_streams"
        if let catId = categoryId {
            urlString += "&category_id=\(catId)"
        }
        guard let url = URL(string: urlString) else {
            throw XtreamError.invalidUrl
        }

        let request = URLRequest(url: url)
        let (data, _) = try await session.dataWithRetry(for: request)

        // Parse with JSONSerialization (tolerant of mixed types, like Flutter)
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw XtreamError.invalidResponse("Format de chaînes invalide")
        }
        let channels = jsonArray.map { Channel(json: $0) }

        // Update cache
        streamCache[cacheKey] = (channels, Date())
        // LRU: trim to 100 entries
        if streamCache.count > 100 {
            let sorted = streamCache.sorted { $0.value.timestamp < $1.value.timestamp }
            for (key, _) in sorted.prefix(streamCache.count - 100) {
                streamCache.removeValue(forKey: key)
            }
        }

        return channels
    }

    // MARK: - Stream URLs

    /// Live stream URL (HLS).
    func liveStreamUrl(streamId: String) -> URL? {
        URL(string: "\(serverUrl)/live/\(username)/\(password)/\(streamId).m3u8")
    }

    /// Timeshift/catch-up URL.
    func timeshiftUrl(streamId: String, startUtc: Date, durationMinutes: Int) -> URL? {
        let serverLocal = startUtc.addingTimeInterval(serverUtcOffset)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd:HH-mm"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let dateStr = formatter.string(from: serverLocal)
        return URL(string: "\(serverUrl)/timeshift/\(username)/\(password)/\(durationMinutes)/\(dateStr)/\(streamId).ts")
    }

    // MARK: - VOD

    func getVodCategories() async throws -> [Category] {
        if DemoMode.isActive { return DemoData.vodCategories }
        guard let url = URL(string: "\(baseUrl)&action=get_vod_categories") else {
            throw XtreamError.invalidUrl
        }
        let (data, _) = try await session.dataWithRetry(for: URLRequest(url: url))
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw XtreamError.invalidResponse("Format de catégories VOD invalide")
        }
        return jsonArray.map { Category(json: $0) }
    }

    func getVodStreams(categoryId: String? = nil) async throws -> [VodItem] {
        if DemoMode.isActive {
            guard let catId = categoryId else { return DemoData.vodItems }
            return DemoData.vodItems.filter { $0.categoryId == catId }
        }
        let cacheKey = "get_vod_streams:\(categoryId ?? "all")"
        if let cached = streamCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < Constants.streamCacheTTL,
           let items = cached.data as? [VodItem] {
            return items
        }

        var urlString = "\(baseUrl)&action=get_vod_streams"
        if let catId = categoryId { urlString += "&category_id=\(catId)" }
        guard let url = URL(string: urlString) else { throw XtreamError.invalidUrl }

        let (data, _) = try await session.dataWithRetry(for: URLRequest(url: url))
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw XtreamError.invalidResponse("Format VOD invalide")
        }
        let items = jsonArray.map { VodItem(json: $0) }
        streamCache[cacheKey] = (items, Date())
        return items
    }

    // MARK: - Series

    func getSeriesCategories() async throws -> [Category] {
        if DemoMode.isActive { return DemoData.seriesCategories }
        guard let url = URL(string: "\(baseUrl)&action=get_series_categories") else {
            throw XtreamError.invalidUrl
        }
        let (data, _) = try await session.dataWithRetry(for: URLRequest(url: url))
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw XtreamError.invalidResponse("Format de catégories séries invalide")
        }
        return jsonArray.map { Category(json: $0) }
    }

    func getSeries(categoryId: String? = nil) async throws -> [SeriesItem] {
        if DemoMode.isActive {
            guard let catId = categoryId else { return DemoData.seriesList }
            return DemoData.seriesList.filter { $0.categoryId == catId }
        }
        let cacheKey = "get_series:\(categoryId ?? "all")"
        if let cached = streamCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < Constants.streamCacheTTL,
           let items = cached.data as? [SeriesItem] {
            return items
        }

        var urlString = "\(baseUrl)&action=get_series"
        if let catId = categoryId { urlString += "&category_id=\(catId)" }
        guard let url = URL(string: urlString) else { throw XtreamError.invalidUrl }

        let (data, _) = try await session.dataWithRetry(for: URLRequest(url: url))
        guard let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw XtreamError.invalidResponse("Format séries invalide")
        }
        let items = jsonArray.map { SeriesItem(json: $0) }
        streamCache[cacheKey] = (items, Date())
        return items
    }

    func getSeriesEpisodes(seriesId: String) async throws -> [String: [Episode]] {
        if DemoMode.isActive { return DemoData.episodes(forSeriesId: seriesId) }
        guard let url = URL(string: "\(baseUrl)&action=get_series_info&series_id=\(seriesId)") else {
            throw XtreamError.invalidUrl
        }
        let (data, _) = try await session.dataWithRetry(for: URLRequest(url: url))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let episodes = json["episodes"] as? [String: Any] else {
            return [:]
        }

        var result: [String: [Episode]] = [:]
        for (season, value) in episodes {
            if let episodeArray = value as? [[String: Any]] {
                result[season] = episodeArray.map { Episode(json: $0) }
            }
        }
        return result
    }

    // MARK: - EPG

    func getShortEpg(streamId: String, limit: Int = 8) async throws -> [EpgProgram] {
        if DemoMode.isActive { return DemoData.shortEpg(streamId: streamId, limit: limit) }
        guard let url = URL(string: "\(baseUrl)&action=get_short_epg&stream_id=\(streamId)&limit=\(limit)") else {
            throw XtreamError.invalidUrl
        }
        let (data, _) = try await session.dataWithRetry(for: URLRequest(url: url))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let listings = json["epg_listings"] as? [[String: Any]] else {
            return []
        }
        return listings.map { EpgProgram(json: $0) }
    }

    /// Full-day EPG for a single channel (used for catch-up program list).
    func getFullDayEpg(streamId: String) async throws -> [EpgProgram] {
        if DemoMode.isActive { return DemoData.shortEpg(streamId: streamId, limit: 24) }
        guard let url = URL(string: "\(baseUrl)&action=get_simple_data_table&stream_id=\(streamId)") else {
            throw XtreamError.invalidUrl
        }
        let (data, _) = try await session.dataWithRetry(for: URLRequest(url: url))
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let listings = json["epg_listings"] as? [[String: Any]] else {
            return []
        }
        return listings.map { EpgProgram(json: $0) }
    }

    /// Timeshift URL using server-local start string (preferred — avoids timezone conversion).
    /// Parses "YYYY-MM-DD HH:mm:ss" → "YYYY-MM-DD:HH-mm" for the URL path.
    func timeshiftUrlFromLocal(streamId: String, serverLocalStart: String, durationMinutes: Int) -> URL? {
        guard !serverLocalStart.isEmpty, durationMinutes > 0 else { return nil }

        // Parse "2026-04-11 20:00:00" → "2026-04-11:20-00"
        let trimmed = serverLocalStart.trimmingCharacters(in: .whitespaces)
        let parts = trimmed.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let datePart = String(parts[0]) // "2026-04-11"
        let timePart = String(parts[1].prefix(5)).replacingOccurrences(of: ":", with: "-") // "20-00"
        let startFmt = "\(datePart):\(timePart)"

        logger.info("Catch-up URL: /timeshift/.../\(durationMinutes)/\(startFmt)/\(streamId).ts")
        return URL(string: "\(serverUrl)/timeshift/\(username)/\(password)/\(durationMinutes)/\(startFmt)/\(streamId).ts")
    }

    // MARK: - Stream URLs (VOD & Series)

    /// VOD stream URL. Returns the original extension — PlayerPresenter handles fallbacks.
    func vodStreamUrl(streamId: String, extension ext: String = "mp4") -> URL? {
        URL(string: "\(serverUrl)/movie/\(username)/\(password)/\(streamId).\(ext)")
    }

    /// Series episode stream URL.
    func seriesStreamUrl(episodeId: String, extension ext: String = "mp4") -> URL? {
        URL(string: "\(serverUrl)/series/\(username)/\(password)/\(episodeId).\(ext)")
    }

    // MARK: - Cache Management

    func clearCache() {
        streamCache.removeAll()
    }
}

// MARK: - Supporting Types

struct ServerInfo {
    let isAuthenticated: Bool
    let timeNow: String
    let timestampNow: Int
}

enum XtreamError: LocalizedError {
    case invalidUrl
    case authFailed
    case httpError(Int)
    case invalidResponse(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidUrl: "URL du serveur invalide"
        case .authFailed: "Échec d'authentification — vérifiez vos identifiants"
        case .httpError(let code): "Erreur serveur (HTTP \(code))"
        case .invalidResponse(let preview): "Réponse invalide du serveur : \(preview.prefix(200))"
        case .networkError(let e): "Erreur réseau : \(e.localizedDescription)"
        }
    }
}
