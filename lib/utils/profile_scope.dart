import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/collections_provider.dart';
import '../providers/favorites_provider.dart';
import '../providers/parental_provider.dart';
import '../providers/watch_progress_provider.dart';

/// Invalidate every Riverpod provider whose state is keyed on
/// `AppConfig.activeProfileId`. Call this after the active profile has
/// changed (cold-start `AppConfig.load`, profile switch) so the providers
/// rebuild against the now-current profile instead of holding the data
/// they cached when the profile was still empty/unset.
///
/// Without this, `_initSync` in `main.dart` can instantiate the
/// favorites/watchlist notifiers from a post-frame callback before the
/// splash flow has had a chance to populate `AppConfig.activeProfileId`,
/// pinning them to an empty-string profile for the lifetime of the app.
///
/// Pass either a `WidgetRef.invalidate` (from a Consumer*) or a
/// `Ref.invalidate` (from a provider builder / notifier) — both expose the
/// same `void invalidate(ProviderOrFamily)` shape.
void invalidateProfileScopedProviders(
  void Function(ProviderOrFamily provider) invalidate,
) {
  invalidate(favoritesProvider);
  invalidate(watchlistProvider);
  invalidate(collectionsProvider);
  invalidate(parentalProvider);
  invalidate(historyProvider);
  invalidate(watchProgressProvider);
  invalidate(continueWatchingProvider);
}
