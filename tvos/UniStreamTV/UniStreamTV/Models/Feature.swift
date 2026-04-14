import Foundation

/// Gated features — mirrors Flutter's `FeatureAccess`.
enum Feature: String, CaseIterable {
    case collections
    case multipleProfiles
    case parentalControls
    case catchupReplay
    case cloudSync
    case advancedSubtitles
}

/// Debug-only tier override for testing feature gating on a single account.
/// Values: "basic", "premium", "trial", or nil to use the real account tier.
enum DebugPlanOverride {
    private static let key = "debug.plan.override"

    static var current: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    static var isActive: Bool { current != nil }

    /// Forces premium features off (simulates a Basic account).
    static var forcesBasic: Bool { current == "basic" }

    /// Forces premium features on (simulates a Premium account).
    static var forcesPremium: Bool { current == "premium" }
}

/// Centralized feature access logic.
enum FeatureAccess {
    /// Check if user can use a feature based on account info.
    static func canUse(_ feature: Feature, account: AccountInfo?) -> Bool {
        // Debug override: "premium" unlocks everything regardless of real tier.
        if DebugPlanOverride.forcesPremium {
            return true
        }

        // Debug override: "basic" forces premium features off regardless of real tier.
        if DebugPlanOverride.forcesBasic {
            switch feature {
            case .collections, .multipleProfiles, .parentalControls,
                 .catchupReplay, .advancedSubtitles:
                return false
            case .cloudSync:
                return true
            }
        }

        guard let account, account.hasAccess else { return false }

        switch feature {
        case .collections, .multipleProfiles, .parentalControls,
             .catchupReplay, .advancedSubtitles:
            return account.isPremium
        case .cloudSync:
            // Cloud sync available for all tiers (basic+)
            return account.isBasicOrAbove || account.isTrialActive
        }
    }

    /// Maximum profiles allowed for the account tier.
    static func maxProfiles(_ account: AccountInfo?) -> Int {
        if DebugPlanOverride.forcesPremium { return 10 }
        if DebugPlanOverride.forcesBasic { return 1 }
        guard let account, account.isPremium else { return 1 }
        return 10
    }
}
