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

    static var isActive: Bool {
        guard let c = current, !c.isEmpty else { return false }
        return true
    }

    /// Forces premium features off (simulates a Basic account).
    static var forcesBasic: Bool { current == "basic" }

    /// Forces premium features on (simulates a Premium account).
    static var forcesPremium: Bool { current == "premium" }
}

/// Centralized feature access logic.
enum FeatureAccess {
    /// ⚠️ All gates lifted while we test the redesigned app on
    /// hardware. The real tier checks below are kept intact (in the
    /// disabled branches) so we can re-enable them in one diff once
    /// the monetisation refactor lands (single tier + 7-day trial).
    static func canUse(_ feature: Feature, account: AccountInfo?) -> Bool {
        return true

        // MARK: - Disabled gating logic (re-enable post-refactor)
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
    /// Same temporary lift as `canUse` — defaults to 10 unconditionally.
    static func maxProfiles(_ account: AccountInfo?) -> Int {
        return 10

        // MARK: - Disabled gating logic (re-enable post-refactor)
        if DebugPlanOverride.forcesPremium { return 10 }
        if DebugPlanOverride.forcesBasic { return 1 }
        guard let account, account.isPremium else { return 1 }
        return 10
    }
}
