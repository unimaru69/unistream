import 'package:freezed_annotation/freezed_annotation.dart';

part 'channel.freezed.dart';
part 'channel.g.dart';

@freezed
abstract class Channel with _$Channel {
  const factory Channel({
    @JsonKey(name: 'stream_id') required dynamic streamId,
    @Default('') String name,
    @JsonKey(name: 'stream_icon') String? streamIcon,
    String? cover,
    @JsonKey(name: 'category_id') String? categoryId,
    @JsonKey(name: 'category_name') String? categoryName,
    @JsonKey(name: 'tv_archive') @Default(0) dynamic tvArchive,
    @JsonKey(name: 'tv_archive_duration') @Default('0') dynamic tvArchiveDuration,
    String? added,
    @JsonKey(name: 'last_modified') String? lastModified,
  }) = _Channel;

  factory Channel.fromJson(Map<String, dynamic> json) => _$ChannelFromJson(json);
}

extension ChannelX on Channel {
  String get id => streamId.toString();
  String get displayIcon => streamIcon ?? cover ?? '';
  bool get hasCatchup => tvArchive.toString() == '1';
  int get archiveDays => int.tryParse(tvArchiveDuration.toString()) ?? 0;
}
