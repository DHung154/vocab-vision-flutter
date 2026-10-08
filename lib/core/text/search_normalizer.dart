final Map<int, int> _searchReplacements = _buildSearchReplacements();

Map<int, int> _buildSearchReplacements() {
  const groups = <String, String>{
    'a': 'aáàảãạăắằẳẵặâấầẩẫậ',
    'd': 'dđ',
    'e': 'eéèẻẽẹêếềểễệ',
    'i': 'iíìỉĩị',
    'o': 'oóòỏõọôốồổỗộơớờởỡợ',
    'u': 'uúùủũụưứừửữự',
    'y': 'yýỳỷỹỵ',
  };
  final replacements = <int, int>{};
  for (final entry in groups.entries) {
    for (final character in entry.value.codeUnits) {
      replacements[character] = entry.key.codeUnitAt(0);
    }
  }
  return Map.unmodifiable(replacements);
}

/// Normalizes English/Vietnamese search input without changing displayed text.
///
/// The catalog keeps its original spelling; this helper only removes common
/// Vietnamese tone/diacritic marks so `ban tinh` can find `Bàn tính`.
String normalizeSearchText(String value) {
  final normalized = StringBuffer();
  for (final character in value.toLowerCase().codeUnits) {
    normalized.writeCharCode(_searchReplacements[character] ?? character);
  }
  return normalized.toString();
}
