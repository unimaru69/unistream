import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Counter bumped whenever something happens that should re-run the
/// startup sync pull (`_initSync` in `main.dart`).
///
/// The bug it patches: when a user signs in via magic link on a fresh
/// install, `_initSync` fires on the `signedIn` AuthChangeEvent — but
/// at that moment `AppConfig.profiles` is empty, so the computed
/// `profileHash` is empty and `pullAll()` returns nothing. The user
/// then walks through `OnboardingScreen` to configure their Xtream
/// server, which finally creates a profile with the SAME credentials
/// as their iOS device → the profileHash now matches → but no further
/// sync was ever triggered, so favorites / watchlist / progress stay
/// invisible until the next cold start.
///
/// Bumping this counter from `OnboardingScreen._authenticate()` (after
/// `_repo.authenticate()` succeeds) makes `_UniStreamAppState` re-run
/// `_initSync` with the now-correct profile, pulling the user's data
/// from Supabase immediately.
final syncTriggerProvider = StateProvider<int>((ref) => 0);
