import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import '../models/profile.dart';

class ConfigState {
  final List<Profile> profiles;
  final String activeProfileId;
  final bool isConfigured;

  const ConfigState({
    required this.profiles,
    required this.activeProfileId,
    required this.isConfigured,
  });

  ConfigState copyWith({
    List<Profile>? profiles,
    String? activeProfileId,
    bool? isConfigured,
  }) {
    return ConfigState(
      profiles: profiles ?? this.profiles,
      activeProfileId: activeProfileId ?? this.activeProfileId,
      isConfigured: isConfigured ?? this.isConfigured,
    );
  }

  Profile? get activeProfile =>
      profiles.where((p) => p.id == activeProfileId).firstOrNull;
}

class ConfigNotifier extends StateNotifier<ConfigState> {
  ConfigNotifier()
      : super(ConfigState(
          profiles: AppConfig.profiles,
          activeProfileId: AppConfig.activeProfileId,
          isConfigured: AppConfig.isConfigured,
        ));

  void refresh() {
    state = ConfigState(
      profiles: List.of(AppConfig.profiles),
      activeProfileId: AppConfig.activeProfileId,
      isConfigured: AppConfig.isConfigured,
    );
  }

  Future<void> switchProfile(String profileId) async {
    await AppConfig.switchProfile(profileId);
    refresh();
  }

  Future<void> addProfile(Profile profile) async {
    await AppConfig.addProfile(profile);
    refresh();
  }

  Future<void> updateProfile(Profile profile) async {
    await AppConfig.updateProfile(profile);
    refresh();
  }

  Future<void> deleteProfile(String id) async {
    await AppConfig.deleteProfile(id);
    refresh();
  }

  Future<void> save(String server, String user, String pass) async {
    await AppConfig.save(server, user, pass);
    refresh();
  }
}

final configProvider = StateNotifierProvider<ConfigNotifier, ConfigState>((ref) {
  return ConfigNotifier();
});
