import 'package:freezed_annotation/freezed_annotation.dart';
import 'json_coerce.dart';

part 'series_item.freezed.dart';
part 'series_item.g.dart';

@freezed
abstract class SeriesItem with _$SeriesItem {
  const factory SeriesItem({
    @JsonKey(name: 'series_id') required dynamic seriesId,
    @JsonKey(fromJson: coerceString) @Default('') String name,
    @JsonKey(fromJson: coerceStringOrNull) String? cover,
    @JsonKey(name: 'stream_icon', fromJson: coerceStringOrNull) String? streamIcon,
    @JsonKey(name: 'category_id', fromJson: coerceStringOrNull) String? categoryId,
    @JsonKey(name: 'category_name', fromJson: coerceStringOrNull) String? categoryName,
    @JsonKey(name: 'num_seasons', fromJson: coerceStringOrNull) String? numSeasons,
    @JsonKey(fromJson: coerceStringOrNull) String? rating,
    @JsonKey(fromJson: coerceStringOrNull) String? plot,
    @JsonKey(fromJson: coerceStringOrNull) String? description,
    @JsonKey(fromJson: coerceStringOrNull) String? added,
    @JsonKey(name: 'last_modified', fromJson: coerceStringOrNull) String? lastModified,
  }) = _SeriesItem;

  factory SeriesItem.fromJson(Map<String, dynamic> json) => _$SeriesItemFromJson(json);
}

extension SeriesItemX on SeriesItem {
  String get id => seriesId.toString();
  String get displayIcon => cover ?? streamIcon ?? '';
}
