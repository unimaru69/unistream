import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/logger.dart';
import '../utils/title_year_parser.dart';

/// Lightweight TMDB client — just the endpoints we actually use:
///   GET /search/movie   (pick the best match by title + year)
///   GET /search/tv
///   GET /movie/{id}?append_to_response=credits,videos,images
///   GET /tv/{id}?append_to_response=credits,videos,images
///
/// No third-party SDK: `http` + plain Maps keep things tiny and easily
/// auditable.
class TmdbService {
  TmdbService({required this.apiKey, this.language = 'fr-FR'});

  final String apiKey;
  final String language;

  static const _base = 'https://api.themoviedb.org/3';
  static const _imageBase = 'https://image.tmdb.org/t/p';

  bool get isEnabled => apiKey.isNotEmpty;

  /// Best-effort lookup. Returns null if TMDB is unreachable, disabled or
  /// no match is found.
  Future<TmdbResult?> enrich({
    required String rawTitle,
    required TmdbKind kind,
  }) async {
    if (!isEnabled) return null;
    final parsed = TitleYearParser.parse(rawTitle);
    if (!parsed.isUsable) return null;

    try {
      final match = await _search(parsed, kind);
      if (match == null) return null;
      return _details(match.id, kind);
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'TMDB enrichment failed',
          error: e, stackTrace: st);
      return null;
    }
  }

  Future<_SearchHit?> _search(TitleYear t, TmdbKind kind) async {
    final path = kind == TmdbKind.movie ? '/search/movie' : '/search/tv';
    final uri = Uri.parse('$_base$path').replace(queryParameters: {
      'api_key': apiKey,
      'language': language,
      'query': t.title,
      if (t.year != null)
        kind == TmdbKind.movie ? 'year' : 'first_air_date_year':
            t.year.toString(),
      'include_adult': 'false',
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final results = (body['results'] as List? ?? []).cast<Map<String, dynamic>>();
    if (results.isEmpty) return null;

    // Prefer exact year match if we have a year; otherwise take the most
    // popular result.
    if (t.year != null) {
      final yearField = kind == TmdbKind.movie ? 'release_date' : 'first_air_date';
      for (final r in results) {
        final date = (r[yearField] as String?) ?? '';
        if (date.startsWith(t.year.toString())) {
          return _SearchHit(id: r['id'] as int);
        }
      }
    }
    return _SearchHit(id: results.first['id'] as int);
  }

  Future<TmdbResult?> _details(int id, TmdbKind kind) async {
    final path = kind == TmdbKind.movie ? '/movie/$id' : '/tv/$id';
    final uri = Uri.parse('$_base$path').replace(queryParameters: {
      'api_key': apiKey,
      'language': language,
      'append_to_response': 'credits,videos,images',
      // Also fetch original language images as a fallback when the localized
      // set is empty.
      'include_image_language': '$language,en,null',
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 6));
    if (r.statusCode != 200) return null;
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    return TmdbResult.fromJson(body, kind);
  }

  /// TMDB image URL builder for a given [path] (comes straight from the JSON).
  /// [size] is one of TMDB's accepted sizes: w300 / w500 / w780 / w1280 /
  /// original.
  static String? image(String? path, {String size = 'w780'}) {
    if (path == null || path.isEmpty) return null;
    return '$_imageBase/$size$path';
  }

  /// Person details (name, biography, profile photo, dept). Returns
  /// `null` on miss / disabled / network error.
  Future<TmdbPersonDetails?> fetchPersonDetails(int personId) async {
    if (!isEnabled) return null;
    final uri = Uri.parse('$_base/person/$personId').replace(
      queryParameters: <String, String>{
        'api_key': apiKey,
        'language': language,
      },
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return null;
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      return TmdbPersonDetails.fromJson(body);
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'TMDB fetchPersonDetails failed',
          error: e, stackTrace: st);
      return null;
    }
  }

  /// Person filmography split into movies + TV shows. Sorted by year
  /// (most recent first). Items without a poster are kept — the card
  /// shows a placeholder so we don't hide credits silently.
  Future<({List<TmdbPersonCredit> movies, List<TmdbPersonCredit> tv})>
      fetchPersonCredits(int personId) async {
    if (!isEnabled) {
      return (movies: <TmdbPersonCredit>[], tv: <TmdbPersonCredit>[]);
    }
    final uri = Uri.parse('$_base/person/$personId/combined_credits').replace(
      queryParameters: <String, String>{
        'api_key': apiKey,
        'language': language,
      },
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) {
        return (movies: <TmdbPersonCredit>[], tv: <TmdbPersonCredit>[]);
      }
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final cast = (body['cast'] as List?) ?? const [];
      final movies = <TmdbPersonCredit>[];
      final tv = <TmdbPersonCredit>[];
      // Dedupe on TMDB id within each bucket — a single project
      // sometimes lists the same actor twice (writer + actor).
      final seenMovies = <int>{};
      final seenTv = <int>{};
      for (final raw in cast) {
        final m = raw as Map<String, dynamic>;
        final credit = TmdbPersonCredit.fromJson(m);
        if (credit == null) continue;
        if (credit.mediaType == TmdbKind.movie) {
          if (seenMovies.add(credit.id)) movies.add(credit);
        } else {
          if (seenTv.add(credit.id)) tv.add(credit);
        }
      }
      int yearOrZero(TmdbPersonCredit c) => c.year ?? 0;
      movies.sort((a, b) => yearOrZero(b).compareTo(yearOrZero(a)));
      tv.sort((a, b) => yearOrZero(b).compareTo(yearOrZero(a)));
      return (movies: movies, tv: tv);
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'TMDB fetchPersonCredits failed',
          error: e, stackTrace: st);
      return (movies: <TmdbPersonCredit>[], tv: <TmdbPersonCredit>[]);
    }
  }

  /// Per-episode metadata for a TV season — name, overview, still
  /// image path. Returned keyed by episode number so callers can do
  /// `meta[ep.number]?.stillPath` without scanning a list.
  ///
  /// Returns an empty map on miss / disabled / network error so
  /// callers can ignore failures and fall back gracefully.
  Future<Map<int, EpisodeMeta>> fetchSeason({
    required int tmdbId,
    required int seasonNumber,
  }) async {
    if (!isEnabled) return const <int, EpisodeMeta>{};
    final uri = Uri.parse('$_base/tv/$tmdbId/season/$seasonNumber').replace(
      queryParameters: <String, String>{
        'api_key': apiKey,
        'language': language,
      },
    );
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 6));
      if (r.statusCode != 200) return const <int, EpisodeMeta>{};
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final episodes = (body['episodes'] as List?) ?? const [];
      final out = <int, EpisodeMeta>{};
      for (final e in episodes.cast<Map<String, dynamic>>()) {
        final num = e['episode_number'] as int?;
        if (num == null) continue;
        out[num] = EpisodeMeta(
          episodeNumber: num,
          name: (e['name'] as String?) ?? '',
          overview: (e['overview'] as String?) ?? '',
          stillPath: e['still_path'] as String?,
        );
      }
      return out;
    } catch (e, st) {
      AppLogger.warning(LogModule.ui, 'TMDB fetchSeason failed',
          error: e, stackTrace: st);
      return const <int, EpisodeMeta>{};
    }
  }
}

