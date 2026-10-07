import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/core/storage/local_app_store.dart';

void main() {
  test('coalesces a boot retry while the first store open is pending', () async {
    final store = LocalAppStore();
    final first = store.open();
    final second = store.open();
    expect(identical(first, second), isTrue);
    await Future.wait([first, second]);
    await store.close();
  });
}
