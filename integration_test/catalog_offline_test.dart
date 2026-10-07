import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:giao_dien/main.dart';

Future<void> _waitForHome(WidgetTester tester) async {
  for (var attempt = 0; attempt < 30; attempt++) {
    if (find.text('Bỏ qua').evaluate().isNotEmpty) {
      await tester.tap(find.text('Bỏ qua'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.text('Hôm nay học gì?').evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 500));
  }
  expect(find.text('Hôm nay học gì?'), findsOneWidget);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'downloads a catalog release then reopens it from SQLite offline',
    (tester) async {
      await tester.pumpWidget(const VocabApp());
      await _waitForHome(tester);

      // The API fixture contains a word that is intentionally absent from the
      // bundled starter list. Seeing it proves the configured release reached
      // the mobile catalog path rather than the fallback list.
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Khám phá'),
        ),
      );
      await tester.pumpAndSettle();
      for (var attempt = 0; attempt < 30; attempt++) {
        if (find.text('read').evaluate().isNotEmpty) break;
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.text('read'), findsOneWidget);
      // Keep the process alive while the host disables Wi-Fi/mobile data.
      // ignore: avoid_print
      print('CATALOG_REMOTE_READY');
      await Future<void>.delayed(const Duration(seconds: 20));

      // The remote word must remain usable after the host-side network cut;
      // opening its detail and starting a lesson exercises the offline path.
      await tester.tap(find.text('read'));
      await tester.pumpAndSettle();
      expect(find.text('Học từ này'), findsOneWidget);
      await tester.tap(find.text('Học từ này'));
      await tester.pumpAndSettle();
      expect(find.text('Chọn bản dịch đúng'), findsOneWidget);
    },
  );
}
