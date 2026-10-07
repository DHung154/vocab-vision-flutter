/// Normalizes English/Vietnamese search input without changing displayed text.
///
/// The catalog keeps its original spelling; this helper only removes common
/// Vietnamese tone/diacritic marks so `ban tinh` can find `Bàn tính`.
String normalizeSearchText(String value) {
  const groups = <String, String>{
    'a': 'aáàảãạăắằẳẵặâấầẩẫậ',
    'd': 'dđ',
    'e': 'eéèẻẽẹêếềểễệ',
    'i': 'iíìỉĩị',
    'o': 'oóòỏõọôốồổỗộơớờởỡợ',
    'u': 'uúùủũụưứừửữự',
    'y': 'yýỳỷỹỵ',
  };
  final replacements = <String, String>{};
  for (final entry in groups.entries) {
    for (final character in entry.value.split('')) {
      replacements[character] = entry.key;
    }
  }
  return value
      .toLowerCase()
      .split('')
      .map((character) => replacements[character] ?? character)
      .join();
}
