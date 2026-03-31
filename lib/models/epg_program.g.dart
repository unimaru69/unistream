// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_program.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EpgProgram _$EpgProgramFromJson(Map<String, dynamic> json) => _EpgProgram(
  title: json['title'] as String? ?? '',
  description: json['description'] as String?,
  start: json['start'] as String?,
  end: json['end'] as String?,
  startTimestamp: json['start_timestamp'] as String?,
  stopTimestamp: json['stop_timestamp'] as String?,
  startUtc: json['start_utc'] as String?,
  startServerLocal: json['start_server_local'] as String?,
  startEpoch: json['start_epoch'],
);

Map<String, dynamic> _$EpgProgramToJson(_EpgProgram instance) =>
    <String, dynamic>{
      'title': instance.title,
      'description': instance.description,
      'start': instance.start,
      'end': instance.end,
      'start_timestamp': instance.startTimestamp,
      'stop_timestamp': instance.stopTimestamp,
      'start_utc': instance.startUtc,
      'start_server_local': instance.startServerLocal,
      'start_epoch': instance.startEpoch,
    };
