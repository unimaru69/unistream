import Foundation
import os

/// Manages IPTV server profiles (stored locally via UserDefaults).
@MainActor @Observable
final class ProfileManager {
    private let logger = Logger(subsystem: "fr.unimaru.unistream.tv", category: "Profiles")
    private let defaults = UserDefaults.standard
    private let storageKey = "iptv_profiles"

    private(set) var profiles: [Profile] = []
    var activeProfile: Profile?

    init() {
        loadProfiles()
    }

    // MARK: - CRUD

    func addProfile(_ profile: Profile) {
        profiles.append(profile)
        saveProfiles()
        logger.info("Added profile: \(profile.name)")
    }

    func updateProfile(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[index] = profile
        saveProfiles()
        if activeProfile?.id == profile.id {
            activeProfile = profile
        }
    }

    func deleteProfile(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        if activeProfile?.id == profile.id {
            activeProfile = profiles.first
        }
        saveProfiles()
        logger.info("Deleted profile: \(profile.name)")
    }

    func setActive(_ profile: Profile) {
        activeProfile = profile
        defaults.set(profile.id, forKey: "active_profile_id")
    }

    // MARK: - Persistence

    private func loadProfiles() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        do {
            profiles = try JSONDecoder().decode([Profile].self, from: data)
            // Restore active profile
            if let activeId = defaults.string(forKey: "active_profile_id") {
                activeProfile = profiles.first { $0.id == activeId }
            }
            activeProfile = activeProfile ?? profiles.first
        } catch {
            logger.error("Failed to load profiles: \(error.localizedDescription)")
        }
    }

    private func saveProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            defaults.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to save profiles: \(error.localizedDescription)")
        }
    }
}
