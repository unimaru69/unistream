import 'package:freezed_annotation/freezed_annotation.dart';

part 'series_item.freezed.dart';
part 'series_item.g.dart';

@freezed
abstract class SeriesItem with _$SeriesItem {
  const factory SeriesItem({
    @JsonKey(name: 'series_id') required dynamic seriesId,
    @Default('') String name,
    String? cover,
    @JsonKey(name: 'stream_icon') String? streamIcon,
    @JsonKey(name: 'category_id') String? categoryId,
    @JsonKey(name: 'category_name') String? categoryName,
    @JsonKey(name: 'num_seasons') String? numSeasons,
    String? rating,
    String? plot,
    String? description,
    String? added,
    @JsonKey(name: 'last_modified') String? lastModified,
  }) = _SeriesItem;

  factory SeriesItem.fromJson(Map<String, dynamic> json) => _$SeriesItemFromJson(json);
}

extension SeriesItemX on SeriesItem {
  String get id => seriesId.toString();
  String get displayIcon => cover ?? streamIcon ?? '';
}
