import '../../catalog_data.dart';
import 'search_normalizer.dart';

/// Immutable text index built once per catalog snapshot, rather than once per
/// query or widget rebuild. Display text and catalog order remain untouched.
class CatalogSearchIndex {
  CatalogSearchIndex(List<CatalogWord> words)
    : _entries = [
        for (final word in words)
          (
            word: word,
            text: normalizeSearchText(
              '${word.english} ${word.vietnamese} ${word.id} ${word.topic}',
            ),
          ),
      ],
      topics = List.unmodifiable(
        words.map((word) => word.topic).toSet().toList()..sort(),
      );

  final List<({CatalogWord word, String text})> _entries;
  final List<String> topics;

  List<CatalogWord> search(
    String input, {
    String? topic,
    Set<String>? favoriteIds,
  }) {
    final query = normalizeSearchText(input.trim());
    return [
      for (final entry in _entries)
        if ((topic == null || entry.word.topic == topic) &&
            (favoriteIds == null || favoriteIds.contains(entry.word.id)) &&
            (query.isEmpty || entry.text.contains(query)))
          entry.word,
    ];
  }
}
