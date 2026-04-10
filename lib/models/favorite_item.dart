import 'package:freezed_annotation/freezed_annotation.dart';

part 'favorite_item.freezed.dart';
part 'favorite_item.g.dart';

@freezed
abstract class FavoriteItem with _$FavoriteItem {
  const factory FavoriteItem({
    required String key,
    @Default('') String name,
    @Default('') String cover,
    @Default('') String mode,
    @JsonKey(name: 'stream_id') String? streamId,
    @JsonKey(name: 'series_id') String? seriesId,
    @JsonKey(name: 'category_id') String? categoryId,
    @JsonKey(name: 'container_extension') String? containerExtension,
    @JsonKey(name: 'stream_icon') String? streamIcon,
    String? rating,
  }) = _FavoriteItem;

  factory FavoriteItem.fromJson(Map<String, dynamic> json) =>
      _$FavoriteItemFromJson(json);

  /// Convert legacy `Map<String, dynamic>` (from old storage) to [FavoriteItem].
  factory FavoriteItem.fromLegacy(String key, Map<String, dynamic> map) {
    return FavoriteItem(
      key: key,
      name: map['name']?.toString() ?? '',
      cover: map['cover']?.toString() ?? map['stream_icon']?.toString() ?? '',
      mode: map['_mode']?.toString() ?? map['mode']?.toString() ?? '',
      streamId: map['stream_id']?.toString(),
      seriesId: map['series_id']?.toString(),
      categoryId: map['category_id']?.toString(),
      containerExtension: map['container_extension']?.toString(),
      streamIcon: map['stream_icon']?.toString(),
      rating: map['rating']?.toString(),
    );
  }
}
