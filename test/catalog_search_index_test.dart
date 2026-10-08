import 'package:flutter_test/flutter_test.dart';
import 'package:giao_dien/catalog_data.dart';
import 'package:giao_dien/core/state/app_state.dart';
import 'package:giao_dien/core/text/catalog_search_index.dart';
import 'package:giao_dien/core/text/search_normalizer.dart';

void main() {
  test(
    'indexed searches preserve results, order, topic and favorite filters',
    () {
      final index = CatalogSearchIndex(catalogWords);
      final topic = catalogWords.first.topic;
      final favorites = catalogWords.take(5).map((w) => w.id).toSet();
      for (final query in [
        '',
        'BAN TINH',
        'bút',
        'pencil',
        'đồ dùng',
        'not-present',
      ]) {
        for (final filter in [null, topic]) {
          for (final saved in [null, <String>{}, favorites]) {
            final normalized = normalizeSearchText(query.trim());
            final expected = catalogWords
                .where(
                  (word) =>
                      (filter == null || word.topic == filter) &&
                      (saved == null || saved.contains(word.id)) &&
                      normalizeSearchText(
                        '${word.english} ${word.vietnamese} ${word.id} ${word.topic}',
                      ).contains(normalized),
                )
                .toList();
            expect(
              index.search(query, topic: filter, favoriteIds: saved),
              expected,
            );
          }
        }
      }
      expect(
        index.topics,
        catalogWords.map((w) => w.topic).toSet().toList()..sort(),
      );
    },
  );

  test('catalog view remains immutable and stable between notifications', () {
    final state = AppState();
    addTearDown(state.dispose);
    expect(identical(state.catalog, state.catalog), isTrue);
    expect(() => state.catalog.clear(), throwsUnsupportedError);
  });

  test('normalization preserves non-Latin characters and emoji', () {
    expect(normalizeSearchText('BÚT CHÌ 🎨 📚 日本語'), 'but chi 🎨 📚 日本語');
  });
}
