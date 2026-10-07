import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/core/text/search_normalizer.dart';

void main() {
  test('Vietnamese search ignores tone marks but keeps word boundaries', () {
    expect(normalizeSearchText('Bàn tính'), 'ban tinh');
    expect(normalizeSearchText('  BÚT chì  '), '  but chi  ');
    expect(normalizeSearchText('pencil'), 'pencil');
  });
}
