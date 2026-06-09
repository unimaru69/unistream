// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'epg_program.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EpgProgram _$EpgProgramFromJson(Map<String, dynamic> json) => _EpgProgram(
  title: json['title'] == null ? '' : coerceString(json['title']),
  description: coerceStringOrNull(json['description']),
  start: coerceStringOrNull(json['start']),
  end: coerceStringOrNull(json['end']),
  startTimestamp: coerceStringOrNull(json['start_timestamp']),
  stopTimestamp: coerceStringOrNull(json['stop_timestamp']),
  startUtc: coerceStringOrNull(json['start_utc']),
  startServerLocal: coerceStringOrNull(json['start_server_local']),
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
