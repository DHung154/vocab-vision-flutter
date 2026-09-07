// Smoke test cơ bản cho app từ vựng.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/main.dart';

void main() {
  testWidgets('App khởi động không lỗi', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 568);
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

    final cameraButton = find.descendant(
      of: find.byType(BottomCutoutNav),
      matching: find.byIcon(Icons.camera_alt_rounded),
    );
    expect(tester.getCenter(cameraButton).dx, closeTo(160, 0.1));

    await tester.drag(find.byType(ListView).first, const Offset(0, -1000));
    await tester.pump();

    expect(find.text('Nghe & chọn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Nút nhanh Từ vựng chuyển đúng màn hình', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    final quickVocabulary = find.descendant(
      of: find.byType(HomeScreen),
      matching: find.text('Từ vựng'),
    );
    await tester.tap(quickVocabulary);
    await tester.pumpAndSettle();

    expect(find.text('15 đồ dùng học tập'), findsOneWidget);
  });

  testWidgets('Card Flashcard mở bài học thật', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.ensureVisible(find.text('Flashcard'));
    await tester.tap(find.text('Flashcard'));
    await tester.pumpAndSettle();

    expect(find.text('Lật thẻ'), findsOneWidget);
    expect(find.text('Abacus'), findsOneWidget);
  });

  testWidgets('Màn camera mặc định chọn đúng E4 và không overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    final cameraButton = find.descendant(
      of: find.byType(BottomCutoutNav),
      matching: find.byIcon(Icons.camera_alt_rounded),
    );
    await tester.tap(cameraButton);
    await tester.pumpAndSettle();

    expect(find.text('YOLO26-S — E4 (nhóm đề xuất)'), findsOneWidget);
    expect(find.text('Xem kết quả thực nghiệm E4 →'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
