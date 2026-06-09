import 'package:freezed_annotation/freezed_annotation.dart';
import 'json_coerce.dart';

part 'epg_program.freezed.dart';
part 'epg_program.g.dart';

@freezed
abstract class EpgProgram with _$EpgProgram {
  const factory EpgProgram({
    @JsonKey(fromJson: coerceString) @Default('') String title,
    @JsonKey(fromJson: coerceStringOrNull) String? description,
    @JsonKey(fromJson: coerceStringOrNull) String? start,
    @JsonKey(fromJson: coerceStringOrNull) String? end,
    @JsonKey(name: 'start_timestamp', fromJson: coerceStringOrNull) String? startTimestamp,
    @JsonKey(name: 'stop_timestamp', fromJson: coerceStringOrNull) String? stopTimestamp,
    @JsonKey(name: 'start_utc', fromJson: coerceStringOrNull) String? startUtc,
    @JsonKey(name: 'start_server_local', fromJson: coerceStringOrNull) String? startServerLocal,
    @JsonKey(name: 'start_epoch') dynamic startEpoch,
  }) = _EpgProgram;

  factory EpgProgram.fromJson(Map<String, dynamic> json) => _$EpgProgramFromJson(json);
}
