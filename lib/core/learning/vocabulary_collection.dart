/// A learner-owned collection. IDs refer to catalog words, never detector
/// class IDs, so catalog releases can evolve without changing E4.
class VocabularyCollection {
  final String id;
  final String name;
  final List<String> wordIds;

  const VocabularyCollection({
    required this.id,
    required this.name,
    required this.wordIds,
  });

  VocabularyCollection copyWith({String? name, Iterable<String>? wordIds}) =>
      VocabularyCollection(
        id: id,
        name: name ?? this.name,
        wordIds: (wordIds ?? this.wordIds).toSet().toList()..sort(),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'word_ids': wordIds,
  };

  static VocabularyCollection? fromJson(Object? value) {
    if (value is! Map) return null;
    final id = value['id'];
    final name = value['name'];
    final rawWords = value['word_ids'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty) {
      return null;
    }
    final wordIds = rawWords is List
        ? rawWords
              .whereType<String>()
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
        : <String>[];
    wordIds.sort();
    return VocabularyCollection(id: id, name: name.trim(), wordIds: wordIds);
  }
}
