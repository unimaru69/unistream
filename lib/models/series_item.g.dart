// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SeriesItem _$SeriesItemFromJson(Map<String, dynamic> json) => _SeriesItem(
  seriesId: json['series_id'],
  name: json['name'] == null ? '' : coerceString(json['name']),
  cover: coerceStringOrNull(json['cover']),
  streamIcon: coerceStringOrNull(json['stream_icon']),
  categoryId: coerceStringOrNull(json['category_id']),
  categoryName: coerceStringOrNull(json['category_name']),
  numSeasons: coerceStringOrNull(json['num_seasons']),
  rating: coerceStringOrNull(json['rating']),
  plot: coerceStringOrNull(json['plot']),
  description: coerceStringOrNull(json['description']),
  added: coerceStringOrNull(json['added']),
  lastModified: coerceStringOrNull(json['last_modified']),
);

Map<String, dynamic> _$SeriesItemToJson(_SeriesItem instance) =>
    <String, dynamic>{
      'series_id': instance.seriesId,
      'name': instance.name,
      'cover': instance.cover,
      'stream_icon': instance.streamIcon,
      'category_id': instance.categoryId,
      'category_name': instance.categoryName,
      'num_seasons': instance.numSeasons,
      'rating': instance.rating,
      'plot': instance.plot,
      'description': instance.description,
      'added': instance.added,
      'last_modified': instance.lastModified,
    };
