// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Episode _$EpisodeFromJson(Map<String, dynamic> json) => _Episode(
  id: json['id'],
  title: coerceStringOrNull(json['title']),
  containerExtension: json['container_extension'] == null
      ? 'mp4'
      : coerceString(json['container_extension']),
  episodeNum: json['episode_num'],
);

Map<String, dynamic> _$EpisodeToJson(_Episode instance) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'container_extension': instance.containerExtension,
  'episode_num': instance.episodeNum,
};
