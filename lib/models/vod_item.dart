import 'package:freezed_annotation/freezed_annotation.dart';

part 'vod_item.freezed.dart';
part 'vod_item.g.dart';

@freezed
abstract class VodItem with _$VodItem {
  const factory VodItem({
    @JsonKey(name: 'stream_id') required dynamic streamId,
    @Default('') String name,
    @JsonKey(name: 'stream_icon') String? streamIcon,
    String? cover,
    @JsonKey(name: 'container_extension') @Default('mp4') String containerExtension,
    @JsonKey(name: 'category_id') String? categoryId,
    @JsonKey(name: 'category_name') String? categoryName,
    String? rating,
    @JsonKey(name: 'stream_type') String? streamType,
    String? plot,
    String? description,
    String? added,
    @JsonKey(name: 'last_modified') String? lastModified,
  }) = _VodItem;

  factory VodItem.fromJson(Map<String, dynamic> json) => _$VodItemFromJson(json);
}

extension VodItemX on VodItem {
  String get id => streamId.toString();
  String get displayIcon => streamIcon ?? cover ?? '';
}
