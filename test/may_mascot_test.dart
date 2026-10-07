import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giao_dien/mascot/may_mascot.dart';
import 'package:giao_dien/mascot/may_feedback.dart';
import 'package:giao_dien/mascot/may_corner_overlay.dart';

void main() {
  testWidgets('clean mascot renders on greeting and answer backgrounds', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.runAsync(() async {
      final image = await MaySpriteRepository.instance.imageFor(
        MayAnimation.idle,
      );
      image.dispose();
      final meme = await MaySpriteRepository.instance.imageFor(
        MayAnimation.memeSurprised,
      );
      meme.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundaryKey,
          child: Column(
            children: [
              for (final row in [
                [
                  (const Color(0xFF2A7BE4), MayAnimation.correctVictory),
                  (const Color(0xFF4CCB57), MayAnimation.correctJump),
                  (const Color(0xFFFF5A5F), MayAnimation.incorrectEncourage),
                ],
                [
                  (const Color(0xFF2A7BE4), MayAnimation.memeSurprised),
                  (const Color(0xFF4CCB57), MayAnimation.memeLaugh),
                  (const Color(0xFFFF5A5F), MayAnimation.memePout),
                ],
              ])
                Expanded(
                  child: Row(
                    children: [
                      for (final sample in row)
                        Expanded(
                          child: ColoredBox(
                            color: sample.$1,
                            child: Center(
                              child: MayMascot(
                                size: 170,
                                animation: sample.$2,
                                reduceMotion: true,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MayMascot), findsNWidgets(6));
    expect(tester.getSize(find.byType(Row).first), const Size(720, 240));
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/may_v3_complete_preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  test('consecutive answer events have distinct replay identifiers', () {
    final controller = MayFeedbackController();
    controller.playCorrect();
    final first = controller.event!.id;
    controller.playCorrect();
    expect(controller.event!.id, greaterThan(first));
    controller.playIncorrect();
    expect(controller.event!.kind, MayFeedbackKind.incorrect);
    controller.clearIf(first);
    expect(controller.event, isNotNull);
    controller.dispose();
  });

  testWidgets('all sprite clips decode and match their frame metadata', (
    tester,
  ) async {
    final repository = MaySpriteRepository.instance;
    await tester.runAsync(() async {
      for (final animation in MayAnimation.values) {
        final clip = await repository.clipFor(animation);
        final image = await repository.imageFor(animation);
        expect(image.width, clip.columns * clip.frameWidth);
        expect(image.height, clip.rows * clip.frameHeight);
        if (clip.category == 'pose_atlas') {
          expect(
            clip.asset,
            anyOf(
              'assets/mascot/may/may_v3_pose_atlas.png',
              'assets/mascot/may/may_v3_meme_bust_atlas.png',
            ),
          );
          expect(clip.poses.length, clip.frames);
          for (final pose in clip.poses) {
            expect(pose, inInclusiveRange(0, clip.columns * clip.rows - 1));
          }
        } else {
          expect(clip.frames, lessThanOrEqualTo(clip.rows * clip.columns));
        }
        image.dispose();
      }
    });
  });

  testWidgets('corner overlay appears, closes and cancels its timers', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MayCornerOverlay(
            minDelay: Duration(milliseconds: 10),
            maxDelay: Duration(milliseconds: 10),
            stayDuration: Duration(seconds: 1),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 300));
    final sprite = tester.widget<MayMascot>(find.byType(MayMascot));
    expect(sprite.visible, isTrue);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<MayMascot>(find.byType(MayMascot)).visible, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });
}
