import 'package:flutter_test/flutter_test.dart';
import 'package:unistream/models/category.dart';

void main() {
  group('Category', () {
    test('fromJson with complete valid JSON', () {
      final json = {
        'category_id': '42',
        'category_name': 'Sports',
        'parent_id': 5,
      };
      final cat = Category.fromJson(json);
      expect(cat.categoryId, '42');
      expect(cat.categoryName, 'Sports');
      expect(cat.parentId, 5);
    });

    test('fromJson with missing optional fields uses defaults', () {
      final json = {'category_id': '1'};
      final cat = Category.fromJson(json);
      expect(cat.categoryId, '1');
      expect(cat.categoryName, '');
      expect(cat.parentId, 0);
    });

    test('toJson roundtrip produces equal objects', () {
      final original = Category(
        categoryId: '99',
        categoryName: 'Movies',
        parentId: 3,
      );
      final json = original.toJson();
      final restored = Category.fromJson(json);
      expect(restored, original);
    });

    test('fromJson with empty string categoryName', () {
      final json = {
        'category_id': '10',
        'category_name': '',
        'parent_id': 0,
      };
      final cat = Category.fromJson(json);
      expect(cat.categoryName, '');
    });

    test('fromJson with null category_name uses default', () {
      final json = {
        'category_id': '7',
        'category_name': null,
        'parent_id': 1,
      };
      final cat = Category.fromJson(json);
      expect(cat.categoryName, '');
    });
  });
}
