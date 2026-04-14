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
  /// - Active trial → Basic-equivalent (premium features locked).
  /// - Expired trial with no subscription → no access.
  /// - Basic → basic features only.
  /// - Premium → all features.
  static bool canUse(Feature feature, AccountInfo? account) {
    if (account == null) return false;
    if (!account.hasAccess) return false;

    // All gated features require Premium
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
    if (account != null && account.isPremium && account.hasAccess) return 10;
    return 1;
  }
}
