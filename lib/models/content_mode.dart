enum ContentMode {
  live, vod, series;

  String get label => switch (this) {
    ContentMode.live => 'Live',
    ContentMode.vod => 'VOD',
    ContentMode.series => 'Séries',
  };

  String get key => name; // 'live', 'vod', 'series'
}
