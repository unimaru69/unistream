import Foundation

/// User account subscription state — mirrors Flutter's `AccountInfo`.
struct AccountInfo: Codable, Identifiable {
    let id: String
    var email: String
    var trialStartedAt: Date
    var subscriptionTier: String
    var subscriptionExpiresAt: Date?
    var crossPlatformLicense: Bool
    var createdAt: Date?

    // MARK: - Computed Properties

    var isTrial: Bool { subscriptionTier == "trial" }

    var trialDaysRemaining: Int {
        guard isTrial else { return 0 }
        let elapsed = Calendar.current.dateComponents([.day], from: trialStartedAt, to: Date()).day ?? 0
        return max(0, min(Constants.trialDays - elapsed, Constants.trialDays))
    }

    var isTrialActive: Bool { isTrial && trialDaysRemaining > 0 }
    var isTrialExpired: Bool { isTrial && trialDaysRemaining <= 0 }

    var hasActiveSubscription: Bool {
        guard !isTrial else { return false }
        guard let expires = subscriptionExpiresAt else { return true }
        return expires > Date()
    }

    var isBasicOrAbove: Bool {
        subscriptionTier == "basic" || subscriptionTier == "premium"
    }

    var isPremium: Bool { subscriptionTier == "premium" }

    /// Whether the user has any form of access (trial or subscription).
    var hasAccess: Bool { isTrialActive || hasActiveSubscription }

    // MARK: - Coding Keys

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case trialStartedAt = "trial_started_at"
        case subscriptionTier = "subscription_tier"
        case subscriptionExpiresAt = "subscription_expires_at"
        case crossPlatformLicense = "cross_platform_license"
        case createdAt = "created_at"
    }

    init(
        id: String,
        email: String = "",
        trialStartedAt: Date = Date(),
        subscriptionTier: String = "trial",
        subscriptionExpiresAt: Date? = nil,
        crossPlatformLicense: Bool = false,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.trialStartedAt = trialStartedAt
        self.subscriptionTier = subscriptionTier
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.crossPlatformLicense = crossPlatformLicense
        self.createdAt = createdAt
    }
}
