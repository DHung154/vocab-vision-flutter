import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/catalog_data.dart';
import 'package:giao_dien/vocabulary_data.dart';

void main() {
  test('E4 label map keeps all 15 class IDs stable', () {
    expect(vocabularyWords, hasLength(15));
    expect(vocabularyWords.map((word) => word.apiLabel).toList(), [
      'abacus',
      'backpack',
      'chalk',
      'chalkboard',
      'crayon',
      'cup',
      'eraser',
      'glue_stick',
      'kids_chair',
      'notebook',
      'paintbrush',
      'pencil',
      'pencil_sharpener',
      'ruler',
      'scissors',
    ]);
  });

  test('starter catalog is independent from the 15 detector classes', () {
    final ids = catalogWords.map((word) => word.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(catalogWords, hasLength(300));
    expect(catalogWords.map((word) => word.topic).toSet(), hasLength(40));
    expect(catalogWords.length, greaterThan(vocabularyWords.length));
    expect(
      catalogWords.map((word) => word.topic).toSet(),
      containsAll(['Đồ dùng học tập', 'Gia đình', 'Động vật', 'Màu sắc']),
    );
    for (final word in catalogWords) {
      expect(word.english.trim(), isNotEmpty);
      expect(word.vietnamese.trim(), isNotEmpty);
      expect(word.exampleEnglish.trim(), isNotEmpty);
      expect(word.exampleVietnamese.trim(), isNotEmpty);
    }
  });

  test('E4 starter media pilot keeps explicit provenance', () {
    final e4Words = catalogWords
        .where((word) => vocabularyWords.any((e4) => e4.apiLabel == word.id))
        .toList();
    expect(e4Words, hasLength(15));
    for (final word in e4Words) {
      expect(word.imageUrl, startsWith('assets/catalog/e4/'));
      expect(word.imageLicense, 'CC BY 4.0');
      expect(word.imageAttribution, contains('school-objects v1'));
      expect(word.reviewedBy, contains('human publication review pending'));
    }
    expect(starterCatalogReleaseVersion, 'starter-2026-09-media3');
  });
}
