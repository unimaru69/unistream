// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CollectionData _$CollectionDataFromJson(Map<String, dynamic> json) =>
    _CollectionData(
      id: json['id'] as String,
      name: json['name'] as String,
      items:
          (json['items'] as List<dynamic>?)
              ?.map((e) => FavoriteItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      mode: json['mode'] as String?,
    );

Map<String, dynamic> _$CollectionDataToJson(_CollectionData instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'items': instance.items,
      'mode': instance.mode,
    };
