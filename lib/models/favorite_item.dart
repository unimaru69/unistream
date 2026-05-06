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
    final rawMode = map['_mode']?.toString() ?? map['mode']?.toString() ?? '';
    return FavoriteItem(
      key: key,
      name: map['name']?.toString() ?? '',
      cover: map['cover']?.toString() ?? map['stream_icon']?.toString() ?? '',
      // tvOS writes `mode: "movie"` for films while Flutter has always
      // filtered by `mode == "vod"`. Both shapes coexist on Supabase
      // and used to silently split the same item into two parallel
      // worlds: a film favourited on tvOS never appeared in the
      // Flutter Films grid because the mode strings didn't match.
      // Normalise on read so the rest of the app sees a single
      // canonical value. Series + live already align.
      mode: _normaliseMode(rawMode),
      streamId: map['stream_id']?.toString(),
      seriesId: map['series_id']?.toString(),
      categoryId: map['category_id']?.toString(),
      containerExtension: map['container_extension']?.toString(),
      streamIcon: map['stream_icon']?.toString(),
      rating: map['rating']?.toString(),
    );
  }

  /// Coerce a free-form mode string into Flutter's canonical set.
  /// `movie` is the only collision today (tvOS writes it; Flutter
  /// expects `vod`); the rest pass through unchanged.
  static String _normaliseMode(String raw) {
    if (raw == 'movie') return 'vod';
    return raw;
  }
}
