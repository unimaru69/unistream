/// Sealed class hierarchy for search results across all content types.
sealed class SearchResult {
  String get name;
  String get mode;
}

class LiveSearchResult extends SearchResult {
  @override
  final String name;
  final int streamId;
  final String streamIcon;

  LiveSearchResult({
    required this.name,
    required this.streamId,
    required this.streamIcon,
  });

  @override
  String get mode => 'live';
}

class VodSearchResult extends SearchResult {
  @override
  final String name;
  final int streamId;
  final String streamIcon;
  final String containerExtension;

  VodSearchResult({
    required this.name,
    required this.streamId,
    required this.streamIcon,
    required this.containerExtension,
  });

  @override
  String get mode => 'vod';
}

class SeriesSearchResult extends SearchResult {
  @override
  final String name;
  final int seriesId;
  final String cover;
  final String? rating;
  final String? categoryName;
  final String? plot;

  SeriesSearchResult({
    required this.name,
    required this.seriesId,
    required this.cover,
    this.rating,
    this.categoryName,
    this.plot,
  });

  @override
  String get mode => 'series';
}

class EpgSearchResult extends SearchResult {
  @override
  final String name;
  final String description;
  final String channelName;
  final String channelIcon;
  final String streamId;
  final DateTime startUtc;
  final DateTime endUtc;
  final String startServerLocal;
  final int durationMin;
  final bool isPast;
  final bool isCurrent;
  final bool hasCatchup;

  EpgSearchResult({
    required this.name,
    required this.description,
    required this.channelName,
    required this.channelIcon,
    required this.streamId,
    required this.startUtc,
    required this.endUtc,
    required this.startServerLocal,
    required this.durationMin,
    required this.isPast,
    required this.isCurrent,
    required this.hasCatchup,
  });

  @override
  String get mode => 'epg';
}
