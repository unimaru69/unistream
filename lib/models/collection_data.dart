import 'package:freezed_annotation/freezed_annotation.dart';
import 'favorite_item.dart';

part 'collection_data.freezed.dart';
part 'collection_data.g.dart';

@freezed
abstract class CollectionData with _$CollectionData {
  const factory CollectionData({
    required String id,
    required String name,
    @Default([]) List<FavoriteItem> items,
    String? mode,
  }) = _CollectionData;

  factory CollectionData.fromJson(Map<String, dynamic> json) =>
      _$CollectionDataFromJson(json);

  /// Convert legacy Map<String, dynamic> to CollectionData.
  factory CollectionData.fromLegacy(Map<String, dynamic> map) {
    final rawItems = (map['items'] as List?) ?? [];
    final items = rawItems.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final key = m['key']?.toString() ?? m['_key']?.toString() ?? '';
      return FavoriteItem.fromLegacy(key, m);
    }).toList();
    return CollectionData(
      id: map['id']?.toString() ?? map['collection_id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      items: items,
      mode: map['mode']?.toString(),
    );
  }
}
