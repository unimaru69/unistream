import 'package:freezed_annotation/freezed_annotation.dart';
import 'json_coerce.dart';

part 'category.freezed.dart';
part 'category.g.dart';

@freezed
abstract class Category with _$Category {
  const factory Category({
    @JsonKey(name: 'category_id', fromJson: coerceString) required String categoryId,
    @JsonKey(name: 'category_name', fromJson: coerceString) @Default('') String categoryName,
    @JsonKey(name: 'parent_id') @Default(0) int parentId,
  }) = _Category;

  factory Category.fromJson(Map<String, dynamic> json) => _$CategoryFromJson(json);
}
