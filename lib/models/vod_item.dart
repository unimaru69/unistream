import 'package:freezed_annotation/freezed_annotation.dart';
import 'json_coerce.dart';

part 'vod_item.freezed.dart';
part 'vod_item.g.dart';

@freezed
abstract class VodItem with _$VodItem {
  const factory VodItem({
    @JsonKey(name: 'stream_id') required dynamic streamId,
    @JsonKey(fromJson: coerceString) @Default('') String name,
    @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? streamIcon,
    @JsonKey(fromJson: coerceStringOrNull) String? cover,
    @JsonKey(name: 'container_extension', fromJson: coerceString) @Default('mp4') String containerExtension,
    @JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? categoryId,
    @JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? categoryName,
    @JsonKey(fromJson: coerceStringOrNull) String? rating,
    @JsonKey(name: 'stream_type', fromJson: coerceStringOrNull) String? streamType,
    @JsonKey(fromJson: coerceStringOrNull) String? plot,
    @JsonKey(fromJson: coerceStringOrNull) String? description,
    @JsonKey(fromJson: coerceStringOrNull) String? added,
    @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? lastModified,
  }) = _VodItem;

  factory VodItem.fromJson(Map<String, dynamic> json) => _$VodItemFromJson(json);
}

extension VodItemX on VodItem {
  String get id => streamId.toString();
  String get displayIcon => streamIcon ?? cover ?? '';
}
