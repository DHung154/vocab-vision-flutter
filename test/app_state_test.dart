import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/catalog_data.dart';
import 'package:giao_dien/core/state/app_state.dart';
import 'package:giao_dien/core/network/catalog_api_client.dart';
import 'package:giao_dien/core/storage/catalog_database.dart';
import 'package:giao_dien/core/storage/catalog_media_cache.dart';
import 'package:giao_dien/core/storage/local_app_store.dart';

void main() {
  test(
    'progress is kept in the local store and streak advances by day',
    () async {
      final state = AppState(store: LocalAppStore());
      await state.load();
      await state.resetProgress();

      final firstDay = DateTime(2026, 9, 17, 9);
      await state.recordSession(
        correct: 8,
        total: 10,
        wordLabels: const ['pencil', 'ruler'],
        now: firstDay,
      );

      await state.recordSession(
        correct: 5,
        total: 10,
        wordLabels: const ['pencil', 'eraser'],
        now: firstDay.add(const Duration(days: 1)),
      );

      expect(state.points, 130);
      expect(state.sessions, 2);
      expect(state.learnedWords, containsAll(['pencil', 'ruler', 'eraser']));
      expect(state.streak, 2);
      expect(state.todayWords, 2);
      expect(state.achievementCount, 2);
    },
  );

  test('settings are exposed through one application state', () async {
    final state = AppState(store: LocalAppStore());
    await state.load();

    await state.setProfileName('  Linh  ');
    await state.setDailyGoal(15);
    await state.setSoundFx(false);
    await state.setNotifications(false);
    await state.setThemeColor(2);

    expect(state.profileName, 'Linh');
    expect(state.dailyGoal, 15);
    expect(state.soundFx, isFalse);
    expect(state.notifications, isFalse);
    expect(state.themeColor, 2);
  });

  test(
    'favorite vocabulary is persisted through the same state boundary',
    () async {
      final state = AppState(store: LocalAppStore());
      await state.load();
      if (state.favoriteWords.contains('pencil')) {
        await state.toggleFavorite('pencil');
      }

      await state.toggleFavorite('pencil');
      expect(state.favoriteWords, contains('pencil'));
      await state.toggleFavorite('pencil');
      expect(state.favoriteWords, isNot(contains('pencil')));
    },
  );

  test('learning draft survives an application-state reload', () async {
    final state = AppState(store: LocalAppStore());
    await state.load();
    await state.clearLearningDraft();

    await state.saveLearningDraft(const {
      'version': 1,
      'mode': 'fillWord',
      'direction': 0,
      'difficulty': 1,
      'index': 3,
      'answered': false,
    });
    final reloaded = AppState(store: state.store);
    await reloaded.load();
    expect(reloaded.learningDraft?['mode'], 'fillWord');
    expect(reloaded.learningDraft?['index'], 3);

    await reloaded.clearLearningDraft();
    expect(reloaded.learningDraft, isNull);
  });

  test('scored attempts create a due review state', () async {
    final state = AppState(store: LocalAppStore());
    final now = DateTime(2026, 9, 1, 9);
    await state.recordAttempt(wordId: 'pencil', correct: true, now: now);

    final review = await state.store.reviewStateFor('pencil');
    expect(review, isNotNull);
    expect(review!.level, 1);
    expect(review.dueAt, now.add(const Duration(days: 1)));
    final due = await state.store.dueReviewStates(
      now: now.add(const Duration(days: 2)),
    );
    expect(due.map((state) => state.wordId), contains('pencil'));
  });

  test('reset progress also clears the review queue', () async {
    final state = AppState(store: LocalAppStore());
    final now = DateTime(2026, 9, 1, 9);
    await state.recordAttempt(wordId: 'pencil', correct: true, now: now);
    expect(await state.store.reviewStateFor('pencil'), isNotNull);

    await state.resetProgress();

    expect(await state.store.reviewStateFor('pencil'), isNull);
    expect(
      await state.store.dueReviewStates(now: now.add(const Duration(days: 2))),
      isEmpty,
    );
  });

  test('attempt and outbox records are acknowledged independently', () async {
    final state = AppState(store: LocalAppStore());
    await state.recordAttempt(
      wordId: 'pencil',
      correct: true,
      questionType: 'translation',
      sessionId: 'session-test',
    );
    await state.recordAttempt(wordId: 'ruler', correct: false);

    final attempts = await state.recentAttempts(limit: 2);
    final pencil = attempts.firstWhere((row) => row['word_id'] == 'pencil');
    expect(pencil['question_type'], 'translation');
    expect(pencil['session_id'], 'session-test');

    final pending = await state.store.pendingOutboxEvents();
    expect(pending, hasLength(2));
    final firstId = pending.first['event_id'] as String;
    await state.store.acknowledgeOutbox([firstId]);

    final remaining = await state.store.pendingOutboxEvents();
    expect(remaining, hasLength(1));
    expect(remaining.single['event_id'], isNot(firstId));
  });

  test('collections support rename and add/remove words', () async {
    final state = AppState(store: LocalAppStore());
    await state.createCollection('Ôn tập');
    final id = state.collections.single.id;

    await state.toggleCollectionWord(id, 'pencil');
    expect(state.collections.single.wordIds, contains('pencil'));
    await state.renameCollection(id, 'Kiểm tra giữa kỳ');
    expect(state.collections.single.name, 'Kiểm tra giữa kỳ');
    await state.toggleCollectionWord(id, 'pencil');
    expect(state.collections.single.wordIds, isEmpty);
    await state.deleteCollection(id);
    expect(state.collections, isEmpty);
  });

  test(
    'restoring starter catalog keeps learner data in the app store',
    () async {
      final catalogStore = _MemoryCatalogStore(
        version: 'remote-1',
        words: const [
          CatalogWord(
            id: 'remote-word',
            english: 'Remote',
            vietnamese: 'Từ từ xa',
            topic: 'Demo',
            partOfSpeech: 'noun',
            exampleEnglish: 'A remote word.',
            exampleVietnamese: 'Một từ từ xa.',
          ),
        ],
      );
      final state = AppState(
        store: LocalAppStore(),
        catalogStore: catalogStore,
      );

      await state.toggleFavorite('pencil');
      await state.createCollection('Bộ riêng');
      await state.recordAttempt(
        wordId: 'pencil',
        correct: true,
        now: DateTime(2026, 9, 18, 9),
      );

      await state.restoreStarterCatalog();

      expect(catalogStore.version, starterCatalogReleaseVersion);
      expect(catalogStore.words, hasLength(catalogWords.length));
      expect(state.favoriteWords, contains('pencil'));
      expect(state.collections, hasLength(1));
      expect(await state.store.reviewStateFor('pencil'), isNotNull);
    },
  );

  test('signing out resets the account-owned sync cursor', () async {
    final state = AppState(store: LocalAppStore());
    await state.store.setSyncCursor(42);
    await state.store.setLastSyncedAt(DateTime.utc(2026, 9, 18, 12, 30));

    await state.signOut();

    expect(state.store.syncCursor, 0);
    expect(state.store.lastSyncedAt, isNull);
  });

  test('last successful sync timestamp survives state reload', () async {
    final store = LocalAppStore();
    final syncedAt = DateTime.utc(2026, 9, 18, 12, 30);
    await store.setLastSyncedAt(syncedAt);

    final state = AppState(store: store);
    await state.load();

    expect(state.lastSyncedAt, syncedAt);
    await store.setLastSyncedAt(null);
  });

  test(
    'concurrent catalog downloads share one validated release request',
    () async {
      final catalogStore = _MemoryCatalogStore(
        version: starterCatalogReleaseVersion,
        words: catalogWords,
      );
      var fetchCount = 0;
      final state = AppState(
        store: LocalAppStore(),
        catalogStore: catalogStore,
        catalogReleaseFetcher: () async {
          fetchCount++;
          await Future<void>.delayed(const Duration(milliseconds: 5));
          return const CatalogRelease(
            version: 'published-1',
            words: [
              CatalogWord(
                id: 'published-pencil',
                english: 'Pencil',
                vietnamese: 'Bút chì',
                topic: 'Đồ dùng học tập',
                partOfSpeech: 'noun',
                exampleEnglish: 'I use a pencil.',
                exampleVietnamese: 'Em dùng bút chì.',
              ),
            ],
          );
        },
      );

      final releases = await Future.wait([
        state.downloadPublishedCatalog(),
        state.downloadPublishedCatalog(),
      ]);

      expect(fetchCount, 1);
      expect(releases.map((release) => release.version), [
        'published-1',
        'published-1',
      ]);
      expect(state.catalogReleaseVersion, 'published-1');
      expect(catalogStore.version, 'published-1');
    },
  );

  test('failed catalog download keeps the current offline release', () async {
    final catalogStore = _MemoryCatalogStore(
      version: starterCatalogReleaseVersion,
      words: catalogWords,
    );
    final state = AppState(
      store: LocalAppStore(),
      catalogStore: catalogStore,
      catalogReleaseFetcher: () async {
        throw const FormatException('manifest unavailable');
      },
    );

    await expectLater(
      state.downloadPublishedCatalog(),
      throwsA(isA<FormatException>()),
    );

    expect(state.catalogReleaseVersion, starterCatalogReleaseVersion);
    expect(catalogStore.version, starterCatalogReleaseVersion);
    expect(catalogStore.words, hasLength(catalogWords.length));
  });

  test(
    'missing cached media is not treated as offline-ready after hydrate',
    () async {
      const source = CatalogWord(
        id: 'remote-word',
        english: 'Remote word',
        vietnamese: 'Từ tải về',
        topic: 'Test',
        partOfSpeech: 'noun',
        exampleEnglish: 'A remote word.',
        exampleVietnamese: 'Một từ tải về.',
        imageUrl: 'https://example.org/remote-image.png',
      );
      final stale = source.copyWith(
        localImagePath: 'E:\\vocab-vision-missing-media\\pencil.img',
      );
      final catalogStore = _MemoryCatalogStore(
        version: 'published-1',
        words: [stale],
      );
      final state = AppState(
        store: LocalAppStore(),
        catalogStore: catalogStore,
      );

      await state.load();
      for (
        var attempt = 0;
        attempt < 20 && state.catalog.length != 1;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }

      expect(state.catalog.single.localImagePath, isNull);
      expect(state.catalog.single.hasOfflineImage, isFalse);
    },
  );

  test(
    'old starter catalog receives bundled illustrations on upgrade',
    () async {
      final catalogStore = _MemoryCatalogStore(
        version: 'starter-2026-09-media3',
        words: [catalogWords.first],
      );
      final state = AppState(
        store: LocalAppStore(),
        catalogStore: catalogStore,
      );
      addTearDown(state.dispose);
      await state.load();
      for (
        var attempt = 0;
        attempt < 20 && catalogStore.version != starterCatalogReleaseVersion;
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(catalogStore.version, starterCatalogReleaseVersion);
      expect(state.catalog, hasLength(300));
      expect(state.catalog.every((word) => word.hasOfflineImage), isTrue);
    },
  );

  test(
    'bundled media upgrade preserves a downloaded catalog release',
    () async {
      final catalogStore = _MemoryCatalogStore(
        version: 'published-existing',
        words: [catalogWords.first],
      );
      final state = AppState(
        store: LocalAppStore(),
        catalogStore: catalogStore,
      );
      addTearDown(state.dispose);
      await state.load();
      for (
        var attempt = 0;
        attempt < 20 && state.catalogReleaseVersion != 'published-existing';
        attempt++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      expect(state.catalogReleaseVersion, 'published-existing');
      expect(catalogStore.version, 'published-existing');
      expect(state.catalog, hasLength(1));
    },
  );

  test('catalog download cancellation keeps the current release', () async {
    final catalogStore = _MemoryCatalogStore(
      version: starterCatalogReleaseVersion,
      words: catalogWords,
    );
    final state = AppState(
      store: LocalAppStore(),
      catalogStore: catalogStore,
      catalogReleaseFetcher: () async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return const CatalogRelease(
          version: 'published-cancelled',
          words: [
            CatalogWord(
              id: 'cancelled-word',
              english: 'Word',
              vietnamese: 'Từ',
              topic: 'Test',
              partOfSpeech: 'noun',
              exampleEnglish: 'A word.',
              exampleVietnamese: 'Một từ.',
            ),
          ],
        );
      },
    );
    final request = state.downloadPublishedCatalog();
    state.cancelCatalogDownload();

    await expectLater(request, throwsA(isA<CatalogDownloadCancelled>()));
    expect(state.catalogReleaseVersion, starterCatalogReleaseVersion);
    expect(catalogStore.version, starterCatalogReleaseVersion);
    expect(state.catalogDownloadProgress, isNull);
  });
}

class _MemoryCatalogStore implements CatalogStore {
  _MemoryCatalogStore({required this.version, required List<CatalogWord> words})
    : words = List<CatalogWord>.of(words);

  String? version;
  List<CatalogWord> words;

  @override
  Future<List<CatalogWord>> all() async =>
      List<CatalogWord>.unmodifiable(words);

  @override
  Future<void> close() async {}

  @override
  Future<String?> get releaseVersion async => version;

  @override
  Future<void> replaceRelease({
    required String version,
    required List<CatalogWord> words,
  }) async {
    this.version = version;
    this.words = List<CatalogWord>.of(words);
  }
}
