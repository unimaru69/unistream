// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vod_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VodItem _$VodItemFromJson(Map<String, dynamic> json) => _VodItem(
  streamId: json['stream_id'],
  name: json['name'] == null ? '' : coerceString(json['name']),
  streamIcon: coerceStringOrNull(json['stream_icon']),
  cover: coerceStringOrNull(json['cover']),
  containerExtension: json['container_extension'] == null
      ? 'mp4'
      : coerceString(json['container_extension']),
  categoryId: coerceStringOrNull(json['category_id']),
  categoryName: coerceStringOrNull(json['category_name']),
  rating: coerceStringOrNull(json['rating']),
  streamType: coerceStringOrNull(json['stream_type']),
  plot: coerceStringOrNull(json['plot']),
  description: coerceStringOrNull(json['description']),
  added: coerceStringOrNull(json['added']),
  lastModified: coerceStringOrNull(json['last_modified']),
);

Map<String, dynamic> _$VodItemToJson(_VodItem instance) => <String, dynamic>{
  'stream_id': instance.streamId,
  'name': instance.name,
  'stream_icon': instance.streamIcon,
  'cover': instance.cover,
  'container_extension': instance.containerExtension,
  'category_id': instance.categoryId,
  'category_name': instance.categoryName,
  'rating': instance.rating,
  'stream_type': instance.streamType,
  'plot': instance.plot,
  'description': instance.description,
  'added': instance.added,
  'last_modified': instance.lastModified,
};
