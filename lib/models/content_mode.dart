enum ContentMode {
  live, vod, series;

  String get label => switch (this) {
    ContentMode.live => 'Live',
    ContentMode.vod => 'Films',
    ContentMode.series => 'Séries',
  };

  String get key => name; // 'live', 'vod', 'series'
}

/// Navigation segments on the home screen.
///
/// `home` is the Apple-TV+-style Accueil that aggregates content across
/// every [ContentMode] (hero rotation, Continue Watching, favourite
/// shelves, Recently Added, Catch-up). The three other values map 1:1
/// to [ContentMode] for the legacy split-view experience.
enum HomeSegment {
  home, live, vod, series;

  String get label => switch (this) {
    HomeSegment.home => 'Accueil',
    HomeSegment.live => 'Live',
    HomeSegment.vod => 'Films',
    HomeSegment.series => 'Séries',
  };

  /// `null` for [HomeSegment.home] — Accueil isn't bound to a single
  /// content type. Use this getter when wiring legacy code that
  /// expects a [ContentMode]; pair it with a fallback when needed.
  ContentMode? get mode => switch (this) {
    HomeSegment.home => null,
    HomeSegment.live => ContentMode.live,
    HomeSegment.vod => ContentMode.vod,
    HomeSegment.series => ContentMode.series,
  };
}
