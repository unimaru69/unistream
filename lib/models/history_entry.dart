/// A single entry in the watch history.
class HistoryEntry {
  final String key;
  final String name;
  final String cover;
  final String url;
  final String mode;
  final String timestamp;

  const HistoryEntry({
    required this.key,
    required this.name,
    required this.cover,
    required this.url,
    required this.mode,
    required this.timestamp,
  });

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    return HistoryEntry(
      key: map['key'] as String? ?? '',
      name: map['name'] as String? ?? '',
      cover: map['cover'] as String? ?? '',
      url: map['url'] as String? ?? '',
      mode: map['mode'] as String? ?? '',
      timestamp: map['timestamp'] as String? ?? '',
    );
  }

  Map<String, String> toMap() => {
    'key': key,
    'name': name,
    'cover': cover,
    'url': url,
    'mode': mode,
    'timestamp': timestamp,
  };
}
