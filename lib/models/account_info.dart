import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_info.freezed.dart';
part 'account_info.g.dart';

@freezed
abstract class AccountInfo with _$AccountInfo {
  const AccountInfo._();

  const factory AccountInfo({
    required String id,
    @Default('') String email,
    @JsonKey(name: 'trial_started_at') required DateTime trialStartedAt,
    @JsonKey(name: 'subscription_tier') @Default('trial') String subscriptionTier,
    @JsonKey(name: 'subscription_expires_at') DateTime? subscriptionExpiresAt,
    @JsonKey(name: 'cross_platform_license') @Default(false) bool crossPlatformLicense,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _AccountInfo;

  factory AccountInfo.fromJson(Map<String, dynamic> json) =>
      _$AccountInfoFromJson(json);

  /// Whether this account is on a free trial.
  bool get isTrial => subscriptionTier == 'trial';

  /// Number of trial days remaining (0 if expired or not on trial).
  int get trialDaysRemaining {
    if (!isTrial) return 0;
    final elapsed = DateTime.now().toUtc().difference(trialStartedAt.toUtc());
    return (14 - elapsed.inDays).clamp(0, 14);
  }

  /// Whether the trial is currently active (within 14 days).
  bool get isTrialActive => isTrial && trialDaysRemaining > 0;

  /// Whether the trial has expired.
  bool get isTrialExpired => isTrial && trialDaysRemaining <= 0;

  /// Whether the user has an active paid subscription (not expired).
  bool get hasActiveSubscription {
    if (isTrial) return false;
    if (subscriptionExpiresAt == null) return true;
    return subscriptionExpiresAt!.toUtc().isAfter(DateTime.now().toUtc());
  }

  /// Whether the user has basic tier or above.
  bool get isBasicOrAbove =>
      subscriptionTier == 'basic' || subscriptionTier == 'premium';

  /// Whether the user has premium tier.
  bool get isPremium => subscriptionTier == 'premium';

  /// Whether the user can access the app (trial active or subscription active).
  bool get hasAccess => isTrialActive || hasActiveSubscription;
}
