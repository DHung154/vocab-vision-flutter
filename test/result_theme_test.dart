import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giao_dien/catalog_data.dart';
import 'package:giao_dien/core/theme/app_theme.dart';
import 'package:giao_dien/detection_model.dart';
import 'package:giao_dien/result_screen.dart';

const result = DetectionResult(
  imageWidth: 512,
  imageHeight: 512,
  modelLabel: 'E4 theme regression',
  latencyMs: 32,
  detections: [
    Detection(
      classId: 11,
      label: 'pencil',
      confidence: .92,
      box: [20, 20, 160, 180],
    ),
    Detection(
      classId: 13,
      label: 'ruler',
      confidence: .62,
      box: [180, 30, 260, 400],
    ),
    Detection(
      classId: 5,
      label: 'cup',
      confidence: .42,
      box: [290, 80, 450, 300],
    ),
  ],
);

double contrast(Color a, Color b) {
  final light = a.computeLuminance();
  final dark = b.computeLuminance();
  return light > dark
      ? (light + .05) / (dark + .05)
      : (dark + .05) / (light + .05);
}

void expectText(WidgetTester tester, String label, Color background) {
  final widget = tester.widget<Text>(find.text(label));
  final color = widget.style!.color!;
  expect(contrast(color, background), greaterThanOrEqualTo(4.5), reason: label);
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/qa-result-theme/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  void viewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget app(Brightness brightness, GlobalKey key, {bool empty = false}) =>
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          theme: buildVocabTheme(
            brightness: brightness,
            seedColor: Colors.blue,
          ),
          home: ResultScreen(
            imageFile: File('assets/catalog/e4/pencil.jpg'),
            result: empty
                ? const DetectionResult(
                    imageWidth: 512,
                    imageHeight: 512,
                    detections: [],
                  )
                : result,
            catalog: catalogWords,
            onToggleFavorite: (_) async {},
            onLearnWord: (_) {},
          ),
        ),
      );

  for (final brightness in Brightness.values) {
    final colors = brightness == Brightness.light
        ? VocabColors.light
        : VocabColors.dark;
    testWidgets(
      '${brightness.name}: result labels, all confidence tiers and details remain readable',
      (tester) async {
        viewport(tester);
        final key = GlobalKey();
        await tester.pumpWidget(app(brightness, key));
        await tester.pumpAndSettle();
        expectText(tester, 'Kết quả nhận diện', colors.canvas);
        expectText(tester, 'PENCIL', colors.surface);
        expectText(tester, 'Bút chì', colors.surface);
        expectText(tester, 'Học thêm về Pencil', colors.surface);
        expectText(tester, '92,0% • Độ tin cậy cao', colors.accentSoft);
        expectText(tester, '62,0%', colors.warningSurface);
        expectText(tester, '42,0%', colors.coralTint);
        final runtime = find.text('Thông tin kỹ thuật');
        await tester.ensureVisible(runtime);
        await tester.tap(runtime);
        await tester.pumpAndSettle();
        expectText(tester, 'E4 theme regression', colors.surface);
        final header = find
            .ancestor(of: runtime, matching: find.byType(Container))
            .first;
        expect(
          (tester.widget<Container>(header).decoration! as BoxDecoration).color,
          colors.surface,
        );
        await tester.ensureVisible(find.text('PENCIL'));
        await capture(tester, key, '${brightness.name}-result');
        await tester.ensureVisible(find.text('ruler'));
        await tester.tap(find.text('ruler'));
        await tester.pumpAndSettle();
        expectText(tester, '62,0% • Khá chắc', colors.warningSurface);
        await tester.ensureVisible(find.text('cup'));
        await tester.tap(find.text('cup'));
        await tester.pumpAndSettle();
        expectText(tester, '42,0% • Độ tin cậy thấp', colors.coralTint);
        await tester.ensureVisible(find.text('Học thêm về Cup'));
        await tester.tap(find.text('Học thêm về Cup'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
          colors.surface,
        );
        expectText(tester, 'Cup', colors.surface);
        expectText(
          tester,
          'Nguồn: school-objects v1 (Roboflow)',
          colors.surface,
        );
        expectText(tester, 'Lưu vào từ yêu thích', colors.surface);
        await capture(tester, key, '${brightness.name}-details');
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${brightness.name}: no-detection message follows the canvas theme',
      (tester) async {
        viewport(tester);
        final key = GlobalKey();
        await tester.pumpWidget(app(brightness, key, empty: true));
        await tester.pumpAndSettle();
        expectText(tester, 'Chưa tìm thấy đồ dùng học tập', colors.canvas);
        expectText(
          tester,
          'Hãy thử chụp lại với ánh sáng tốt hơn\nhoặc đưa vật thể gần camera hơn nhé!',
          colors.canvas,
        );
        await capture(tester, key, '${brightness.name}-empty');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'changing theme keeps the selected object and updates an open detail sheet',
    (tester) async {
      viewport(tester);
      final brightness = ValueNotifier(Brightness.light);
      addTearDown(brightness.dispose);
      final key = GlobalKey();
      await tester.pumpWidget(
        ValueListenableBuilder(
          valueListenable: brightness,
          builder: (_, value, _) => app(value, key),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('ruler'));
      await tester.tap(find.text('ruler'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Học thêm về Ruler'));
      await tester.tap(find.text('Học thêm về Ruler'));
      await tester.pumpAndSettle();
      brightness.value = Brightness.dark;
      await tester.pumpAndSettle();
      expectText(tester, 'Ruler', VocabColors.dark.surface);
      expectText(tester, 'Lưu vào từ yêu thích', VocabColors.dark.surface);
      expect(
        tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor,
        VocabColors.dark.surface,
      );
      Navigator.of(tester.element(find.text('Ruler'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('RULER'), findsOneWidget);
      expectText(tester, 'RULER', VocabColors.dark.surface);
      expect(tester.takeException(), isNull);
    },
  );
}