/// TMDB person details — slim subset for the cast filmography page.
class TmdbPersonDetails {
  const TmdbPersonDetails({
    required this.id,
    required this.name,
    this.biography,
    this.profilePath,
    this.knownForDepartment,
  });

  final int id;
  final String name;
  final String? biography;
  final String? profilePath;

  /// e.g. "Acting", "Directing", "Writing". TMDB-supplied; not
  /// localised but commonly understood. Caller can translate / hide.
  final String? knownForDepartment;

  factory TmdbPersonDetails.fromJson(Map<String, dynamic> j) {
    final bio = (j['biography'] as String?)?.trim();
    return TmdbPersonDetails(
      id: j['id'] as int,
      name: (j['name'] as String?) ?? '',
      biography: (bio == null || bio.isEmpty) ? null : bio,
      profilePath: j['profile_path'] as String?,
      knownForDepartment: j['known_for_department'] as String?,
    );
  }

  String? profileUrl({String size = 'h632'}) =>
      TmdbService.image(profilePath, size: size);
}

/// A single TMDB credit on a person's filmography — used by the cast
/// filmography screen.
class TmdbPersonCredit {
  const TmdbPersonCredit({
    required this.id,
    required this.mediaType,
    required this.title,
    this.character,
    this.posterPath,
    this.year,
  });

