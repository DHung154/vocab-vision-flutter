import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/detection_model.dart';
import 'package:giao_dien/catalog_data.dart';
import 'package:giao_dien/learning_screen.dart';
import 'package:giao_dien/main.dart';
import 'package:giao_dien/result_screen.dart';
import 'package:giao_dien/vocabulary_data.dart';
import 'package:giao_dien/core/state/app_state.dart';
import 'package:giao_dien/core/storage/local_app_store.dart';
import 'package:giao_dien/core/theme/app_theme.dart';
import 'package:giao_dien/mascot/may_mascot.dart';

void main() {
  testWidgets(
    'Home opens the space minigame and back returns to the same app',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        final image = await MaySpriteRepository.instance.imageFor(
          MayAnimation.encourage,
        );
        image.dispose();
      });
      await tester.pumpWidget(const VocabApp());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -520),
      );
      await tester.pump(const Duration(milliseconds: 700));
      final entry = find.text('Sân chơi của Mây');
      await tester.ensureVisible(entry);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(entry);
      await tester.pump();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Phi đội từ vựng'), findsOneWidget);
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(ProductShell), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('profile and shared hero cards remain readable in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previewKey = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(key: previewKey, child: const VocabApp()),
    );
    await tester.pump(const Duration(milliseconds: 50));
    final state = tester
        .widget<ProductShell>(find.byType(ProductShell))
        .appState;
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    void expectHero(String label) {
      final title = find.text(label);
      expect(title, findsOneWidget);
      final colors = tester.element(title).vocabColors;
      final text = tester.widget<Text>(title);
      expect(text.style?.color, colors.onPrimaryPanel);
      final decorated = tester
          .widgetList<Container>(
            find.ancestor(of: title, matching: find.byType(Container)),
          )
          .where((item) => item.decoration is BoxDecoration);
      expect(
        decorated.any(
          (item) =>
              (item.decoration! as BoxDecoration).color == colors.primaryPanel,
        ),
        isTrue,
      );
    }

    for (final dark in [false, true]) {
      await tester.runAsync(() => state.setDarkMode(dark));
      await tester.pumpAndSettle();
      expectHero(state.profileName);
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      final colors = tester.element(find.byType(CircleAvatar)).vocabColors;
      expect(avatar.backgroundColor, colors.accentSoft);
      expect((avatar.child! as Text).style?.color, colors.tealTextOnTint);
      await tester.runAsync(() async {
        final boundary =
            previewKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'build/profile_${dark ? 'dark' : 'light'}_preview.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.tap(find.text('Giới thiệu và nguồn nội dung'));
      await tester.pumpAndSettle();
      expectHero('Gói starter offline');
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('saved appearance switches the app between light and dark', (
    tester,
  ) async {
    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));
    final state = tester
        .widget<ProductShell>(find.byType(ProductShell))
        .appState;
    await tester.runAsync(() => state.setDarkMode(true));
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
    await tester.runAsync(() => state.setDarkMode(false));
    await tester.pump();
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('App starts with the product shell', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ProductShell), findsOneWidget);
    expect(find.text('Hôm nay học gì?'), findsOneWidget);
    expect(find.text('Tiếp tục học'), findsOneWidget);
    expect(find.text('Ghép cặp'), findsOneWidget);
    expect(find.text('Điền từ'), findsOneWidget);
    expect(find.text('Dịch từ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Product shell renders at required narrow and wide widths', (
    tester,
  ) async {
    for (final width in <double>[360, 390, 430]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(const VocabApp());
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byType(ProductShell), findsOneWidget);
      expect(find.text('Hôm nay học gì?'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Product shell survives larger accessibility text scales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );

    for (final scale in <double>[1.3, 2.0]) {
      tester.binding.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(const VocabApp());
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ProductShell), findsOneWidget);
      expect(find.text('Hôm nay học gì?'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'textScale=$scale');
    }
  });

  testWidgets('Tabs can be swiped and preserve the vocabulary query', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.drag(find.text('Hôm nay học gì?'), const Offset(-420, 0));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'pencil');
    await tester.pump();
    expect(find.text('Pencil'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.home_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.text('Hôm nay học gì?'), const Offset(-420, 0));
    await tester.pumpAndSettle();
    expect(find.text('pencil'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ban tinh');
    await tester.pump();
    expect(find.text('Bàn tính'), findsOneWidget);
  });

  testWidgets(
    'Explore keeps offline pack when no content server is configured',
    (tester) async {
      await tester.pumpWidget(const VocabApp());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kiểm tra gói nội dung mới'));
      await tester.pump();

      expect(
        find.textContaining('Chưa cấu hình máy chủ nội dung'),
        findsOneWidget,
      );
      expect(find.textContaining('Gói offline:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Android back returns to Home before allowing exit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay học gì?'), findsOneWidget);
  });

  testWidgets('Back from a learning session asks before leaving', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Thẻ ghi nhớ'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Thoát phiên học?'), findsOneWidget);

    await tester.tap(find.text('Rời phiên'));
    await tester.pumpAndSettle();
    expect(find.text('Hôm nay học gì?'), findsOneWidget);
  });

  testWidgets('Learning screen does not reveal an answer through emoji', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Thẻ ghi nhớ'));
    await tester.pumpAndSettle();

    expect(find.text('Lật thẻ'), findsOneWidget);
    expect(find.text('Bàn tính'), findsOneWidget);
    expect(find.text('1/10'), findsOneWidget);
    expect(find.text('🧮'), findsNothing);
  });

  testWidgets('Remembered flashcards count as practiced words', (tester) async {
    final practiced = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: LearningScreen(
          mode: LearningMode.flashcard,
          words: [vocabularyWords.first],
          onCompleted: (summary) => practiced.addAll(summary.wordLabels),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Lật thẻ'));
    await tester.pump();
    await tester.tap(find.text('Đã nhớ'));
    await tester.pump();

    expect(practiced, contains(vocabularyWords.first.apiLabel));
    expect(find.text('Bạn nhớ 1/1 từ (100%)'), findsOneWidget);
  });

  testWidgets('Matching mode has two independently ordered columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: LearningScreen(mode: LearningMode.matching)),
    );
    await tester.pump();

    expect(find.text('Nghĩa'), findsOneWidget);
    expect(find.text('Từ tiếng Anh'), findsOneWidget);
    expect(find.text('Bàn tính'), findsOneWidget);
    expect(find.text('Abacus'), findsOneWidget);

    await tester.tap(find.text('Bàn tính'));
    await tester.tap(find.text('Abacus'));
    await tester.pump();
    expect(find.text('Chưa khớp — thử lại'), findsNothing);
  });

  testWidgets('Learning screen restores a compatible draft', (tester) async {
    final draft = <String, dynamic>{
      'version': 1,
      'mode': LearningMode.fillWord.name,
      'direction': 0,
      'difficulty': 1,
      'index': 3,
      'correct': 1,
      'answered': false,
      'revealed': false,
      'mastered': <String>[],
      'matchingMatched': <String>[],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: LearningScreen(
          mode: LearningMode.fillWord,
          loadDraft: () => draft,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(vocabularyWords[3].vietnamese), findsOneWidget);
    expect(find.text('4/15'), findsOneWidget);
  });

  testWidgets('Home exposes a compatible learning draft', (tester) async {
    final state = AppState(store: LocalAppStore());
    await state.saveLearningDraft(const {
      'version': 1,
      'mode': 'flashcard',
      'direction': 0,
      'difficulty': 1,
      'index': 2,
    });

    await tester.pumpWidget(MaterialApp(home: ProductShell(appState: state)));
    await tester.pump();
    expect(find.textContaining('Tiếp tục flashcard'), findsOneWidget);

    await state.clearLearningDraft();
    state.dispose();
  });

  testWidgets('Home opens a lesson for due review words', (tester) async {
    final state = AppState(store: LocalAppStore());
    await state.recordAttempt(
      wordId: state.catalog.first.id,
      correct: true,
      now: DateTime.now().subtract(const Duration(days: 2)),
    );

    await tester.pumpWidget(MaterialApp(home: ProductShell(appState: state)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.textContaining('1 từ đang đến hạn'), findsOneWidget);
    await tester.tap(find.textContaining('1 từ đang đến hạn'));
    await tester.pumpAndSettle();

    expect(find.text('Chọn bản dịch đúng'), findsOneWidget);
    state.dispose();
  });

  testWidgets('Camera tab advertises local E4 inference', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byIcon(Icons.camera_alt_outlined));
    await tester.pumpAndSettle();

    expect(find.text('YOLO26-S — E4 (nhóm đề xuất)'), findsOneWidget);
    expect(find.textContaining('không cần Wi-Fi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile shows actual offline content provenance', (
    tester,
  ) async {
    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giới thiệu và nguồn nội dung'));
    await tester.pumpAndSettle();

    expect(find.text('Nguồn nội dung'), findsOneWidget);
    expect(find.text('Gói starter offline'), findsOneWidget);
    expect(
      find.text('300 mục • 40 chủ đề • 15 mục có media • 15 ảnh offline'),
      findsOneWidget,
    );
    expect(find.textContaining('human'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Translation mode shows a text prompt without answer imagery', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LearningScreen(mode: LearningMode.translation)),
    );
    await tester.pump();

    expect(find.text('Chọn bản dịch đúng'), findsOneWidget);
    expect(find.text('Bàn tính'), findsOneWidget);
    expect(find.text('🧮'), findsNothing);
  });

  testWidgets('Image writing mode keeps the answer out of the prompt', (
    tester,
  ) async {
    const word = VocabularyWord(
      apiLabel: 'pencil',
      emoji: '',
      english: 'Pencil',
      vietnamese: 'Bút chì',
      imageUrl: 'https://example.test/pencil.jpg',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: LearningScreen(mode: LearningMode.imageWriting, words: [word]),
      ),
    );
    await tester.pump();

    expect(find.text('Nhìn hình, viết từ tiếng Anh'), findsOneWidget);
    expect(find.text('Pencil'), findsNothing);
    expect(find.text('Bút chì'), findsNothing);
    expect(find.text('Ảnh chưa có trong gói offline.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets('Onboarding can be skipped and persists completion', (
    tester,
  ) async {
    final state = AppState(store: LocalAppStore());
    await state.store.setOnboardingComplete(false);

    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(appState: state)),
    );
    await tester.pump();
    expect(find.text('Học vừa đủ, nhớ lâu hơn'), findsOneWidget);

    await tester.tap(find.text('Bỏ qua'));
    // The onboarding contains a live text-field cursor on some Flutter
    // versions; a bounded pump is more reliable than waiting for every
    // scheduler frame to become idle.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));
    expect(state.onboardingComplete, isTrue);
    state.dispose();
  });

  testWidgets('Home topic cards open a real lesson route', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));

    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -520),
    );
    await tester.pumpAndSettle();
    final topicLabel = find.text('Đồ dùng học tập');
    await tester.tap(
      find.ancestor(of: topicLabel, matching: find.byType(InkWell)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TopicDetailPage), findsOneWidget);
    expect(find.text('Bắt đầu bài học'), findsOneWidget);
    expect(find.textContaining('20 từ'), findsOneWidget);
  });

  testWidgets('Image writing uses only catalog words with licensed media', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.drag(
      find.byType(CustomScrollView).first,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhìn hình viết từ'));
    await tester.pumpAndSettle();

    expect(find.text('Nhìn hình, viết từ tiếng Anh'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);
    final error = tester.takeException();
    expect(error, isNull);
  });

  testWidgets('Progress opens the product achievements page', (tester) async {
    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.insights_outlined));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -520));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thành tích'));
    await tester.pumpAndSettle();

    expect(find.text('Tiến độ thành tích'), findsOneWidget);
    expect(find.text('Từ đầu tiên'), findsOneWidget);
    expect(find.text('🌟'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });

  testWidgets('Vocabulary tab opens persisted collections', (tester) async {
    final state = AppState(store: LocalAppStore());
    await state.createCollection('Ôn thi');

    await tester.pumpWidget(MaterialApp(home: ProductShell(appState: state)));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bộ sưu tập'));
    await tester.pumpAndSettle();

    expect(find.text('Ôn thi'), findsOneWidget);
    await tester.tap(find.text('Ôn thi'));
    await tester.pumpAndSettle();
    expect(find.text('0 từ trong bộ'), findsOneWidget);
    state.dispose();
  });

  testWidgets('Vocabulary detail remains scrollable with the lesson CTA', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const VocabApp());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abacus'));
    await tester.pumpAndSettle();

    expect(find.text('Học từ này'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Result screen selects the same detection as the tapped row', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final result = DetectionResult(
      imageWidth: 640,
      imageHeight: 480,
      modelId: 'e4',
      modelLabel: 'YOLO26-S — E4 (nhóm đề xuất)',
      detections: const [
        Detection(
          classId: 11,
          label: 'pencil',
          confidence: 0.95,
          box: [20, 20, 220, 220],
        ),
        Detection(
          classId: 5,
          label: 'cup',
          confidence: 0.80,
          box: [300, 100, 500, 360],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          imageFile: File('assets/catalog/e4/pencil.jpg'),
          result: result,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PENCIL'), findsOneWidget);
    expect(find.text('cup'), findsOneWidget);
    await tester.tap(find.text('cup'));
    await tester.pump();

    expect(find.text('CUP'), findsOneWidget);
    expect(find.text('PENCIL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('E4 result can save and start a catalog word lesson', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var saved = false;
    var learned = false;
    const word = CatalogWord(
      id: 'pencil',
      english: 'Pencil',
      vietnamese: 'Bút chì',
      topic: 'Đồ dùng học tập',
      partOfSpeech: 'noun',
      exampleEnglish: 'Use a pencil.',
      exampleVietnamese: 'Dùng bút chì.',
    );
    final result = DetectionResult(
      imageWidth: 640,
      imageHeight: 480,
      modelId: 'e4',
      modelLabel: 'YOLO26-S — E4 (nhóm đề xuất)',
      detections: const [
        Detection(
          classId: 11,
          label: 'pencil',
          confidence: 0.95,
          box: [20, 20, 220, 220],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          imageFile: File('assets/catalog/e4/pencil.jpg'),
          result: result,
          catalog: const [word],
          isFavorite: (_) => saved,
          onToggleFavorite: (_) async => saved = !saved,
          onLearnWord: (_) => learned = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    final learnCard = find.text('Học thêm về Pencil');
    await tester.ensureVisible(learnCard);
    await tester.tap(learnCard);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu vào từ yêu thích'));
    await tester.pumpAndSettle();

    expect(saved, isTrue);
    expect(find.text('Đã lưu từ này'), findsOneWidget);
    await tester.tap(find.text('Học từ này'));
    await tester.pumpAndSettle();
    expect(learned, isTrue);
    expect(tester.takeException(), isNull);
  });
}
