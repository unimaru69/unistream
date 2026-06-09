// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'channel.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Channel _$ChannelFromJson(Map<String, dynamic> json) => _Channel(
  streamId: json['stream_id'],
  name: json['name'] == null ? '' : coerceString(json['name']),
  streamIcon: coerceStringOrNull(json['stream_icon']),
  cover: coerceStringOrNull(json['cover']),
  categoryId: coerceStringOrNull(json['category_id']),
  categoryName: coerceStringOrNull(json['category_name']),
  num: json['num'],
  tvArchive: json['tv_archive'] ?? 0,
  tvArchiveDuration: json['tv_archive_duration'] ?? '0',
  added: coerceStringOrNull(json['added']),
  lastModified: coerceStringOrNull(json['last_modified']),
);

Map<String, dynamic> _$ChannelToJson(_Channel instance) => <String, dynamic>{
  'stream_id': instance.streamId,
  'name': instance.name,
  'stream_icon': instance.streamIcon,
  'cover': instance.cover,
  'category_id': instance.categoryId,
  'category_name': instance.categoryName,
  'num': instance.num,
  'tv_archive': instance.tvArchive,
  'tv_archive_duration': instance.tvArchiveDuration,
  'added': instance.added,
  'last_modified': instance.lastModified,
};
