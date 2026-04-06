// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'favorite_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FavoriteItem _$FavoriteItemFromJson(Map<String, dynamic> json) =>
    _FavoriteItem(
      key: json['key'] as String,
      name: json['name'] as String? ?? '',
      cover: json['cover'] as String? ?? '',
      mode: json['mode'] as String? ?? '',
      streamId: json['stream_id'] as String?,
      seriesId: json['series_id'] as String?,
      categoryId: json['category_id'] as String?,
      containerExtension: json['container_extension'] as String?,
      streamIcon: json['stream_icon'] as String?,
      rating: json['rating'] as String?,
    );

Map<String, dynamic> _$FavoriteItemToJson(_FavoriteItem instance) =>
    <String, dynamic>{
      'key': instance.key,
      'name': instance.name,
      'cover': instance.cover,
      'mode': instance.mode,
      'stream_id': instance.streamId,
      'series_id': instance.seriesId,
      'category_id': instance.categoryId,
      'container_extension': instance.containerExtension,
      'stream_icon': instance.streamIcon,
      'rating': instance.rating,
    };
