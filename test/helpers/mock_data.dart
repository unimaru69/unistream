import 'package:unistream/models/channel.dart';
import 'package:unistream/models/vod_item.dart';
import 'package:unistream/models/series_item.dart';
import 'package:unistream/models/category.dart' as cat;
import 'package:unistream/models/episode.dart';

cat.Category mockCategory({
  String id = '1',
  String name = 'Test Category',
}) =>
    cat.Category(categoryId: id, categoryName: name);

Channel mockChannel({
  dynamic streamId = 1,
  String name = 'Test Channel',
  String? streamIcon,
  String? cover,
  String? categoryId = '1',
}) =>
    Channel(
      streamId: streamId,
      name: name,
      streamIcon: streamIcon,
      cover: cover,
      categoryId: categoryId,
    );

VodItem mockVodItem({
  dynamic streamId = 1,
  String name = 'Test Movie',
  String? streamIcon,
  String? cover,
  String? categoryId = '1',
  String? rating,
  String? plot,
}) =>
    VodItem(
      streamId: streamId,
      name: name,
      streamIcon: streamIcon,
      cover: cover,
      categoryId: categoryId,
      rating: rating,
      plot: plot,
    );

SeriesItem mockSeriesItem({
  dynamic seriesId = 1,
  String name = 'Test Series',
  String? cover,
  String? streamIcon,
  String? categoryId = '1',
  String? numSeasons,
}) =>
    SeriesItem(
      seriesId: seriesId,
      name: name,
      cover: cover,
      streamIcon: streamIcon,
      categoryId: categoryId,
      numSeasons: numSeasons,
    );

Episode mockEpisode({
  dynamic id = 1,
  String? title = 'Episode 1',
  String containerExtension = 'mp4',
  dynamic episodeNum = 1,
}) =>
    Episode(
      id: id,
      title: title,
      containerExtension: containerExtension,
      episodeNum: episodeNum,
    );
