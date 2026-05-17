import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/content_repository.dart';
import '../services/catalog_index.dart';
import '../services/tmdb_service.dart';
import 'tmdb_provider.dart';

/// Singleton CatalogIndex bound to the active ContentRepository.
/// The index lazy-loads on first warmup call. We don't auto-warm on
/// startup — only the cast-filmography screen needs it today, and
/// holding the full VOD catalogue in memory before it's actually
/// useful would be wasteful on the iPad / phone path.
final catalogIndexProvider = Provider<CatalogIndex>((ref) {
  final repo = ref.read(contentRepositoryProvider);
  return CatalogIndex(repo: repo);
});

/// TMDB person details + filmography for a given TMDB person id.
/// `autoDispose` — bundle holds full filmography lists (could be
/// hundreds of credits per actor). Freed when the cast filmography
/// screen pops.
final tmdbPersonProvider =
    FutureProvider.autoDispose.family<TmdbPersonBundle, int>((ref, personId) async {
  final cfg = ref.watch(tmdbConfigProvider);
  if (!cfg.isActive) {
    return const TmdbPersonBundle(
      details: null,
      movies: <TmdbPersonCredit>[],
      tv: <TmdbPersonCredit>[],
    );
  }
  final svc = ref.read(tmdbServiceProvider);
  // Two parallel calls — `combined_credits` is ~50 % heavier than
  // `details`, but waiting them both in `Future.wait` keeps total
  // wall-time at one TMDB roundtrip.
  final results = await Future.wait<dynamic>(<Future<dynamic>>[
    svc.fetchPersonDetails(personId),
    svc.fetchPersonCredits(personId),
  ]);
  final details = results[0] as TmdbPersonDetails?;
  final credits = results[1]
      as ({List<TmdbPersonCredit> movies, List<TmdbPersonCredit> tv});
  return TmdbPersonBundle(
    details: details,
    movies: credits.movies,
    tv: credits.tv,
  );
});

class TmdbPersonBundle {
  const TmdbPersonBundle({
    required this.details,
    required this.movies,
    required this.tv,
  });

  final TmdbPersonDetails? details;
  final List<TmdbPersonCredit> movies;
  final List<TmdbPersonCredit> tv;
}