  final int id;
  final TmdbKind mediaType;
  final String title;
  final String? character;
  final String? posterPath;
  final int? year;

  static TmdbPersonCredit? fromJson(Map<String, dynamic> j) {
    final mt = j['media_type'] as String?;
    final TmdbKind kind;
    if (mt == 'movie') {
      kind = TmdbKind.movie;
    } else if (mt == 'tv') {
      kind = TmdbKind.tv;
    } else {
      return null; // person → person credits are skipped
    }
    final title =
        ((kind == TmdbKind.movie ? j['title'] : j['name']) as String?) ?? '';
    if (title.isEmpty) return null;
    final dateField =
        kind == TmdbKind.movie ? 'release_date' : 'first_air_date';
    final date = (j[dateField] as String?) ?? '';
    final year = int.tryParse(date.length >= 4 ? date.substring(0, 4) : '');
    final character = (j['character'] as String?)?.trim();
    return TmdbPersonCredit(
      id: j['id'] as int,
      mediaType: kind,
      title: title,
      character: (character == null || character.isEmpty) ? null : character,
      posterPath: j['poster_path'] as String?,
      year: year,
    );
  }

  String? posterUrl({String size = 'w500'}) =>
      TmdbService.image(posterPath, size: size);
}

/// TMDB per-episode metadata. Slim — only fields the UI consumes.
class EpisodeMeta {
  const EpisodeMeta({
    required this.episodeNumber,
    required this.name,
    required this.overview,
    this.stillPath,
  });

  final int episodeNumber;
  final String name;
  final String overview;
  final String? stillPath;

  /// Convenience: full TMDB URL for the still (16:9 thumbnail).
  /// Defaults to `w300` — fine on poster-row cards. Pass `original`
  /// for full screen detail.
  String? stillUrl({String size = 'w300'}) =>
      TmdbService.image(stillPath, size: size);
}

class _SearchHit {
  _SearchHit({required this.id});
  final int id;
}

enum TmdbKind { movie, tv }

/// The subset of TMDB we expose to the app.
class TmdbResult {
  final int id;
  final TmdbKind kind;
  final String title;
  final String? overview;
  final String? tagline;
  final int? year;
  final double? rating;
  final String? posterPath;
  final String? backdropPath;
  final List<TmdbCast> cast;
  final List<TmdbVideo> videos;

  /// Movie: `runtime` (minutes). Series: median of
  /// `episode_run_time[]` rounded. `null` when TMDB has no value.
  /// Used by the VOD / Series detail metadata strip (`2h17` / `47 min`).
  final int? runtime;

  const TmdbResult({
    required this.id,
    required this.kind,
    required this.title,
    this.overview,
    this.tagline,
    this.year,
    this.rating,
    this.posterPath,
    this.backdropPath,
    this.cast = const [],
    this.videos = const [],
    this.runtime,
  });

