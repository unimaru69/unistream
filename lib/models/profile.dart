/// Available profile avatars (emoji-based).
const profileAvatars = [
  '👤', '👩', '👨', '🧒', '👶', '🧑‍💻', '🎮', '📺',
  '🎬', '🎵', '⚽', '🌟', '🦊', '🐱', '🐶', '🦁',
  '🐼', '🦄', '🌈', '🚀', '🏠', '🎨', '📚', '🍿',
];

class Profile {
  final String id;
  String name;
  String serverUrl;
  String username;
  String password;
  /// Emoji avatar for visual identification.
  String avatar;
  /// Optional SHA-256 PIN hash to lock this profile.
  String? pinHash;

  Profile({required this.id, required this.name, required this.serverUrl,
           required this.username, required this.password,
           this.avatar = '👤', this.pinHash});

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'serverUrl': serverUrl,
    'username': username, 'password': password,
    'avatar': avatar,
    if (pinHash != null) 'pinHash': pinHash,
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String, name: j['name'] as String,
    serverUrl: j['serverUrl'] as String, username: j['username'] as String,
    password: j['password'] as String,
    avatar: j['avatar'] as String? ?? '👤',
    pinHash: j['pinHash'] as String?,
  );
}
