import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:giao_dien/main.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('root swipe, Android back and lesson route keep app state', (
    tester,
  ) async {
    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(seconds: 1));

    // SQLite hydration can be slower on a cold API 36 emulator. Wait for the
    // actual product shell instead of treating a transient boot frame as a
    // navigation failure. Onboarding remains the only setup action.
    for (var attempt = 0; attempt < 20; attempt++) {
      if (find.text('Bỏ qua').evaluate().isNotEmpty) {
        await tester.tap(find.text('Bỏ qua'));
        await tester.pump(const Duration(milliseconds: 300));
      }
      if (find.text('Hôm nay học gì?').evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(find.text('Hôm nay học gì?'), findsOneWidget);

    final shellPageView = find.byType(PageView).first;
    await tester.drag(shellPageView, const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Khám phá'),
      ),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay học gì?'), findsOneWidget);

    await tester.tap(find.text('Dịch từ'));
    await tester.pumpAndSettle();
    expect(find.text('Chọn bản dịch đúng'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Thoát phiên học?'), findsOneWidget);
    await tester.tap(find.text('Rời phiên'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay học gì?'), findsOneWidget);

    // Optional host-side visual-QA hook. The normal smoke test stays fast;
    // setting VOCAB_SCREENSHOT_HOLD=1 keeps the real Activity foreground so
    // adb can capture a frame while Flutter is idle.
    if (Platform.environment['VOCAB_SCREENSHOT_HOLD'] == '1') {
      // ignore: avoid_print
      print('VOCAB_SCREENSHOT_HOLD active');
      await Future<void>.delayed(const Duration(seconds: 45));
      await tester.pump();
    }
  });
}
