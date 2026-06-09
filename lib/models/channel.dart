import 'package:freezed_annotation/freezed_annotation.dart';
import 'json_coerce.dart';

part 'channel.freezed.dart';
part 'channel.g.dart';

@freezed
abstract class Channel with _$Channel {
  const factory Channel({
    @JsonKey(name: 'stream_id') required dynamic streamId,
    @JsonKey(fromJson: coerceString) @Default('') String name,
    @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? streamIcon,
    @JsonKey(fromJson: coerceStringOrNull) String? cover,
    @JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? categoryId,
    @JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? categoryName,
    @JsonKey(name: 'num') dynamic num,
    @JsonKey(name: 'tv_archive') @Default(0) dynamic tvArchive,
    @JsonKey(name: 'tv_archive_duration') @Default('0') dynamic tvArchiveDuration,
    @JsonKey(fromJson: coerceStringOrNull) String? added,
    @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? lastModified,
  }) = _Channel;

  factory Channel.fromJson(Map<String, dynamic> json) => _$ChannelFromJson(json);
}

extension ChannelX on Channel {
  String get id => streamId.toString();
  String get displayIcon => streamIcon ?? cover ?? '';
  bool get hasCatchup => tvArchive.toString() == '1';
  int get archiveDays => int.tryParse(tvArchiveDuration.toString()) ?? 0;
}
