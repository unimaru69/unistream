import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_config.dart';
import '../models/profile.dart';
import '../utils/profile_scope.dart';

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
  // `_ref` is optional so the unit-test suite can construct
  // `ConfigNotifier()` without spinning up a ProviderContainer; in that
  // mode `switchProfile` skips the cross-provider invalidation (there's
  // no container to dispatch to anyway). Production paths always go
  // through the provider builder below, which passes a real `Ref`.
  ConfigNotifier([this._ref])
      : super(ConfigState(
          profiles: AppConfig.profiles,
          activeProfileId: AppConfig.activeProfileId,
          isConfigured: AppConfig.isConfigured,
        ));

  final Ref? _ref;

  void refresh() {
    state = ConfigState(
      profiles: List.of(AppConfig.profiles),
      activeProfileId: AppConfig.activeProfileId,
      isConfigured: AppConfig.isConfigured,
    );
  }

  Future<void> switchProfile(String profileId) async {
    await AppConfig.switchProfile(profileId);
    if (!mounted) return;
    final ref = _ref;
    if (ref != null) invalidateProfileScopedProviders(ref.invalidate);
    refresh();
  }

  Future<void> addProfile(Profile profile) async {
    await AppConfig.addProfile(profile);
    if (!mounted) return;
    refresh();
  }

  Future<void> updateProfile(Profile profile) async {
    await AppConfig.updateProfile(profile);
    if (!mounted) return;
    refresh();
  }

  Future<void> deleteProfile(String id) async {
    await AppConfig.deleteProfile(id);
    if (!mounted) return;
    refresh();
  }

  Future<void> save(String server, String user, String pass) async {
    await AppConfig.save(server, user, pass);
    if (!mounted) return;
    refresh();
  }
}

final configProvider = StateNotifierProvider<ConfigNotifier, ConfigState>((ref) {
  return ConfigNotifier(ref);
});
