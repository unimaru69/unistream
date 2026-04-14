import Foundation

/// App-wide constants.
enum Constants {
    /// RevenueCat public API key (same as Flutter app).
    static let revenueCatApiKey = "appl_hCGnNALIWCBnGEVfAGBDCmodKTR"

    /// Trial duration in days.
    static let trialDays = 14

    /// Xtream API cache TTL for stream lists.
    static let streamCacheTTL: TimeInterval = 300 // 5 minutes

    /// Xtream API cache TTL for EPG data.
    static let epgCacheTTL: TimeInterval = 1800 // 30 minutes

    /// HTTP request timeout.
    static let httpTimeout: TimeInterval = 15

    /// Max HTTP retries.
    static let maxRetries = 3
}
