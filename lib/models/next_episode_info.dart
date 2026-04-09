/// Lightweight info about the next episode to auto-play.
class NextEpisodeInfo {
  final String id;
  final String title;
  final String containerExtension;
  final String? coverUrl;

  const NextEpisodeInfo({
    required this.id,
    required this.title,
    required this.containerExtension,
    this.coverUrl,
  });
}
