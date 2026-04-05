import 'package:unistream/models/channel.dart';
import 'package:unistream/models/vod_item.dart';
import 'package:unistream/models/series_item.dart';

/// Extract the unique ID from a typed stream object or a raw Map.
String getStreamId(dynamic stream) {
  if (stream is Channel) return stream.streamId.toString();
  if (stream is VodItem) return stream.streamId.toString();
  if (stream is SeriesItem) return stream.seriesId.toString();
  if (stream is Map<String, dynamic>) {
    return (stream['series_id'] ?? stream['stream_id'])?.toString() ?? '';
  }
  return '';
}

/// Extract the display name from a typed stream object or a raw Map.
String getStreamName(dynamic stream) {
  if (stream is Channel) return stream.name;
  if (stream is VodItem) return stream.name;
  if (stream is SeriesItem) return stream.name;
  if (stream is Map<String, dynamic>) return stream['name']?.toString() ?? '';
  return '';
}

/// Extract the icon/cover URL from a typed stream object or a raw Map.
String getStreamIcon(dynamic stream) {
  if (stream is Channel) return stream.displayIcon;
  if (stream is VodItem) return stream.displayIcon;
  if (stream is SeriesItem) return stream.displayIcon;
  if (stream is Map<String, dynamic>) {
    return stream['stream_icon']?.toString() ?? stream['cover']?.toString() ?? '';
  }
  return '';
}

/// Extract the category ID from a typed stream object or a raw Map.
String? getStreamCategoryId(dynamic stream) {
  if (stream is Channel) return stream.categoryId;
  if (stream is VodItem) return stream.categoryId;
  if (stream is SeriesItem) return stream.categoryId;
  if (stream is Map<String, dynamic>) return stream['category_id']?.toString();
  return null;
}

/// Convert a typed model to a Map for storage in favorites/watchlist/collections.
Map<String, dynamic> streamToMap(dynamic stream) {
  if (stream is Channel) {
    return {
      'stream_id': stream.streamId,
      'name': stream.name,
      'stream_icon': stream.streamIcon,
      'cover': stream.cover,
      'category_id': stream.categoryId,
      'category_name': stream.categoryName,
      'tv_archive': stream.tvArchive,
      'tv_archive_duration': stream.tvArchiveDuration,
      'added': stream.added,
      'last_modified': stream.lastModified,
    };
  }
  if (stream is VodItem) {
    return {
      'stream_id': stream.streamId,
      'name': stream.name,
      'stream_icon': stream.streamIcon,
      'cover': stream.cover,
      'container_extension': stream.containerExtension,
      'category_id': stream.categoryId,
      'category_name': stream.categoryName,
      'rating': stream.rating,
      'stream_type': stream.streamType,
      'plot': stream.plot,
      'description': stream.description,
      'added': stream.added,
      'last_modified': stream.lastModified,
    };
  }
  if (stream is SeriesItem) {
    return {
      'series_id': stream.seriesId,
      'name': stream.name,
      'cover': stream.cover,
      'stream_icon': stream.streamIcon,
      'category_id': stream.categoryId,
      'category_name': stream.categoryName,
      'num_seasons': stream.numSeasons,
      'rating': stream.rating,
      'plot': stream.plot,
      'description': stream.description,
      'added': stream.added,
      'last_modified': stream.lastModified,
    };
  }
  if (stream is Map<String, dynamic>) return stream;
  return {};
}
