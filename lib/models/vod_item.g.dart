// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vod_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VodItem _$VodItemFromJson(Map<String, dynamic> json) => _VodItem(
  streamId: json['stream_id'],
  name: json['name'] as String? ?? '',
  streamIcon: json['stream_icon'] as String?,
  cover: json['cover'] as String?,
  containerExtension: json['container_extension'] as String? ?? 'mp4',
  categoryId: json['category_id'] as String?,
  categoryName: json['category_name'] as String?,
  rating: json['rating'] as String?,
  streamType: json['stream_type'] as String?,
  plot: json['plot'] as String?,
  description: json['description'] as String?,
  added: json['added'] as String?,
  lastModified: json['last_modified'] as String?,
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
