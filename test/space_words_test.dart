import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:giao_dien/catalog_data.dart';
import 'package:giao_dien/core/state/app_state.dart';
import 'package:giao_dien/core/storage/local_app_store.dart';
import 'package:giao_dien/core/theme/app_theme.dart';
import 'package:giao_dien/features/space_words/space_data.dart';
import 'package:giao_dien/features/space_words/space_engine.dart';
import 'package:giao_dien/features/space_words/space_game_screen.dart';
import 'package:giao_dien/features/space_words/space_sprites.dart';
import 'package:giao_dien/features/space_words/space_words_page.dart';
import 'package:giao_dien/mascot/may_mascot.dart';

class _FixedMusicRandom implements math.Random {
  _FixedMusicRandom(this.value);
  final int value;
  @override
  int nextInt(int max) => value % max;
  @override
  double nextDouble() => value / 3;
  @override
  bool nextBool() => value.isEven;
}

void main() {
  late SpaceConfig config;

  test('enemy shots aim at the ship snapshot, not a homing missile', () {
    final level = config.levels[1];
    final engine = SpaceEngine(
      config: config,
      level: level,
      words: config.wordsFor(level, catalogWords),
      random: math.Random(2),
    );
    engine.move(.86, .85);
    for (
      var tick = 0;
      tick < 200 &&
          !engine.bullets.any(
            (b) => b.active && b.kind == SpaceBulletKind.enemy,
          );
      tick++
    ) {
      engine.update(1 / 60);
    }
    final bullet = engine.bullets.firstWhere(
      (b) => b.active && b.kind == SpaceBulletKind.enemy,
    );
    final landingX =
        bullet.x + bullet.vx / bullet.vy * (engine.shipY - bullet.y);
    expect(landingX, closeTo(engine.shipX, .00001));
    final vx = bullet.vx, vy = bullet.vy;
    engine.move(.12, .85);
    engine.update(1 / 60);
    expect(bullet.vx, vx);
    expect(bullet.vy, vy);
    engine.dispose();
  });

  test(
    'enemy enters, moves and next enemy appears before first is defeated',
    () {
      final level = config.levels[2];
      final engine = SpaceEngine(
        config: config,
        level: level,
        words: config.wordsFor(level, catalogWords),
      );
      expect(engine.target!.y, lessThan(0));
      final x = engine.target!.x;
      for (var i = 0; i < 250; i++) {
        engine.update(1 / 60);
      }
      expect(engine.defeated, 0);
      expect(engine.enemies.where((e) => e.alive).length, greaterThan(1));
      expect(engine.target!.y, greaterThan(0));
      expect(engine.target!.x, isNot(closeTo(x, .01)));
      expect(
        engine.enemies.map((e) => e.homeX).toSet().length,
        engine.enemies.length,
      );
      engine.dispose();
    },
  );

  test(
    'four different pickups fall together, collecting wrong switches ammo',
    () {
      final level = config.levels[4];
      final engine = SpaceEngine(
        config: config,
        level: level,
        words: config.wordsFor(level, catalogWords),
      );
      engine.invulnerable = 100;
      for (var frame = 0; frame < 241; frame++) {
        engine.update(1 / 60);
      }
      final drops = engine.pickups.where((p) => p.active).toList();
      expect(drops.length, 4);
      expect(drops.map((p) => p.index).toSet().length, 4);
      expect(drops.every((p) => p.y < 0), isTrue);
      final wrong = drops.firstWhere(
        (p) => engine.choices[p.index].id != engine.target!.word.id,
      );
      wrong.y = .8;
      engine.move(wrong.x, .8);
      engine.update(1 / 60);
      expect(wrong.active, isFalse);
      expect(engine.selected, wrong.index);
      expect(engine.collected, contains(wrong.index));
      expect(engine.choices[engine.selected].id, isNot(engine.target!.word.id));
      engine.dispose();
    },
  );

  test(
    'wrong boss ammo telegraphs laser before damage; phase preserves body and total HP',
    () {
      final level = SpaceLevel({
        ...config.levels.last.json,
        'enemyInterval': 999,
      });
      final engine = SpaceEngine(
        config: config,
        level: level,
        words: config.wordsFor(level, catalogWords),
      );
      engine.move(.5, .8);
      for (var i = 0; i < 70; i++) {
        engine.update(1 / 60);
      }
      final target = engine.target!;
      engine.resolveHit(SpaceBullet()..wordId = 'wrong', target);
      expect(engine.bossAttack?.laser, isTrue);
      for (var i = 0; i < 60; i++) {
        engine.update(1 / 60);
      }
      expect(engine.hearts, 3);
      for (var i = 0; i < 40; i++) {
        engine.update(1 / 60);
      }
      expect(engine.hearts, 2);
      expect(engine.bossHp, engine.bossMaxHp);
      final x = target.x, y = target.y;
      for (var i = 0; i < target.maxHp; i++) {
        engine.resolveHit(SpaceBullet()..wordId = target.word.id, target);
      }
      expect(engine.bossHp, engine.bossMaxHp - target.maxHp);
      expect(engine.target!.x, x);
      expect(engine.target!.y, y);
      expect(engine.target!.age, target.age);
      engine.dispose();
    },
  );

  test(
    'rare boss song exactly one of three draws, never selected for normal stages',
    () {
      final audio = config.json['audio'] as Map;
      final draws = [
        for (var i = 0; i < 3; i++) config.musicFor(true, _FixedMusicRandom(i)),
      ];
      expect(draws.where((p) => p == audio['rareBossMusic']).length, 1);
      expect(draws.where((p) => p == audio['bossMusic']).length, 2);
      expect(config.musicFor(false, _FixedMusicRandom(0)), audio['music']);
    },
  );

  testWidgets('rare boss banner and same music survive Pause without reroll', (
    tester,
  ) async {
    const channel = MethodChannel('vocab_vision/game_audio');
    final musicCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'music') {
        musicCalls.add((call.arguments as Map)['asset'] as String);
      }
      return call.method == 'device' ? {'model': 'test'} : null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVocabTheme(
          brightness: Brightness.light,
          seedColor: AppColors.blue,
        ),
        home: RepaintBoundary(
          key: key,
          child: SpaceGameScreen(
            config: config,
            level: config.levels.last,
            words: config.wordsFor(config.levels.last, catalogWords),
            progress: SpaceProgress(sound: false, music: true),
            tutorial: false,
            musicRandom: _FixedMusicRandom(0),
            onResult: (_) async {},
          ),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(seconds: 1));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text("you're gonna have a bad time :))"), findsOneWidget);
    expect(find.textContaining('HP 48/48'), findsOneWidget);
    expect(find.text('Né và nhặt đạn'), findsNothing);
    final field = tester.getRect(find.byKey(const ValueKey('space-playfield')));
    expect(field.height, greaterThanOrEqualTo(844 * .55));
    void expectShoulderJoints() {
      final body = tester.getRect(find.byKey(const ValueKey('boss-body')));
      for (final side in ['left', 'right']) {
        final render = tester.renderObject<RenderBox>(
          find.byKey(ValueKey('boss-tentacle-$side')),
        );
        final joint = render.localToGlobal(
          Offset(render.size.width * .38, render.size.height * .035),
        );
        final shoulder = Offset(
          body.center.dx + (side == 'left' ? -.32 : .32) * body.width,
          body.center.dy + body.height * .08,
        );
        expect(
          (joint - shoulder).distance,
          lessThan(.1),
          reason: '$side root must stay attached',
        );
      }
    }

    expectShoulderJoints();
    final bodyBefore = tester.getCenter(
      find.byKey(const ValueKey('boss-body')),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
    expect(
      tester.getCenter(find.byKey(const ValueKey('boss-body'))),
      isNot(bodyBefore),
    );
    expectShoulderJoints();
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/space_boss_v2_preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.bySemanticsLabel('Tạm dừng'));
    await tester.pump();
    expect(find.text('Nghỉ một chút nhé!'), findsNothing);
    await tester.tap(find.text('Tiếp tục chơi'));
    await tester.pump();
    expect(musicCalls, everyElement(config.json['audio']['rareBossMusic']));
    expect(musicCalls.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('tutorial fits small screens and backgrounding pauses gameplay', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tutorialKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVocabTheme(
          brightness: Brightness.dark,
          seedColor: AppColors.blue,
        ),
        home: RepaintBoundary(
          key: tutorialKey,
          child: SpaceGameScreen(
            config: config,
            level: config.levels.first,
            words: config.wordsFor(config.levels.first, catalogWords),
            progress: SpaceProgress(sound: false),
            tutorial: true,
            onResult: (_) async {},
          ),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Hướng dẫn 1/10'), findsOneWidget);
    await tester.runAsync(() async {
      final boundary =
          tutorialKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final img = await boundary.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/space_tutorial_preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      img.dispose();
    });
    await tester.tap(find.text('Tiếp'));
    await tester.pump();
    expect(find.textContaining('Kéo phi thuyền sang trái'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(
      ui.AppLifecycleState.inactive,
    );
    await tester.pump();
    expect(find.text('Tiếp tục chơi'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(ui.AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.text('Tiếp tục chơi'));
    await tester.pump();
    await tester.tap(find.text('Bỏ qua'));
    await tester.pump();
    expect(find.textContaining('Hướng dẫn'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'listening safely falls back to text if offline voice is missing',
    (tester) async {
      const channel = MethodChannel('vocab_vision/tts');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (call) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: SpaceGameScreen(
            config: config,
            level: config.levels[3],
            words: config.wordsFor(config.levels[3], catalogWords),
            progress: SpaceProgress(sound: true),
            tutorial: false,
            onResult: (_) async {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Chưa phát âm được'), findsOneWidget);
      expect(
        config
            .wordsFor(config.levels[3], catalogWords)
            .any((word) => find.text(word.english).evaluate().isNotEmpty),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final anim in MayAnimation.values) {
      final img = await MaySpriteRepository.instance.imageFor(anim);
      img.dispose();
    }
    // Use SDK fonts for human-readable QA captures instead of test Ahem boxes.
    final packages = File('.dart_tool/package_config.json').absolute;
    final packageJson = jsonDecode(await packages.readAsString()) as Map;
    final flutter = (packageJson['packages'] as List).firstWhere(
      (p) => p['name'] == 'flutter',
    );
    final flutterRoot = packages.uri.resolve('${flutter['rootUri']}/');
    for (final font in [
      ('Roboto', 'roboto-regular.ttf'),
      ('MaterialIcons', 'materialicons-regular.otf'),
    ]) {
      final file = File.fromUri(
        flutterRoot.resolve(
          '../../bin/cache/artifacts/material_fonts/${font.$2}',
        ),
      );
      if (await file.exists()) {
        final loader = FontLoader(font.$1)
          ..addFont(
            Future.value(ByteData.sublistView(await file.readAsBytes())),
          );
        await loader.load();
      }
    }
    config = SpaceConfig(
      Map<String, dynamic>.from(
        jsonDecode(
              await File(
                'assets/games/space_words/game_config.json',
              ).readAsString(),
            )
            as Map,
      ),
    );
  });
  SpaceEngine make(
    int id, {
    bool tutorial = false,
    void Function(CatalogWord)? speak,
  }) {
    final level = config.levels[id - 1];
    return SpaceEngine(
      config: config,
      level: level,
      words: config.wordsFor(level, catalogWords),
      random: math.Random(2),
      replayTutorial: tutorial,
      onSpeak: speak,
    );
  }

  void hit(SpaceEngine engine, bool correct) {
    final target = engine.target!;
    final word = correct
        ? target.word.id
        : engine.choices.firstWhere((w) => w.id != target.word.id).id;
    engine.resolveHit(SpaceBullet()..wordId = word, target);
  }

  test(
    'all six levels resolve existing catalog IDs, never invent vocabulary',
    () {
      for (final level in config.levels) {
        final words = config.wordsFor(level, catalogWords);
        expect(words.every((w) => catalogWords.contains(w)), isTrue);
      }
      expect(
        () => config.wordsFor(config.levels.first, []),
        throwsFormatException,
      );
    },
  );
  test(
    'correct and wrong collisions, anger, bounce, combo, repeated vocabulary',
    () {
      final engine = make(2);
      final target = engine.target!;
      final bullet = SpaceBullet()
        ..wordId = 'wrong'
        ..active = true;
      engine.resolveHit(bullet, target);
      expect(target.hp, target.maxHp);
      expect(target.angry, 4);
      expect(bullet.kind, SpaceBulletKind.bounced);
      expect(engine.wrongAmmoId, bullet.wordId);
      expect(engine.attempts.single.correct, isFalse);
      hit(engine, true);
      expect(engine.wrongAmmoId, isNull);
      expect(target.hp, target.maxHp - 1);
      hit(engine, true);
      expect(target.alive, isFalse);
      expect(engine.combo, 1);
      expect(
        engine.attempts.length,
        2,
      ); // Each choice once, not every auto bullet.
      engine.dispose();
    },
  );
  test(
    'stable answer order, pause, bullet pool, and bounded frame catch-up',
    () {
      final engine = make(3);
      final order = engine.choices.map((w) => w.id).toList();
      engine.setPaused(true);
      engine.update(99);
      expect(engine.elapsed, 0);
      engine.setPaused(false);
      engine.update(99);
      expect(
        engine.elapsed,
        lessThanOrEqualTo(config.p('fixedStep') * 4 + .0001),
      );
      expect(engine.choices.map((w) => w.id), orderedEquals(order));
      final pool = engine.bullets;
      for (var i = 0; i < 300; i++) {
        engine.update(1 / 60);
      }
      expect(identical(pool, engine.bullets), isTrue);
      expect(engine.bullets.length, 64);
      engine.dispose();
    },
  );
  test('one hit per invulnerability window and game-over at zero hearts', () {
    final engine = make(2);
    engine.hurt();
    engine.hurt();
    expect(engine.hearts, 2);
    for (var i = 0; i < 92; i++) {
      engine.update(1 / 60);
    }
    engine.hurt();
    expect(engine.hearts, 1);
    for (var i = 0; i < 92; i++) {
      engine.update(1 / 60);
    }
    engine.hurt();
    expect(engine.result!.won, isFalse);
    expect(engine.result!.stars, 0);
    engine.dispose();
  });
  test('all six levels can finish using real moving auto-fire projectiles', () {
    for (var id = 1; id <= 6; id++) {
      final engine = make(id);
      engine.invulnerable =
          10000; // Combat learning test; health tested separately.
      for (var tick = 0; tick < 15000 && engine.result == null; tick++) {
        final target = engine.target!;
        final correct = engine.choices.indexWhere(
          (w) => w.id == target.word.id,
        );
        final drops = engine.pickups.where(
          (p) => p.active && p.index == correct,
        );
        if (engine.needsPickups &&
            !engine.collected.contains(correct) &&
            drops.isNotEmpty) {
          engine.move(drops.first.x, drops.first.y);
        } else {
          engine.move(target.x, .8);
        }
        final index = engine.choices.indexWhere((w) => w.id == target.word.id);
        if (!engine.needsPickups || engine.collected.contains(index)) {
          engine.select(index);
        }
        engine.update(1 / 60);
      }
      expect(engine.result?.won, isTrue, reason: 'level $id');
      expect(engine.result!.stars, 3);
      expect(engine.result!.words, isNotEmpty);
      engine.dispose();
    }
  });
  test(
    'wrong choice locks all ammo for five seconds without extending on tap',
    () {
      final engine = make(2);
      engine.invulnerable = 100;
      final wrong = engine.choices.indexWhere(
        (w) => w.id != engine.target!.word.id,
      );
      final correct = engine.choices.indexWhere(
        (w) => w.id == engine.target!.word.id,
      );
      engine.select(wrong);
      expect(engine.cooldownSeconds, 5);
      engine.select(correct);
      expect(engine.selected, wrong);
      for (var i = 0; i < 240; i++) {
        engine.update(1 / 60);
      }
      engine.select(correct);
      expect(engine.selected, wrong);
      for (var i = 0; i < 62; i++) {
        engine.update(1 / 60);
      }
      expect(engine.answerCooldown, 0);
      engine.select(correct);
      expect(engine.selected, correct);
      engine.dispose();
    },
  );

  test(
    'normal stages use 36 catalog animals without repeats within a cycle',
    () {
      for (var id = 2; id <= 6; id++) {
        final engine = make(id);
        expect(engine.words.length, 36);
        final targets = <String>[];
        while (engine.result == null) {
          final target = engine.target!;
          targets.add(target.word.id);
          for (var i = 0; i < target.maxHp; i++) {
            hit(engine, true);
          }
        }
        expect(targets.length, config.levels[id - 1].enemyCount);
        expect(targets.toSet().length, targets.length);
        engine.dispose();
      }
    },
  );

  test('boss randomizes modes only per target and resets old ammo safely', () {
    final spoken = <String>[];
    final engine = make(6, speak: (w) => spoken.add(w.id));
    final modes = <bool>[];
    while (engine.result == null) {
      final target = engine.target!;
      modes.add(engine.needsPickups);
      final order = engine.choices.map((w) => w.id).toList();
      expect(engine.selected, -1);
      expect(engine.pickupActive, isFalse);
      expect(engine.answerCooldown, 0);
      if (engine.listening) expect(spoken.last, target.word.id);
      engine.setPaused(true);
      engine.update(1);
      expect(engine.needsPickups, modes.last);
      expect(engine.choices.map((w) => w.id), order);
      engine.setPaused(false);
      if (engine.needsPickups) {
        expect(engine.collected, isEmpty);
        engine.select(0);
        expect(engine.selected, -1);
        engine.invulnerable = 100;
        for (var frame = 0; frame < 241; frame++) {
          engine.update(1 / 60);
        }
        final drops = engine.pickups.where((p) => p.active).toList();
        expect(drops.length, 4);
        expect(drops.every((p) => p.y < 0), isTrue);
        final correct = drops.firstWhere(
          (p) => engine.choices[p.index].id == target.word.id,
        );
        final startY = correct.y;
        for (var frame = 0; frame < 120; frame++) {
          engine.update(1 / 60);
        }
        expect(correct.y, greaterThan(startY));
        // Wait for the correct drop to reach the reachable ship zone.
        while (correct.y < .72) {
          engine.move(correct.x, .85);
          engine.update(1 / 60);
        }
        engine.move(correct.x, correct.y);
        engine.update(1 / 60);
        expect(engine.collected, contains(correct.index));
        expect(engine.selected, correct.index);
      }
      while (target.alive) {
        hit(engine, true);
      }
    }
    expect(modes.toSet().length, 2);
    for (var i = 2; i < modes.length; i++) {
      expect(modes[i] == modes[i - 1] && modes[i] == modes[i - 2], isFalse);
    }
    engine.dispose();
  });

  test(
    'pickups wait four seconds, start at top, and correct collections stack shots',
    () {
      final engine = make(6);
      engine.invulnerable = 1000;
      while (!engine.needsPickups) {
        final target = engine.target!;
        while (target.alive) {
          hit(engine, true);
        }
      }
      for (var frame = 0; frame < 239; frame++) {
        engine.update(1 / 60);
      }
      expect(engine.pickupActive, isFalse);
      for (var frame = 0; frame < 2; frame++) {
        engine.update(1 / 60);
      }
      expect(engine.pickups.where((p) => p.active).length, 4);
      expect(engine.pickups.every((p) => p.y < 0), isTrue);
      void collectCorrect() {
        final correct = engine.pickups.firstWhere(
          (p) =>
              p.active && engine.choices[p.index].id == engine.target!.word.id,
        );
        correct.y = .75;
        engine.move(correct.x, .75);
        engine.update(1 / 60);
      }

      collectCorrect();
      expect(engine.ammoMultiplier, 1);
      for (final p in engine.pickups) {
        p.active = false;
      }
      engine.move(.08, .9);
      for (var frame = 0; frame < 180; frame++) {
        engine.update(1 / 60);
      }
      expect(engine.pickupActive, isFalse);
      for (var frame = 0; frame < 62; frame++) {
        engine.update(1 / 60);
      }
      collectCorrect();
      expect(engine.ammoMultiplier, 2);
      engine.move(.08, .9);
      for (final bullet in engine.bullets) {
        bullet.active = false;
      }
      // Re-select after clearing selection to schedule an immediate burst.
      engine.selected = -1;
      engine.select(
        engine.choices.indexWhere((w) => w.id == engine.target!.word.id),
      );
      engine.update(1 / 60);
      expect(
        engine.bullets
            .where((b) => b.active && b.kind == SpaceBulletKind.player)
            .length,
        2,
      );
      final target = engine.target!;
      while (target.alive) {
        hit(engine, true);
      }
      expect(engine.ammoMultiplier, 2); // Power survives the next word/phase.
      engine.dispose();
    },
  );

  test('tutorial is gated by actions, wrong demonstration is assisted', () {
    final engine = make(1, tutorial: true);
    expect(engine.step!['id'], 'hello');
    engine.nextStep();
    engine.nextStep(); // Cannot skip movement by pressing Next.
    expect(engine.step!['id'], 'move');
    engine.move(.15, .85);
    engine.move(.8, .85);
    expect(engine.step!['id'], 'dodge');
    engine.move(.15, .85);
    for (var i = 0; i < 1200 && engine.step!['id'] == 'dodge'; i++) {
      engine.update(1 / 60);
    }
    expect(engine.step!['id'], 'word');
    engine.nextStep();
    final wrong = engine.choices.indexWhere(
      (w) => w.id != engine.target!.word.id,
    );
    engine.select(wrong);
    expect(engine.step!['id'], 'ammo');
    engine.select(
      engine.choices.indexWhere((w) => w.id == engine.target!.word.id),
    );
    expect(engine.step!['id'], 'correct');
    hit(engine, true);
    expect(engine.step!['id'], 'wrong');
    hit(engine, false);
    expect(engine.step!['id'], 'recover');
    expect(engine.target!.angry, greaterThan(0));
    hit(engine, true);
    engine.nextStep();
    engine.nextStep();
    expect(engine.result!.won, isTrue);
    expect(engine.result!.stars, 1);
    expect(engine.attempts.every((a) => a.assisted), isTrue);
    expect(engine.hearts, 3);
    engine.dispose();
  });
  test(
    'listening speaks existing words; wrong words prioritized on next stage',
    () {
      final spoken = <String>[];
      final level = config.levels[3];
      final engine = SpaceEngine(
        config: config,
        level: level,
        words: config.wordsFor(level, catalogWords),
        priorityIds: ['fish'],
        onSpeak: (word) => spoken.add(word.id),
      );
      expect(engine.target!.word.id, 'fish');
      expect(spoken.first, 'fish');
      engine.dispose();
    },
  );
  test(
    'progress survives reopening; replay never removes best stars or other app data',
    () async {
      SharedPreferences.setMockInitialValues({'profile.name': 'Bo'});
      final store = LocalAppStore();
      await store.open();
      final progress = SpaceProgress()
        ..stars[1] = 1
        ..stars[2] = 3;
      await store.saveSpaceGameProgress(progress.toJson());
      await store.close();
      final reopened = LocalAppStore();
      await reopened.open();
      final loaded = SpaceProgress.fromJson(reopened.spaceGameProgress);
      expect(loaded.unlocked, 3);
      expect(loaded.totalStars, 4);
      expect(reopened.profileName, 'Bo');
      loaded.record(
        2,
        const SpaceResult(
          won: true,
          hearts: 1,
          stars: 1,
          attempts: [],
          words: [],
        ),
      );
      expect(loaded.stars[2], 3);
      loaded.record(
        1,
        const SpaceResult(
          won: true,
          hearts: 3,
          stars: 3,
          attempts: [],
          words: [],
        ),
      );
      await reopened.saveSpaceGameProgress(loaded.toJson());
      await reopened.close();
      final upgradedStore = LocalAppStore();
      await upgradedStore.open();
      final upgraded = SpaceProgress.fromJson(upgradedStore.spaceGameProgress);
      expect(upgraded.stars[1], 3);
      expect(upgraded.totalStars, 6);
      upgraded.record(
        1,
        const SpaceResult(
          won: true,
          hearts: 1,
          stars: 1,
          attempts: [],
          words: [],
        ),
      );
      expect(upgraded.stars[1], 3);
      expect(upgradedStore.profileName, 'Bo');
      await upgradedStore.close();
    },
  );
  testWidgets('menu, map and all artwork load with no missing assets', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.runAsync(() => state.load());
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVocabTheme(
          brightness: Brightness.light,
          seedColor: AppColors.blue,
        ),
        home: RepaintBoundary(
          key: key,
          child: SpaceWordsPage(appState: state),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.text('Phi đội từ vựng'), findsOneWidget);
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await boundary.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/space_menu_preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      img.dispose();

      // Inspect atlas pixels near pause boundary
      final bytes = await rootBundle.load('${spaceAssets}sprite_atlas.png');
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final atlasImg = frame.image;
      final byteData = await atlasImg.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );
      if (byteData != null) {
        // Inspect row 1120 (mid-height of pause sprite) around x = 970..1010
        // pause y is ~ 0.84928 * 1254 = 1065, height 154 -> 1065 to 1219. Mid is ~1140.
        final y = 1140;
        final rowPixels = <String>[];
        for (var x = 970; x <= 1010; x++) {
          final offset = (y * atlasImg.width + x) * 4;
          final a = byteData.getUint8(offset + 3);
          if (a > 0) {
            rowPixels.add('x=$x');
          }
        }
      }
      atlasImg.dispose();
      codec.dispose();
    });
    await tester.tap(find.text('Khám phá bản đồ'));
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await boundary.toImage();
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/space_map_preview.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      img.dispose();
      for (final asset in [
        'sprite_atlas.png',
        'map_cosmos.png',
        'background_sky.png',
        'background_forest.png',
        'background_ocean.png',
      ]) {
        final bytes = await rootBundle.load('$spaceAssets$asset');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    state.dispose();
  });
  testWidgets(
    'all ammo buttons show cooldown and Back leaves directly for map',
    (tester) async {
      final level = config.levels[1];
      final words = config.wordsFor(level, catalogWords);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SpaceGameScreen(
                    config: config,
                    level: level,
                    words: words,
                    progress: SpaceProgress(sound: false, music: false),
                    tutorial: false,
                    onResult: (_) async {},
                  ),
                ),
              ),
              child: const Text('Test map'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Test map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final target = words.firstWhere(
        (w) => find.text(w.english).evaluate().isNotEmpty,
      );
      Finder ammo() => find.byWidgetPredicate(
        (w) =>
            w is SpaceButton &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith('ammo-'),
      );
      final wrong = ammo()
          .evaluate()
          .map((e) => e.widget as SpaceButton)
          .firstWhere((w) => w.key != ValueKey('ammo-${target.id}'));
      await tester.tap(find.byKey(wrong.key!));
      await tester.pump();
      expect(find.text('Chọn lại sau 5s'), findsOneWidget);
      expect(
        ammo().evaluate().every(
          (e) => (e.widget as SpaceButton).onPressed == null,
        ),
        isTrue,
      );
      for (var i = 0; i < 310; i++) {
        await tester.pump(const Duration(milliseconds: 17));
      }
      expect(find.textContaining('Chọn lại sau'), findsNothing);
      expect(
        ammo().evaluate().every(
          (e) => (e.widget as SpaceButton).onPressed != null,
        ),
        isTrue,
      );
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Test map'), findsOneWidget);
      expect(find.text('Nghỉ một chút nhé!'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('game UI can drag, choose, pause and exit without leaks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildVocabTheme(
          brightness: Brightness.light,
          seedColor: AppColors.blue,
        ),
        home: RepaintBoundary(
          key: key,
          child: SpaceGameScreen(
            config: config,
            level: config.levels[1],
            words: config.wordsFor(config.levels[1], catalogWords),
            progress: SpaceProgress(sound: false),
            tutorial: false,
            onResult: (_) async {},
          ),
        ),
      ),
    );
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(
      find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('ammo-'),
          )
          .first,
    );
    await tester.drag(
      find.byKey(const ValueKey('space-playfield')),
      const Offset(40, -20),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        'build/space_game_preview.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await tester.tap(find.bySemanticsLabel('Tạm dừng'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tiếp tục chơi'), findsOneWidget);
    await tester.tap(find.text('Tiếp tục chơi'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'space UI renders without overflow across viewports, text scales, and themes',
    (tester) async {
      final viewports = const [
        Size(320, 640),
        Size(360, 720),
        Size(390, 844),
        Size(412, 915),
      ];
      final textScales = const [1.0, 1.3, 1.5];
      final themes = const [Brightness.light, Brightness.dark];

      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await tester.runAsync(() => state.load());

      for (final size in viewports) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        for (final scale in textScales) {
          for (final brightness in themes) {
            // 1. Test Menu
            await tester.pumpWidget(
              MaterialApp(
                theme: buildVocabTheme(
                  brightness: brightness,
                  seedColor: AppColors.blue,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: SpaceWordsPage(appState: state, config: config),
                ),
              ),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.text('Phi đội từ vựng'), findsOneWidget);
            expect(find.text('Chọn phi thuyền'), findsOneWidget);
            await tester.scrollUntilVisible(find.text('Phát âm từ'), 150);
            expect(find.text('Phát âm từ'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason: 'Menu overflow at size $size, scale $scale, $brightness',
            );

            // 2. Test Tutorial Game Screen
            await tester.pumpWidget(
              MaterialApp(
                theme: buildVocabTheme(
                  brightness: brightness,
                  seedColor: AppColors.blue,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: SpaceGameScreen(
                    key: const ValueKey('viewport-tutorial'),
                    config: config,
                    level: config.levels.first,
                    words: config.wordsFor(config.levels.first, catalogWords),
                    progress: SpaceProgress(sound: false),
                    tutorial: true,
                    onResult: (_) async {},
                  ),
                ),
              ),
            );
            await tester.runAsync(
              () async =>
                  Future<void>.delayed(const Duration(milliseconds: 200)),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(find.textContaining('Hướng dẫn'), findsOneWidget);
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Tutorial overflow at size $size, scale $scale, $brightness',
            );

            // 3. Test Normal Game Screen
            await tester.pumpWidget(
              MaterialApp(
                theme: buildVocabTheme(
                  brightness: brightness,
                  seedColor: AppColors.blue,
                ),
                home: MediaQuery(
                  data: MediaQueryData(
                    size: size,
                    textScaler: TextScaler.linear(scale),
                  ),
                  child: SpaceGameScreen(
                    key: const ValueKey('viewport-normal'),
                    config: config,
                    level: config.levels[1],
                    words: config.wordsFor(config.levels[1], catalogWords),
                    progress: SpaceProgress(sound: false),
                    tutorial: false,
                    onResult: (_) async {},
                  ),
                ),
              ),
            );
            await tester.runAsync(
              () async =>
                  Future<void>.delayed(const Duration(milliseconds: 200)),
            );
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'Normal game overflow at size $size, scale $scale, $brightness',
            );
            for (final level in [config.levels[4], config.levels.last]) {
              await tester.pumpWidget(
                MaterialApp(
                  theme: buildVocabTheme(
                    brightness: brightness,
                    seedColor: AppColors.blue,
                  ),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: size,
                      textScaler: TextScaler.linear(scale),
                    ),
                    child: SpaceGameScreen(
                      key: ValueKey('viewport-${level.id}'),
                      config: config,
                      level: level,
                      words: config.wordsFor(level, catalogWords),
                      progress: SpaceProgress(sound: false),
                      tutorial: false,
                      musicRandom: _FixedMusicRandom(0),
                      onResult: (_) async {},
                    ),
                  ),
                ),
              );
              await tester.pump();
              for (var frame = 0; frame < 100; frame++) {
                await tester.pump(const Duration(milliseconds: 17));
              }
              expect(
                tester.takeException(),
                isNull,
                reason:
                    'Stage ${level.id} overflow: $size, $scale, $brightness',
              );
              if (level.boss) {
                expect(find.byKey(const ValueKey('boss-body')), findsOneWidget);
                expect(find.text('Né và nhặt đạn'), findsNothing);
                final field = tester.getRect(
                  find.byKey(const ValueKey('space-playfield')),
                );
                final body = tester.getRect(
                  find.byKey(const ValueKey('boss-body')),
                );
                final ship = tester.getRect(
                  find.byKey(const ValueKey('space-player-ship')),
                );
                expect(body.top, greaterThanOrEqualTo(field.top));
                expect(body.bottom, lessThanOrEqualTo(field.bottom));
                expect(ship.bottom, lessThanOrEqualTo(field.bottom + .1));
                if (find
                    .byKey(const ValueKey('boss-listen-again'))
                    .evaluate()
                    .isNotEmpty) {
                  final listen = tester.getSize(
                    find.byKey(const ValueKey('boss-listen-again')),
                  );
                  expect(listen.height, greaterThanOrEqualTo(48));
                  expect(listen.width, lessThan(160));
                }
                expect(
                  find.text("you're gonna have a bad time :))"),
                  findsOneWidget,
                );
              }
            }
          }
        }
      }
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
