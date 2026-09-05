// Smoke test cơ bản cho app từ vựng.
import 'dart:ui' show Size;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/main.dart';

void main() {
  testWidgets('App khởi động không lỗi', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump();

    // Màn Trang chủ là tab mặc định — kiểm tra app dựng được widget.
    expect(find.byType(VocabApp), findsOneWidget);
    expect(find.text('Chọn chế độ học 🎯'), findsOneWidget);
  });

  testWidgets('Mở lộ trình học từ Trang chủ', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.tap(find.text('Ôn tập'));
    await tester.pumpAndSettle();

    expect(find.text('Lộ trình học'), findsOneWidget);
    expect(find.textContaining('15 đồ dùng học tập'), findsWidgets);
    expect(find.text('Bạn đã hoàn thành 3/8 chặng'), findsOneWidget);
  });

  testWidgets('Home responsive không che card cuối bởi navigation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pump();

    expect(find.text('Nghe & chọn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
