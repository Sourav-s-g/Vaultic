import 'package:flutter_test/flutter_test.dart';
import 'package:cents/utils/category_name.dart';

void main() {
  group('normalizeCategoryName', () {
    test('trims, collapses internal whitespace, and lowercases', () {
      expect(normalizeCategoryName(' Food '), 'food');
      expect(normalizeCategoryName('Fo  od'), 'fo od');
      expect(normalizeCategoryName('  Fo\t od\n'), 'fo od');
    });

    test('normalizes Unicode case', () {
      expect(normalizeCategoryName('Café'), normalizeCategoryName('café'));
    });
  });

  group('categoryNameExists', () {
    test('detects case and whitespace variants', () {
      const names = ['Food', 'Fo od'];
      expect(categoryNameExists(names, 'food'), isTrue);
      expect(categoryNameExists(names, ' Food '), isTrue);
      expect(categoryNameExists(names, 'FOOD'), isTrue);
      expect(categoryNameExists(names, 'Fo  od'), isTrue);
    });

    test('does not treat empty names as duplicates', () {
      expect(categoryNameExists(['', 'Food'], ''), isFalse);
      expect(categoryNameExists(['Food'], '   '), isFalse);
    });

    test('detects Unicode case variants', () {
      expect(categoryNameExists(['Café'], 'café'), isTrue);
    });
  });
}
