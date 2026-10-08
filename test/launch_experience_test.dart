import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giao_dien/app/launch_experience.dart';

void main() {
  Future<void> showLaunch(
    WidgetTester tester,
    ValueNotifier<bool> ready, {
    bool reduceMotion = false,
    GlobalKey? captureKey,
    VoidCallback? onTap,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            disableAnimations: reduceMotion,
          ),
          child: RepaintBoundary(
            key: captureKey,
            child: ValueListenableBuilder<bool>(
              valueListenable: ready,
              builder: (context, value, _) => LaunchExperience(
                ready: value,
                child: Scaffold(
                  backgroundColor: const Color(0xFF131F27),
                  body: Center(
                    child: TextButton(
                      key: const ValueKey('destination'),
                      onPressed: onTap,
                      child: const Text('Trang chủ'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => precacheImage(
        tester.widget<Image>(find.byKey(const ValueKey('launch-logo'))).image,
        tester.element(find.byType(LaunchExperience)),
      ),
    );
    await tester.pump();
  }

  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory('build/qa-launch')
        ..createSync(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'solid logo and paint rise together over a stationary destination',
    (tester) async {
      final ready = ValueNotifier(true);
      addTearDown(ready.dispose);
      final key = GlobalKey();
      var taps = 0;
      await showLaunch(tester, ready, captureKey: key, onTap: () => taps++);
      final destinationCenter = tester.getCenter(
        find.byKey(const ValueKey('destination')),
      );
      final logoCenter = tester.getCenter(
        find.byKey(const ValueKey('launch-logo')),
      );
      await capture(tester, key, '01-logo');
      await tester.pump(const Duration(milliseconds: 850));
      await capture(tester, key, '02-paint-spread');
      await tester.pump(const Duration(milliseconds: 550));
      expect(
        tester
            .widget<CustomPaint>(find.byKey(const ValueKey('launch-paint')))
            .painter,
        isA<LaunchPaintPainter>().having((p) => p.progress, 'full paint', 1),
      );
      await capture(tester, key, '03-filled');
      await tester.pump(const Duration(milliseconds: 901));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final curtain = tester.widget<Transform>(
        find.byKey(const ValueKey('launch-curtain')),
      );
      final expectedRise = -844 * Curves.easeInOutCubic.transform(.5);
      expect(curtain.transform.storage[13], closeTo(expectedRise, .1));
      expect(
        tester.getCenter(find.byKey(const ValueKey('launch-logo'))).dy,
        closeTo(logoCenter.dy + expectedRise, .1),
      );
      expect(
        tester.getCenter(find.byKey(const ValueKey('destination'))),
        destinationCenter,
      );
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      await capture(tester, key, '04-slide-up');
      await tester.pump(const Duration(milliseconds: 351));
      expect(find.byKey(const ValueKey('launch-curtain')), findsNothing);
      final destinationOverlay = tester
          .widget<AnnotatedRegion<SystemUiOverlayStyle>>(
            find
                .descendant(
                  of: find.byType(LaunchExperience),
                  matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
                )
                .first,
          );
      expect(destinationOverlay.value.statusBarIconBrightness, Brightness.dark);
      await tester.tap(find.byKey(const ValueKey('destination')));
      expect(taps, 1);
      await tester.pump();
      await capture(tester, key, '05-destination');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'waits for initialization then exits and never replays on resume',
    (tester) async {
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      await showLaunch(tester, ready);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('launch-curtain')), findsOneWidget);
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('launch-curtain')))
            .transform
            .storage[13],
        0,
      );
      ready.value = true;
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 701));
      expect(find.byKey(const ValueKey('launch-curtain')), findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 4));
      expect(find.byKey(const ValueKey('launch-curtain')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reduced motion keeps a static logo then directly opens ready UI',
    (tester) async {
      final ready = ValueNotifier(false);
      addTearDown(ready.dispose);
      await showLaunch(tester, ready, reduceMotion: true);
      await tester.pump(const Duration(milliseconds: 500));
      final paint = tester.widget<CustomPaint>(
        find.byKey(const ValueKey('launch-paint')),
      );
      expect((paint.painter! as LaunchPaintPainter).progress, 0);
      expect(
        tester
            .widget<Transform>(find.byKey(const ValueKey('launch-curtain')))
            .transform
            .storage[13],
        0,
      );
      ready.value = true;
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('launch-curtain')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'completed paint covers every corner with the same opaque blue',
    () async {
      final recorder = ui.PictureRecorder();
      const painter = LaunchPaintPainter(progress: 1);
      painter.paint(Canvas(recorder), const Size(390, 844));
      final picture = recorder.endRecording();
      final image = await picture.toImage(390, 844);
      final bytes = await image.toByteData();
      for (final point in [
        const Offset(0, 0),
        const Offset(389, 0),
        const Offset(0, 843),
        const Offset(389, 843),
      ]) {
        final index = (point.dy.toInt() * 390 + point.dx.toInt()) * 4;
        expect(bytes!.buffer.asUint8List(index, 4), [21, 91, 181, 255]);
      }
      image.dispose();
      picture.dispose();
    },
  );
}
