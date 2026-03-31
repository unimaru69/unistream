// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Category _$CategoryFromJson(Map<String, dynamic> json) => _Category(
  categoryId: json['category_id'] as String,
  categoryName: json['category_name'] as String? ?? '',
  parentId: (json['parent_id'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$CategoryToJson(_Category instance) => <String, dynamic>{
  'category_id': instance.categoryId,
  'category_name': instance.categoryName,
  'parent_id': instance.parentId,
};
