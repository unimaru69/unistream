class Profile {
  final String id;
  String name;
  String serverUrl;
  String username;
  String password;

  Profile({required this.id, required this.name, required this.serverUrl,
           required this.username, required this.password});

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'serverUrl': serverUrl,
    'username': username, 'password': password,
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String, name: j['name'] as String,
    serverUrl: j['serverUrl'] as String, username: j['username'] as String,
    password: j['password'] as String,
  );
}
