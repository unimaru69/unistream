import 'package:freezed_annotation/freezed_annotation.dart';

part 'episode.freezed.dart';
part 'episode.g.dart';

@freezed
abstract class Episode with _$Episode {
  const factory Episode({
    required dynamic id,
    String? title,
    @JsonKey(name: 'container_extension') @Default('mp4') String containerExtension,
    @JsonKey(name: 'episode_num') dynamic episodeNum,
  }) = _Episode;

  factory Episode.fromJson(Map<String, dynamic> json) => _$EpisodeFromJson(json);
}

extension EpisodeX on Episode {
  String get idStr => id.toString();
  String get displayTitle => title ?? 'Episode ${episodeNum ?? ''}';
  int get number => int.tryParse(episodeNum?.toString() ?? '') ?? 0;
}
