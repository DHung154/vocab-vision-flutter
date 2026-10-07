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

  testWidgets('holds the real Home screen for host visual QA', (tester) async {
    await tester.pumpWidget(const VocabApp());
    await _waitForHome(tester);
    // ignore: avoid_print
    print('VISUAL_QA_HOME_READY');
    await Future<void>.delayed(const Duration(seconds: 45));
    await tester.pump();
  });
}
