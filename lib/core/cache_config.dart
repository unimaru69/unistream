import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppCacheManager {
  static const key = 'unistream_image_cache';

  static CacheManager instance = CacheManager(
    Config(
      key,
      maxNrOfCacheObjects: 500,
      stalePeriod: const Duration(days: 7),
    ),
  );
}