  factory TmdbResult.fromJson(Map<String, dynamic> j, TmdbKind kind) {
    final title = (kind == TmdbKind.movie ? j['title'] : j['name']) as String? ?? '';
    final dateField = kind == TmdbKind.movie ? 'release_date' : 'first_air_date';
    final date = (j[dateField] as String?) ?? '';
    final year = int.tryParse(date.length >= 4 ? date.substring(0, 4) : '');

    final credits = (j['credits'] as Map?)?.cast<String, dynamic>();
    final cast = (credits?['cast'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .take(12)
        .map(TmdbCast.fromJson)
        .toList();

    final videos = (j['videos'] as Map?)?.cast<String, dynamic>();
    final videoList = (videos?['results'] as List? ?? [])
        .cast<Map<String, dynamic>>()
        .where((v) =>
            v['site'] == 'YouTube' &&
            (v['type'] == 'Trailer' || v['type'] == 'Teaser'))
        .map(TmdbVideo.fromJson)
        .toList();

    // Runtime — TMDB exposes it as `runtime` (minutes) on movies and
    // `episode_run_time` (an array of minute values) on TV. Take the
    // first non-zero entry of the array; some shows ship multiple
    // values for different formats (Q&A vs. main, etc.).
    int? runtime;
    if (kind == TmdbKind.movie) {
      final r = j['runtime'];
      if (r is int && r > 0) runtime = r;
    } else {
      final list = (j['episode_run_time'] as List?) ?? const [];
      for (final v in list) {
        if (v is int && v > 0) {
          runtime = v;
          break;
        }
        if (v is num && v.toInt() > 0) {
          runtime = v.toInt();
          break;
        }
      }
    }

    return TmdbResult(
      id: j['id'] as int,
      kind: kind,
      title: title,
      overview: (j['overview'] as String?)?.trim().isEmpty == true
          ? null
          : j['overview'] as String?,
      tagline: (j['tagline'] as String?)?.trim().isEmpty == true
          ? null
          : j['tagline'] as String?,
      year: year,
      rating: (j['vote_average'] as num?)?.toDouble(),
      posterPath: j['poster_path'] as String?,
      backdropPath: j['backdrop_path'] as String?,
      cast: cast,
      videos: videoList,
      runtime: runtime,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'overview': overview,
        'tagline': tagline,
        'year': year,
        'rating': rating,
        'posterPath': posterPath,
        'backdropPath': backdropPath,
        'cast': cast.map((c) => c.toJson()).toList(),
        'videos': videos.map((v) => v.toJson()).toList(),
        'runtime': runtime,
      };

  factory TmdbResult.fromCache(Map<String, dynamic> j) {
    return TmdbResult(
      id: j['id'] as int,
      kind: TmdbKind.values.firstWhere((k) => k.name == j['kind']),
      title: j['title'] as String? ?? '',
      overview: j['overview'] as String?,
      tagline: j['tagline'] as String?,
      year: j['year'] as int?,
      rating: (j['rating'] as num?)?.toDouble(),
      posterPath: j['posterPath'] as String?,
      backdropPath: j['backdropPath'] as String?,
      cast: ((j['cast'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(TmdbCast.fromJson)
          .toList(),
      videos: ((j['videos'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(TmdbVideo.fromJson)
          .toList(),
      runtime: j['runtime'] as int?,
    );
  }
}

class TmdbCast {
  final int id;
  final String name;
  final String character;
  final String? profilePath;

  const TmdbCast({
    required this.id,
    required this.name,
    required this.character,
    this.profilePath,
  });

  factory TmdbCast.fromJson(Map<String, dynamic> j) => TmdbCast(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        character: j['character'] as String? ?? '',
        profilePath: j['profile_path'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'character': character,
        'profile_path': profilePath,
      };
}

class TmdbVideo {
  final String key;
  final String name;
  final String type;

  const TmdbVideo({required this.key, required this.name, required this.type});

  factory TmdbVideo.fromJson(Map<String, dynamic> j) => TmdbVideo(
        key: j['key'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? 'Trailer',
      );

  Map<String, dynamic> toJson() => {'key': key, 'name': name, 'type': type};

  String get youtubeUrl => 'https://www.youtube.com/watch?v=$key';
}
