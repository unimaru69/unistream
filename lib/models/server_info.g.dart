// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_info.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserInfo _$UserInfoFromJson(Map<String, dynamic> json) =>
    _UserInfo(auth: json['auth'] ?? 0);

Map<String, dynamic> _$UserInfoToJson(_UserInfo instance) => <String, dynamic>{
  'auth': instance.auth,
};

_ServerDetails _$ServerDetailsFromJson(Map<String, dynamic> json) =>
    _ServerDetails(
      timeNow: json['time_now'] as String?,
      timestampNow: json['timestamp_now'],
    );

Map<String, dynamic> _$ServerDetailsToJson(_ServerDetails instance) =>
    <String, dynamic>{
      'time_now': instance.timeNow,
      'timestamp_now': instance.timestampNow,
    };

_ServerInfo _$ServerInfoFromJson(Map<String, dynamic> json) => _ServerInfo(
  userInfo: json['user_info'] == null
      ? null
      : UserInfo.fromJson(json['user_info'] as Map<String, dynamic>),
  serverInfo: json['server_info'] == null
      ? null
      : ServerDetails.fromJson(json['server_info'] as Map<String, dynamic>),
);

Map<String, dynamic> _$ServerInfoToJson(_ServerInfo instance) =>
    <String, dynamic>{
      'user_info': instance.userInfo,
      'server_info': instance.serverInfo,
    };
