/// An item currently being watched, used for the "Continue watching" carousel.
class ContinueWatchingItem {
  final String id;
  final String name;
  final String cover;
  final String url;
  final String mode;
  final double ratio;
  final int timestamp;

  const ContinueWatchingItem({
    required this.id,
    required this.name,
    required this.cover,
    required this.url,
    required this.mode,
    required this.ratio,
    required this.timestamp,
  });

  factory ContinueWatchingItem.fromMap(Map<String, dynamic> map) {
    return ContinueWatchingItem(
      id: map['_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      cover: map['cover'] as String? ?? '',
      url: map['url'] as String? ?? '',
      mode: map['mode'] as String? ?? '',
      ratio: (map['_ratio'] as num?)?.toDouble() ?? 0.0,
      timestamp: map['ts'] as int? ?? 0,
    );
  }
}
