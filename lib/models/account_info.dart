import 'package:freezed_annotation/freezed_annotation.dart';

part 'account_info.freezed.dart';
part 'account_info.g.dart';

/// The signed-in user's row in `user_accounts`.
///
/// The table still carries trial and subscription columns from the
/// abandoned paid model; the app no longer reads them. Every feature is
/// available to every account.
@freezed
abstract class AccountInfo with _$AccountInfo {
  const factory AccountInfo({
    required String id,
    @Default('') String email,
    @JsonKey(name: 'created_at') DateTime? createdAt,
  }) = _AccountInfo;

  factory AccountInfo.fromJson(Map<String, dynamic> json) =>
      _$AccountInfoFromJson(json);
}
