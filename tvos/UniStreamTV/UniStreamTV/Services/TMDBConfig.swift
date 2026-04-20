import Foundation
import Observation
import SwiftUI

/// Configuration for the TMDB enrichment feature.
///
/// Precedence for the API key:
///   1. User-provided key stored in UserDefaults (entered via Settings).
///   2. Bundled key from `Info.plist` → `TMDBAPIKey` (filled in at build
///      time from the `TMDB_API_KEY` env var — see the xcodeproj setting).
///   3. Empty string → feature dormant.
@Observable
final class TMDBConfig: @unchecked Sendable {
    static let shared = TMDBConfig()

    var apiKey: String = "" { didSet { persistKey() } }
    var enabled: Bool = true { didSet { persistEnabled() } }

    /// Language code passed to TMDB (`fr-FR` by default).
    let language: String = "fr-FR"

    /// `true` when both a key is present and the feature isn't disabled.
    var isActive: Bool { enabled && !apiKey.isEmpty }

    private let keyDefaultsKey = "tmdb.user_key"
    private let enabledDefaultsKey = "tmdb.enabled"

    private init() {
        let defaults = UserDefaults.standard
        enabled = (defaults.object(forKey: enabledDefaultsKey) as? Bool) ?? true
        if let stored = defaults.string(forKey: keyDefaultsKey), !stored.isEmpty {
            apiKey = stored
        } else if let bundled = Bundle.main.object(forInfoDictionaryKey: "TMDBAPIKey") as? String,
                  !bundled.isEmpty {
            apiKey = bundled
        }
    }

    private func persistKey() {
        let defaults = UserDefaults.standard
        if apiKey.isEmpty {
            defaults.removeObject(forKey: keyDefaultsKey)
        } else {
            defaults.set(apiKey, forKey: keyDefaultsKey)
        }
    }

    private func persistEnabled() {
        UserDefaults.standard.set(enabled, forKey: enabledDefaultsKey)
    }
}
