import 'dart:io';

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

  testWidgets('camera tab exposes the offline E4 action surface', (
    tester,
  ) async {
    await tester.pumpWidget(const VocabApp());
    await _waitForHome(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Nhận diện'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nhận diện đồ dùng học tập'), findsOneWidget);
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn từ thư viện'), findsOneWidget);
    expect(find.text('YOLO26-S — E4 (nhóm đề xuất)'), findsOneWidget);
    expect(
      find.text('Chạy trực tiếp trên thiết bị • không cần Wi-Fi'),
      findsOneWidget,
    );

    // Host-side visual-QA hook. The normal test remains short; setting this
    // variable holds the real Activity long enough for adb screencap.
    if (Platform.environment['VOCAB_SCREENSHOT_HOLD'] == '1') {
      // ignore: avoid_print
      print('CAMERA_SCREENSHOT_READY');
      await Future<void>.delayed(const Duration(seconds: 45));
      await tester.pump();
    }
  });
}
