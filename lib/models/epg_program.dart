import 'package:freezed_annotation/freezed_annotation.dart';

part 'epg_program.freezed.dart';
part 'epg_program.g.dart';

@freezed
abstract class EpgProgram with _$EpgProgram {
  const factory EpgProgram({
    @Default('') String title,
    String? description,
    String? start,
    String? end,
    @JsonKey(name: 'start_timestamp') String? startTimestamp,
    @JsonKey(name: 'stop_timestamp') String? stopTimestamp,
    @JsonKey(name: 'start_utc') String? startUtc,
    @JsonKey(name: 'start_server_local') String? startServerLocal,
    @JsonKey(name: 'start_epoch') dynamic startEpoch,
  }) = _EpgProgram;

  factory EpgProgram.fromJson(Map<String, dynamic> json) => _$EpgProgramFromJson(json);
}
