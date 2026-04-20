import Foundation

/// Simple on-disk cache for TMDB enrichment results, written to
/// UserDefaults. Entries expire after 30 days (positive hits) or 7 days
/// (negative hits — so we retry on a title that may have appeared on TMDB
/// in the meantime).
///
/// Parity with the Flutter `tmdbLookupProvider` caching layer.
///
/// `@unchecked Sendable`: the only mutable state is UserDefaults, which is
/// documented as thread-safe.
final class TMDBCache: @unchecked Sendable {
    static let shared = TMDBCache()

    private let defaults = UserDefaults.standard
    private let ttlPositive: TimeInterval = 60 * 60 * 24 * 30
    private let ttlNegative: TimeInterval = 60 * 60 * 24 * 7

    private init() {}

    struct Entry {
        let result: TMDBResult?
        let negative: Bool
    }

    func get(kind: TMDBKind, title: String, year: Int?) -> Entry? {
        let key = cacheKey(kind: kind, title: title, year: year)
        guard let dict = defaults.dictionary(forKey: key) else { return nil }
        guard let savedAt = dict["_savedAt"] as? TimeInterval else { return nil }
        let age = Date().timeIntervalSince1970 - savedAt
        let negative = (dict["_negative"] as? Bool) ?? false
        if negative {
            guard age < ttlNegative else { return nil }
            return Entry(result: nil, negative: true)
        }
        guard age < ttlPositive else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
        guard let result = try? JSONDecoder().decode(TMDBResult.self, from: data) else {
            return nil
        }
        return Entry(result: result, negative: false)
    }

    func put(_ result: TMDBResult, title: String, year: Int?) {
        let key = cacheKey(kind: result.kind, title: title, year: year)
        guard let data = try? JSONEncoder().encode(result),
              var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }
        dict["_savedAt"] = Date().timeIntervalSince1970
        dict["_negative"] = false
        defaults.set(dict, forKey: key)
    }

    func putNegative(kind: TMDBKind, title: String, year: Int?) {
        let key = cacheKey(kind: kind, title: title, year: year)
        defaults.set([
            "_savedAt": Date().timeIntervalSince1970,
            "_negative": true,
        ], forKey: key)
    }

    private func cacheKey(kind: TMDBKind, title: String, year: Int?) -> String {
        let normalized = title.lowercased().replacingOccurrences(of: " ", with: "_")
        return "tmdb.cache.\(kind.rawValue).\(normalized).\(year.map(String.init) ?? "na")"
    }
}
