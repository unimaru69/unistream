import Foundation
import CryptoKit
import os

/// Parental controls — PIN protection + category blocking.
@MainActor @Observable
final class ParentalService {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Parental")

    /// Whether a PIN is set.
    private(set) var isEnabled = false

    /// Whether the current session has been unlocked.
    var isUnlocked = false

    /// Blocked category IDs per content type.
    private(set) var blockedLiveCategories: Set<String> = []
    private(set) var blockedVodCategories: Set<String> = []
    private(set) var blockedSeriesCategories: Set<String> = []

    private var pinHash: String?
    private var profilePrefix = ""

    // MARK: - Setup

    func configure(profilePrefix: String) {
        self.profilePrefix = profilePrefix
        loadState()
    }

    // MARK: - PIN Management

    func setPin(_ pin: String) {
        let hash = sha256(pin)
        pinHash = hash
        UserDefaults.standard.set(hash, forKey: key("parental_pin_hash"))
        isEnabled = true
        isUnlocked = true
        logger.info("Parental PIN set")
    }

    func verifyPin(_ pin: String) -> Bool {
        guard let stored = pinHash else { return false }
        let hash = sha256(pin)
        // Constant-time comparison
        guard hash.count == stored.count else { return false }
        var result: UInt8 = 0
        for (a, b) in zip(hash.utf8, stored.utf8) {
            result |= a ^ b
        }
        let valid = result == 0
        if valid { isUnlocked = true }
        return valid
    }

    func clearPin() {
        pinHash = nil
        UserDefaults.standard.removeObject(forKey: key("parental_pin_hash"))
        isEnabled = false
        isUnlocked = false
        blockedLiveCategories = []
        blockedVodCategories = []
        blockedSeriesCategories = []
        saveBlockedCategories()
        logger.info("Parental controls disabled")
    }

    func lock() {
        isUnlocked = false
    }

    // MARK: - Category Blocking

    func setBlockedCategories(live: Set<String>, vod: Set<String>, series: Set<String>) {
        blockedLiveCategories = live
        blockedVodCategories = vod
        blockedSeriesCategories = series
        saveBlockedCategories()
    }

    func toggleBlockedCategory(_ categoryId: String, contentType: ContentType) {
        switch contentType {
        case .live:
            if blockedLiveCategories.contains(categoryId) {
                blockedLiveCategories.remove(categoryId)
            } else {
                blockedLiveCategories.insert(categoryId)
            }
        case .vod:
            if blockedVodCategories.contains(categoryId) {
                blockedVodCategories.remove(categoryId)
            } else {
                blockedVodCategories.insert(categoryId)
            }
        case .series:
            if blockedSeriesCategories.contains(categoryId) {
                blockedSeriesCategories.remove(categoryId)
            } else {
                blockedSeriesCategories.insert(categoryId)
            }
        }
        saveBlockedCategories()
    }

    func isCategoryBlocked(_ categoryId: String, contentType: ContentType) -> Bool {
        guard isEnabled else { return false }
        switch contentType {
        case .live: return blockedLiveCategories.contains(categoryId)
        case .vod: return blockedVodCategories.contains(categoryId)
        case .series: return blockedSeriesCategories.contains(categoryId)
        }
    }

    /// Filter out blocked categories from a list.
    func filterCategories(_ categories: [Category], contentType: ContentType) -> [Category] {
        guard isEnabled && !isUnlocked else { return categories }
        return categories.filter { !isCategoryBlocked($0.categoryId, contentType: contentType) }
    }

    var totalBlockedCount: Int {
        blockedLiveCategories.count + blockedVodCategories.count + blockedSeriesCategories.count
    }

    // MARK: - Types

    enum ContentType: String {
        case live, vod, series
    }

    // MARK: - Private

    private func loadState() {
        pinHash = UserDefaults.standard.string(forKey: key("parental_pin_hash"))
        isEnabled = pinHash != nil
        isUnlocked = false

        if let data = UserDefaults.standard.data(forKey: key("blocked_live")),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            blockedLiveCategories = ids
        }
        if let data = UserDefaults.standard.data(forKey: key("blocked_vod")),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            blockedVodCategories = ids
        }
        if let data = UserDefaults.standard.data(forKey: key("blocked_series")),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            blockedSeriesCategories = ids
        }
    }

    private func saveBlockedCategories() {
        let encoder = JSONEncoder()
        UserDefaults.standard.set(try? encoder.encode(blockedLiveCategories), forKey: key("blocked_live"))
        UserDefaults.standard.set(try? encoder.encode(blockedVodCategories), forKey: key("blocked_vod"))
        UserDefaults.standard.set(try? encoder.encode(blockedSeriesCategories), forKey: key("blocked_series"))
    }

    private func key(_ suffix: String) -> String {
        "\(profilePrefix)_\(suffix)"
    }

    private func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
