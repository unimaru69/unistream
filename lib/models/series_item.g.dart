// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SeriesItem _$SeriesItemFromJson(Map<String, dynamic> json) => _SeriesItem(
  seriesId: json['series_id'],
  name: json['name'] as String? ?? '',
  cover: json['cover'] as String?,
  streamIcon: json['stream_icon'] as String?,
  categoryId: json['category_id'] as String?,
  categoryName: json['category_name'] as String?,
  numSeasons: json['num_seasons'] as String?,
  rating: json['rating'] as String?,
  plot: json['plot'] as String?,
  description: json['description'] as String?,
  added: json['added'] as String?,
  lastModified: json['last_modified'] as String?,
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
