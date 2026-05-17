import '../models/account_info.dart';

/// Features that can be gated by subscription tier.
///
/// Kept around so a future monetisation refactor (single paid tier + 7-day
/// trial — cf. auto-memory `project_business_model.md`) can re-introduce
/// per-feature checks without rebuilding the whole list of gated
/// surfaces. Today every value below is unlocked unconditionally — see
/// [FeatureAccess.canUse].
enum Feature {
  collections,
  multipleProfiles,
  parentalControls,
  catchupReplay,
  miniPlayer,
  cloudSync,
  advancedSubtitles,
}

/// Centralised feature-gating logic.
///
/// **All gates are currently suspended** pending the monetisation
/// rework: every feature is unlocked for every account, including
/// signed-out / trial-expired states. Downstream call-sites
/// ([`PremiumGate`](../widgets/premium_gate.dart), `checkPremiumAccess`,
/// `showPremiumRequiredDialog`) flow through this entry-point so a
/// single revert here re-enables tier checks once the new model lands.
///
/// **When re-enabling**: restore the per-feature `switch` and the
/// `account.hasAccess` / `account.isTrialActive` short-circuits in
/// [`canUse`] (see git history for the previous shape), then audit
/// [`maxProfiles`] for the same.
class FeatureAccess {
  FeatureAccess._();

  /// Currently a permanent `true` — see class docs.
  // ignore: avoid_unused_constructor_parameters
  static bool canUse(Feature feature, AccountInfo? account) => true;

  /// Currently a permanent generous cap — see class docs.
  // ignore: avoid_unused_constructor_parameters
  static int maxProfiles(AccountInfo? account) => 10;
}
