import 'package:flutter/foundation.dart';

import '../core/logger.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';
import '../repositories/content_repository.dart';
import '../utils/title_formatting.dart';

/// Result of a [CatalogIndex.match] lookup.
sealed class CatalogMatch {
  const CatalogMatch();
}

class CatalogMatchVod extends CatalogMatch {
  const CatalogMatchVod(this.item);
  final VodItem item;
}

class CatalogMatchSeries extends CatalogMatch {
  const CatalogMatchSeries(this.item);
  final SeriesItem item;
}

class CatalogMatchNotFound extends CatalogMatch {
  const CatalogMatchNotFound();
}

enum CatalogLoadState { idle, loading, ready, failed }

/// What kind of catalogue we're indexing — movies (VOD) or TV series.
/// Public so callers (cast filmography screen) can name it without
/// reaching into the TMDB layer.
enum CatalogKind { movie, tv }

/// In-memory full-catalog index. Mirror of the tvOS
/// `Services/CatalogIndex.swift`. Used by the cast-filmography screen
/// to answer "does the user actually have this title in their Xtream
/// catalogue?" without scanning every category individually.
///
/// Warms up lazily. Two parallel indexes (movies + series), each
/// queryable via [match] and warmable via [warmupIfNeeded]. The
/// `ValueNotifier` states let the UI show "Indexation…" hints while
/// loads are in flight.
class CatalogIndex {
  CatalogIndex({required this.repo});

  final ContentRepository repo;

  final ValueNotifier<CatalogLoadState> movieState =
      ValueNotifier<CatalogLoadState>(CatalogLoadState.idle);
  final ValueNotifier<CatalogLoadState> seriesState =
      ValueNotifier<CatalogLoadState>(CatalogLoadState.idle);

  Map<String, VodItem> _movieIndex = <String, VodItem>{};
  Map<String, SeriesItem> _seriesIndex = <String, SeriesItem>{};

  CatalogMatch match(String title, CatalogKind kind) {
    final normalized = normalize(title);
    if (normalized.isEmpty) return const CatalogMatchNotFound();
    switch (kind) {
      case CatalogKind.movie:
        final v = _movieIndex[normalized];
        return v != null ? CatalogMatchVod(v) : const CatalogMatchNotFound();
      case CatalogKind.tv:
        final s = _seriesIndex[normalized];
        return s != null
            ? CatalogMatchSeries(s)
            : const CatalogMatchNotFound();
    }
  }

  /// Kick a warmup of [kind]. No-op when already loading / ready.
  Future<void> warmupIfNeeded(CatalogKind kind) async {
    switch (kind) {
      case CatalogKind.movie:
        if (movieState.value == CatalogLoadState.loading ||
            movieState.value == CatalogLoadState.ready) {
          return;
        }
        await _loadMovies();
      case CatalogKind.tv:
        if (seriesState.value == CatalogLoadState.loading ||
            seriesState.value == CatalogLoadState.ready) {
          return;
        }
        await _loadSeries();
    }
  }

  Future<void> _loadMovies() async {
    movieState.value = CatalogLoadState.loading;
    try {
      final items = await repo.getVodStreams();
      final dict = <String, VodItem>{};
      for (final it in items) {
        final key = normalize(it.name);
        if (key.isEmpty) continue;
        dict.putIfAbsent(key, () => it);
      }
      _movieIndex = dict;
      movieState.value = CatalogLoadState.ready;
      AppLogger.info(LogModule.ui,
          'CatalogIndex: ${items.length} movies indexed (${dict.length} unique titles)');
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'CatalogIndex movies failed',
          error: e, stackTrace: st);
      movieState.value = CatalogLoadState.failed;
    }
  }

  Future<void> _loadSeries() async {
    seriesState.value = CatalogLoadState.loading;
    try {
      final items = await repo.getSeries();
      final dict = <String, SeriesItem>{};
      for (final it in items) {
        final key = normalize(it.name);
        if (key.isEmpty) continue;
        dict.putIfAbsent(key, () => it);
      }
      _seriesIndex = dict;
      seriesState.value = CatalogLoadState.ready;
      AppLogger.info(LogModule.ui,
          'CatalogIndex: ${items.length} series indexed (${dict.length} unique titles)');
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'CatalogIndex series failed',
          error: e, stackTrace: st);
      seriesState.value = CatalogLoadState.failed;
    }
  }

  /// Strip provider tag, trailing `(YYYY)`, accents, punctuation;
  /// lowercase. Mirror of the Swift `CatalogIndex.normalise` so the
  /// two platforms match titles consistently.
  @visibleForTesting
  static String normalize(String raw) {
    final cleaned = raw.cleanedTitleNoYear;
    final folded = _stripAccents(cleaned);
    final buf = StringBuffer();
    for (final r in folded.runes) {
      final c = String.fromCharCode(r);
      // Keep alphanumerics + whitespace; drop punctuation.
      if (RegExp(r'[A-Za-z0-9 ]').hasMatch(c)) {
        buf.write(c);
      }
    }
    return buf
        .toString()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  /// Diacritic-folding for FR / EN / ES / DE chars common in IPTV
  /// catalogues. Not exhaustive — covers the high-frequency Latin set.
  static String _stripAccents(String input) {
    const map = <String, String>{
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ñ': 'n', 'ç': 'c', 'ÿ': 'y',
      'À': 'A', 'Á': 'A', 'Â': 'A', 'Ä': 'A', 'Ã': 'A', 'Å': 'A',
      'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
      'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Ö': 'O', 'Õ': 'O',
      'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
      'Ñ': 'N', 'Ç': 'C', 'Ÿ': 'Y',
    };
    final buf = StringBuffer();
    for (final r in input.runes) {
      final c = String.fromCharCode(r);
      buf.write(map[c] ?? c);
    }
    return buf.toString();
  }
}
