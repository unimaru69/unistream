import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

@freezed
abstract class UserInfo with _$UserInfo {
  const factory UserInfo({
    @Default(0) dynamic auth,
  }) = _UserInfo;

  factory UserInfo.fromJson(Map<String, dynamic> json) => _$UserInfoFromJson(json);
}

extension UserInfoX on UserInfo {
  bool get isAuthenticated => auth.toString() == '1';
}

@freezed
abstract class ServerDetails with _$ServerDetails {
  const factory ServerDetails({
    @JsonKey(name: 'time_now') String? timeNow,
    @JsonKey(name: 'timestamp_now') dynamic timestampNow,
  }) = _ServerDetails;

  factory ServerDetails.fromJson(Map<String, dynamic> json) => _$ServerDetailsFromJson(json);
}

@freezed
abstract class ServerInfo with _$ServerInfo {
  const factory ServerInfo({
    @JsonKey(name: 'user_info') UserInfo? userInfo,
    @JsonKey(name: 'server_info') ServerDetails? serverInfo,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) => _$ServerInfoFromJson(json);
}
