// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountInfo _$AccountInfoFromJson(Map<String, dynamic> json) => _AccountInfo(
  id: json['id'] as String,
  email: json['email'] as String? ?? '',
  trialStartedAt: DateTime.parse(json['trial_started_at'] as String),
  subscriptionTier: json['subscription_tier'] as String? ?? 'trial',
  subscriptionExpiresAt: json['subscription_expires_at'] == null
      ? null
      : DateTime.parse(json['subscription_expires_at'] as String),
  crossPlatformLicense: json['cross_platform_license'] as bool? ?? false,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$AccountInfoToJson(
  _AccountInfo instance,
) => <String, dynamic>{
  'id': instance.id,
  'email': instance.email,
  'trial_started_at': instance.trialStartedAt.toIso8601String(),
  'subscription_tier': instance.subscriptionTier,
  'subscription_expires_at': instance.subscriptionExpiresAt?.toIso8601String(),
  'cross_platform_license': instance.crossPlatformLicense,
  'created_at': instance.createdAt?.toIso8601String(),
};
