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
