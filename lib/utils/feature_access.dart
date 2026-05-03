import '../models/account_info.dart';

/// Features that can be gated by subscription tier.
enum Feature {
  collections,
  multipleProfiles,
  parentalControls,
  catchupReplay,
  miniPlayer,
  cloudSync,
  advancedSubtitles,
}

/// Centralized feature-gating logic.
///
/// All tier checks go through this class so gating rules live in one place.
class FeatureAccess {
  FeatureAccess._();

  /// Whether [feature] is available for the given [account].
  ///
  /// Rules:
  /// - `null` account → no access.
  /// - Active trial → full Premium access (essai = Premium complet).
  /// - Expired trial with no subscription → no access.
  /// - Basic → basic features only.
  /// - Premium → all features.
  ///
  /// (The full monetization model is being simplified to a single paid
  /// tier with a 7-day trial in a follow-up refactor; for now this helper
  /// just unlocks Premium during the active trial so cloud sync — and
  /// every other gated feature — works in TestFlight without requiring
  /// a Sandbox subscription.)
  static bool canUse(Feature feature, AccountInfo? account) {
    if (account == null) return false;
    if (!account.hasAccess) return false;

    // Active trial gets the full Premium feature set.
    if (account.isTrialActive) return true;

    switch (feature) {
      case Feature.collections:
      case Feature.multipleProfiles:
      case Feature.parentalControls:
      case Feature.catchupReplay:
      case Feature.miniPlayer:
      case Feature.advancedSubtitles:
      case Feature.cloudSync:
        return account.isPremium;
    }
  }

  /// Maximum number of IPTV profiles allowed for [account].
  static int maxProfiles(AccountInfo? account) {
    if (account == null || !account.hasAccess) return 1;
    if (account.isTrialActive || account.isPremium) return 10;
    return 1;
  }
}
