// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Channel _$ChannelFromJson(Map<String, dynamic> json) => _Channel(
  streamId: json['stream_id'],
  name: json['name'] as String? ?? '',
  streamIcon: json['stream_icon'] as String?,
  cover: json['cover'] as String?,
  categoryId: json['category_id'] as String?,
  categoryName: json['category_name'] as String?,
  tvArchive: json['tv_archive'] ?? 0,
  tvArchiveDuration: json['tv_archive_duration'] ?? '0',
  added: json['added'] as String?,
  lastModified: json['last_modified'] as String?,
);

Map<String, dynamic> _$ChannelToJson(_Channel instance) => <String, dynamic>{
  'stream_id': instance.streamId,
  'name': instance.name,
  'stream_icon': instance.streamIcon,
  'cover': instance.cover,
  'category_id': instance.categoryId,
  'category_name': instance.categoryName,
  'tv_archive': instance.tvArchive,
  'tv_archive_duration': instance.tvArchiveDuration,
  'added': instance.added,
  'last_modified': instance.lastModified,
};
