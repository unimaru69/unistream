import 'dart:convert';
import '../models/category.dart' as cat;
import '../models/channel.dart';
import '../models/episode.dart';
import '../models/series_item.dart';
import '../models/vod_item.dart';

/// Fictional data used when the app runs in demo mode (--dart-define=DEMO=true).
/// Channel/movie/series names are generic and do NOT reference real
/// copyrighted brands. Placeholder images are served from placehold.co.
class DemoData {
  DemoData._();

  static const _fg = 'FFFFFF';

  /// Rich color palette — each poster picks deterministically from this list
  /// based on a hash of its title, so the same title always gets the same color
  /// but different titles get different colors for visual variety.
  static const _palette = [
    'C62828', // red
    '2E7D32', // green
    '6A1B9A', // purple
    'EF6C00', // orange
    'AD1457', // pink
    '00838F', // cyan
    '1565C0', // blue
    'B71C1C', // dark red
    '283593', // indigo
    'F9A825', // gold
    '4E342E', // brown
    '1A237E', // deep blue
    '4A148C', // violet
    '006064', // dark cyan
    'E65100', // dark orange
    '37474F', // blue grey
  ];

  static String _colorFor(String label) {
    // If the key is purely numeric (an item id), use it as direct index for
    // deterministic diversity. Otherwise FNV-1a hash.
    final asInt = int.tryParse(label);
    if (asInt != null) return _palette[asInt % _palette.length];
    var hash = 0x811C9DC5;
    for (final c in label.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return _palette[hash % _palette.length];
  }

  static String _poster(String label, {String? colorKey}) =>
      'https://placehold.co/400x600/${_colorFor(colorKey ?? label)}/$_fg/png?text=${Uri.encodeComponent(label)}';

  static String _square(String label, {String? colorKey}) =>
      'https://placehold.co/300x300/${_colorFor(colorKey ?? label)}/$_fg/png?text=${Uri.encodeComponent(label)}';

  /// Square with a 1-letter label, color hashed from a stable key.
  static String _squareFor(String channelName, String id) {
    final letter = channelName.substring(0, 1).toUpperCase();
    return 'https://placehold.co/300x300/${_colorFor(id)}/$_fg/png?text=${Uri.encodeComponent(letter)}';
  }

  // ── Live Categories ──
  static final liveCategories = <cat.Category>[
    cat.Category(categoryId: 'l1', categoryName: 'Actualités'),
    cat.Category(categoryId: 'l2', categoryName: 'Sport'),
    cat.Category(categoryId: 'l3', categoryName: 'Documentaire'),
    cat.Category(categoryId: 'l4', categoryName: 'Jeunesse'),
    cat.Category(categoryId: 'l5', categoryName: 'Musique'),
    cat.Category(categoryId: 'l6', categoryName: 'Culture'),
    cat.Category(categoryId: 'l7', categoryName: 'Lifestyle'),
  ];

  // ── Live Channels ──
  static final liveChannels = <Channel>[
    _chan('1', 'News Channel HD', 'l1', 1),
    _chan('2', 'Info 24', 'l1', 2),
    _chan('3', 'World News Live', 'l1', 3),
    _chan('4', 'Business Today', 'l1', 4),
    _chan('5', 'Sports HD', 'l2', 10),
    _chan('6', 'Sport Action', 'l2', 11),
    _chan('7', 'Football Live', 'l2', 12),
    _chan('8', 'Tennis+', 'l2', 13),
    _chan('9', 'Discovery World', 'l3', 20),
    _chan('10', 'Nature TV', 'l3', 21),
    _chan('11', 'Science Channel', 'l3', 22),
    _chan('12', 'History Plus', 'l3', 23),
    _chan('13', 'Kids Cartoons', 'l4', 30),
    _chan('14', 'Junior TV', 'l4', 31),
    _chan('15', 'Music Box', 'l5', 40),
    _chan('16', 'Top Hits Live', 'l5', 41),
    _chan('17', 'Classical HD', 'l5', 42),
    _chan('18', 'Jazz & Blues', 'l5', 43),
    _chan('19', 'Arts & Culture', 'l6', 50),
    _chan('20', 'Museum Live', 'l6', 51),
    _chan('21', 'Fashion TV+', 'l7', 60),
    _chan('22', 'Travel HD', 'l7', 61),
    _chan('23', 'Cooking Channel', 'l7', 62),
    _chan('24', 'Home & Garden', 'l7', 63),
  ];

  static Channel _chan(String id, String name, String catId, int num) => Channel(
        streamId: id,
        name: name,
        streamIcon: _squareFor(name, id),
        categoryId: catId,
        num: num,
        tvArchive: '1',
        tvArchiveDuration: '7',
      );

  // ── VOD Categories ──
  static final vodCategories = <cat.Category>[
    cat.Category(categoryId: 'v1', categoryName: 'Action'),
    cat.Category(categoryId: 'v2', categoryName: 'Drame'),
    cat.Category(categoryId: 'v3', categoryName: 'Comédie'),
    cat.Category(categoryId: 'v4', categoryName: 'Aventure'),
    cat.Category(categoryId: 'v5', categoryName: 'Documentaire'),
  ];

  // ── VOD (Movies) ──
  // More items in category v1 (Action) so the first auto-selected grid is rich.
  static final vodItems = <VodItem>[
    _vod('101', 'Midnight Coder', 'v1', '7.8'),
    _vod('102', 'Urban Legends', 'v1', '7.1'),
    _vod('103', 'Neon Streets', 'v1', '7.7'),
    _vod('104', 'Shadow Hunters', 'v1', '8.0'),
    _vod('105', 'Steel Horizon', 'v1', '7.6'),
    _vod('106', 'Last Protocol', 'v1', '7.9'),
    _vod('107', 'City Lights', 'v2', '8.2'),
    _vod('108', 'The Last Summer', 'v2', '8.0'),
    _vod('109', 'Silent River', 'v2', '7.3'),
    _vod('110', 'The Inventor', 'v2', '7.9'),
    _vod('111', 'The Comedian', 'v3', '7.4'),
    _vod('112', 'Old Friends', 'v3', '7.0'),
    _vod('113', 'Mountain Trail', 'v4', '7.5'),
    _vod('114', 'Desert Wind', 'v4', '6.9'),
    _vod('115', 'Breaking Dawn', 'v4', '7.6'),
    _vod('116', 'Northern Star', 'v4', '8.1'),
    _vod('117', 'Lost Expedition', 'v4', '7.2'),
    _vod('118', 'Ocean Deep', 'v5', '8.4'),
    _vod('119', 'Ice Field', 'v5', '8.0'),
    _vod('120', 'Ancient Worlds', 'v5', '7.8'),
  ];

  static VodItem _vod(String id, String name, String catId, String rating) => VodItem(
        streamId: id,
        name: name,
        cover: _poster(name, colorKey: id),
        containerExtension: 'mp4',
        categoryId: catId,
        rating: rating,
        plot: 'Synopsis de démonstration pour "$name". Ce contenu est fictif et '
            'sert uniquement à illustrer les fonctionnalités de l\'application.',
      );

  // ── Series Categories ──
  static final seriesCategories = <cat.Category>[
    cat.Category(categoryId: 's1', categoryName: 'Thriller'),
    cat.Category(categoryId: 's2', categoryName: 'Drame'),
    cat.Category(categoryId: 's3', categoryName: 'Science-fiction'),
    cat.Category(categoryId: 's4', categoryName: 'Comédie'),
  ];

  // ── Series ──
  static final seriesList = <SeriesItem>[
    _series('201', 'The Archive', 's1', '8.5', '3'),
    _series('202', 'Crossroads', 's1', '8.0', '4'),
    _series('203', 'Cold Trail', 's1', '8.1', '2'),
    _series('204', 'Night Watchman', 's1', '8.2', '3'),
    _series('205', 'Hidden Truths', 's1', '7.9', '2'),
    _series('206', 'The Informant', 's1', '8.3', '4'),
    _series('207', 'Sunrise Valley', 's2', '7.8', '2'),
    _series('208', 'Family Ties', 's2', '7.4', '5'),
    _series('209', 'Harbor Lights', 's2', '7.9', '4'),
    _series('210', 'Beyond Tomorrow', 's3', '8.7', '2'),
    _series('211', 'Station Zero', 's3', '8.3', '3'),
    _series('212', 'Code Breakers', 's3', '8.0', '3'),
    _series('213', 'The Neighbors', 's4', '7.2', '6'),
  ];

  static SeriesItem _series(String id, String name, String catId, String rating, String seasons) =>
      SeriesItem(
        seriesId: id,
        name: name,
        cover: _poster(name, colorKey: id),
        categoryId: catId,
        rating: rating,
        numSeasons: seasons,
        plot: 'Description de démonstration pour la série "$name".',
      );

  // ── Episodes ──
  static Map<String, List<Episode>> episodesFor(String seriesId) {
    // Generate 3 seasons of 6 episodes each
    final result = <String, List<Episode>>{};
    for (var s = 1; s <= 3; s++) {
      final eps = <Episode>[];
      for (var e = 1; e <= 6; e++) {
        eps.add(Episode(
          id: '$seriesId-s${s}e$e',
          title: 'Épisode $e',
          episodeNum: '$e',
          containerExtension: 'mp4',
        ));
      }
      result['$s'] = eps;
    }
    return result;
  }

  // ── EPG ──
  static Map<String, dynamic> shortEpgFor(String streamId, {int limit = 8}) {
    final now = DateTime.now();
    final programs = <Map<String, dynamic>>[];
    final titles = [
      'Journal du matin',
      'Grand reportage',
      'Le débat',
      'Direct international',
      'Magazine sportif',
      'Documentaire spécial',
      'Actualités',
      'Le journal du soir',
      'Analyse éco',
      'Rendez-vous culture',
    ];
    for (var i = 0; i < limit; i++) {
      final start = now.add(Duration(minutes: 30 * (i - 1)));
      final end = start.add(const Duration(minutes: 30));
      programs.add({
        'id': '$streamId-epg-$i',
        'epg_id': '$streamId-epg-$i',
        'title': _base64(titles[i % titles.length]),
        'lang': 'fr',
        'start': _fmt(start),
        'end': _fmt(end),
        'description': _base64('Description de démonstration du programme.'),
        'channel_id': streamId,
        'start_timestamp': (start.millisecondsSinceEpoch ~/ 1000).toString(),
        'stop_timestamp': (end.millisecondsSinceEpoch ~/ 1000).toString(),
      });
    }
    return {'epg_listings': programs};
  }

  static Map<String, dynamic> fullDayEpgFor(String streamId) =>
      shortEpgFor(streamId, limit: 24);

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:00';

  static String _base64(String s) => base64.encode(utf8.encode(s));
}
