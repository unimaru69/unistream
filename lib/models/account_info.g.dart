// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'account_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AccountInfo _$AccountInfoFromJson(Map<String, dynamic> json) => _AccountInfo(
  id: json['id'] as String,
  email: json['email'] as String? ?? '',
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$AccountInfoToJson(_AccountInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'created_at': instance.createdAt?.toIso8601String(),
    };
