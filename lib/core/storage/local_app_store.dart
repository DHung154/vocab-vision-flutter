import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../learning/review_scheduler.dart';
import '../learning/vocabulary_collection.dart';
import '../network/account_api_client.dart';
import 'secure_token_store.dart';

/// Local persistence boundary for the offline release.
///
/// Android uses SQLite for the durable key/value projection. Existing
/// SharedPreferences values are imported exactly once when the new database is
/// empty, so an upgrade does not reset a learner's progress. SharedPreferences
/// remains a desktop/widget fallback because sqflite has no Windows test
/// implementation in this project.
class LocalAppStore {
  static const _profileNameKey = 'profile.name';
  static const _dailyGoalKey = 'profile.daily_goal';
  static const _pointsKey = 'progress.points';
  static const _streakKey = 'progress.streak';
  static const _sessionsKey = 'progress.sessions';
  static const _todayWordsKey = 'progress.today_words';
  static const _lastActivityKey = 'progress.last_activity';
  static const _learnedWordsKey = 'progress.learned_words';
  static const _favoriteWordsKey = 'vocabulary.favorite_words';
  static const _soundFxKey = 'settings.sound_fx';
  static const _notificationsKey = 'settings.notifications';
  static const _themeColorKey = 'settings.theme_color';
  static const _directionKey = 'settings.direction';
  static const _difficultyKey = 'settings.difficulty';
  static const _bgMusicKey = 'settings.bg_music';
  static const _volumeKey = 'settings.volume';
  static const _vibrateKey = 'settings.vibrate';
  static const _dailyReminderKey = 'settings.daily_reminder';
  static const _darkModeKey = 'settings.dark_mode';
  static const _onboardingCompleteKey = 'profile.onboarding_complete';
  static const _collectionsKey = 'vocabulary.collections';
  static const _learningDraftKey = 'learning.draft';
  static const _spaceGameKey = 'minigame.space_words.v1';
  static const _authSessionKey = 'account.session';
  static const _syncCursorKey = 'account.sync_cursor';
  static const _lastSyncedAtKey = 'account.last_synced_at';

  static const _allKeys = <String>[
    _profileNameKey,
    _dailyGoalKey,
    _pointsKey,
    _streakKey,
    _sessionsKey,
    _todayWordsKey,
    _lastActivityKey,
    _learnedWordsKey,
    _favoriteWordsKey,
    _soundFxKey,
    _notificationsKey,
    _themeColorKey,
    _directionKey,
    _difficultyKey,
    _bgMusicKey,
    _volumeKey,
    _vibrateKey,
    _dailyReminderKey,
    _darkModeKey,
    _onboardingCompleteKey,
    _collectionsKey,
    _learningDraftKey,
    _spaceGameKey,
    _authSessionKey,
    _syncCursorKey,
    _lastSyncedAtKey,
  ];

  SharedPreferences? _preferences;
  final Map<String, Object> _memory = {};
  Database? _database;
  String? _persistenceError;
  final Map<String, ReviewState> _reviewMemory = <String, ReviewState>{};
  final List<Map<String, Object?>> _attemptMemory = [];
  final Map<String, Map<String, Object?>> _outboxMemory = {};
  final SecureTokenStore _secureTokenStore = SecureTokenStore();
  int _eventCounter = 0;
  Future<void>? _opening;

  /// Non-null when Android could not open the durable SQLite store. The app
  /// keeps a best-effort in-process/legacy preference fallback so it can show
  /// a recovery message, but never presents that fallback as a successful
  /// durable save.
  String? get persistenceError => _persistenceError;

  /// Marks a boot-time storage timeout without pretending that data was
  /// persisted. The shell can still open in memory-only mode and expose the
  /// existing retry action to the learner.
  void markPersistenceUnavailable() {
    _persistenceError ??=
        'Cơ sở dữ liệu cục bộ khởi động quá lâu. Dữ liệu mới chỉ tạm thời; hãy thử lại.';
  }

  void _markPersistenceFailure() {
    _persistenceError ??=
        'Không ghi được cơ sở dữ liệu cục bộ. Dữ liệu mới chỉ tạm thời; hãy thử lại.';
  }

  /// Opens SQLite at most once at a time. AppState deliberately has a bounded
  /// Android boot wait; when that wait expires the original open future can
  /// still be finishing in the platform plugin. Coalescing retries prevents a
  /// second connection from racing the first one and losing the recovery copy.
  Future<void> open() {
    final current = _opening;
    if (current != null) return current;
    final next = _openInternal();
    late final Future<void> completion;
    completion = next.whenComplete(() {
      if (identical(_opening, completion)) _opening = null;
    });
    _opening = completion;
    return completion;
  }

  Future<void> _openInternal() async {
    final preferences = await _openPreferences();
    if (Platform.isAndroid) {
      final fallbackValues = Map<String, Object>.from(_memory);
      final hadFallbackRows =
          _reviewMemory.isNotEmpty ||
          _attemptMemory.isNotEmpty ||
          _outboxMemory.isNotEmpty;
      try {
        _database = await _openDatabase();
        _persistenceError = null;
        await _loadDatabaseValues();
        if (fallbackValues.isNotEmpty || hadFallbackRows) {
          // Values collected while SQLite was unavailable are newer than the
          // copy read from disk. Put them back before promoting the fallback
          // so a retry cannot silently discard work from that session.
          _memory.addAll(fallbackValues);
          await _database!.transaction((txn) async {
            for (final entry in fallbackValues.entries) {
              await _writeDatabaseValue(txn, entry.key, entry.value);
            }
          });
          await _promoteFallbackRows();
        } else if (_memory.isEmpty) {
          await _importPreferences(preferences);
        } else if (_database != null) {
          // A previous open can leave a best-effort key/value copy even when
          // SharedPreferences is unavailable. Promote it on retry instead of
          // making durable recovery depend on that optional fallback.
          await _database!.transaction((txn) async {
            for (final entry in _memory.entries) {
              await _writeDatabaseValue(txn, entry.key, entry.value);
            }
          });
        }
        await _migrateAuthSessionToSecureStorage();
        _preferences = null;
      } catch (_) {
        // Keep a best-effort fallback so the learner can export/retry, but
        // expose the failure to the UI instead of claiming that data is
        // durable. A later app restart retries opening SQLite.
        _persistenceError =
            'Không mở được cơ sở dữ liệu cục bộ. Dữ liệu mới chỉ tạm thời; hãy thử lại.';
        _database = null;
        _preferences = preferences;
      }
    } else {
      _preferences = preferences;
    }
    // The home card represents today's distinct words, not yesterday's
    // cached number. Keep the last activity for streak calculation but reset
    // only this display counter when the local calendar day changes.
    final last = lastActivity;
    if (last != null && last != _dateKey(DateTime.now()) && todayWords != 0) {
      await _writeInt(_todayWordsKey, 0);
    }
  }

  Future<void> _promoteFallbackRows() async {
    final db = _database;
    if (db == null ||
        (_reviewMemory.isEmpty &&
            _attemptMemory.isEmpty &&
            _outboxMemory.isEmpty)) {
      return;
    }
    await db.transaction((txn) async {
      for (final state in _reviewMemory.values) {
        await txn.insert(
          'review_states',
          state.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final attempt in _attemptMemory) {
        await txn.insert(
          'learning_attempts',
          attempt,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final event in _outboxMemory.values) {
        await txn.insert(
          'outbox',
          event,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
  }

  Future<SharedPreferences?> _openPreferences() async {
    try {
      return await SharedPreferences.getInstance();
    } catch (_) {
      return null;
    }
  }

  Future<Database> _openDatabase() async {
    final root = await getDatabasesPath();
    return openDatabase(
      path.join(root, 'vocab_app_state.db'),
      version: 4,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE app_kv (
            key TEXT PRIMARY KEY,
            value_type TEXT NOT NULL,
            value_json TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await _createReviewStatesTable(db);
        await _createLearningTables(db);
      },
      onUpgrade: (db, oldVersion, _) async {
        if (oldVersion < 2) await _createReviewStatesTable(db);
        if (oldVersion < 3) await _createLearningTables(db);
        await _ensureSessionIdColumn(db);
      },
    );
  }

  Future<void> _createReviewStatesTable(DatabaseExecutor db) => db.execute('''
    CREATE TABLE IF NOT EXISTS review_states (
      word_id TEXT PRIMARY KEY,
      level INTEGER NOT NULL DEFAULT 0,
      recall_count INTEGER NOT NULL DEFAULT 0,
      last_reviewed_at TEXT,
      due_at TEXT NOT NULL,
      mastered INTEGER NOT NULL DEFAULT 0
    )
  ''');

  Future<void> _createLearningTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS learning_attempts (
        event_id TEXT PRIMARY KEY,
        word_id TEXT NOT NULL,
        correct INTEGER NOT NULL,
        assisted INTEGER NOT NULL,
        question_type TEXT NOT NULL,
        session_id TEXT NOT NULL DEFAULT '',
        answered_at TEXT NOT NULL,
        review_level INTEGER NOT NULL,
        rules_version TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS outbox (
        event_id TEXT PRIMARY KEY,
        event_type TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attempts INTEGER NOT NULL DEFAULT 0,
        next_retry_at TEXT
      )
    ''');
  }

  Future<void> _ensureSessionIdColumn(DatabaseExecutor db) async {
    final columns = await db.rawQuery('PRAGMA table_info(learning_attempts)');
    final hasSessionId = columns.any((row) => row['name'] == 'session_id');
    if (!hasSessionId) {
      await db.execute(
        "ALTER TABLE learning_attempts ADD COLUMN session_id TEXT NOT NULL DEFAULT ''",
      );
    }
  }

  Future<void> _loadDatabaseValues() async {
    final rows = await _database!.query('app_kv');
    for (final row in rows) {
      final key = row['key'];
      final encoded = row['value_json'];
      if (key is! String || encoded is! String) continue;
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is String || decoded is num || decoded is bool) {
          _memory[key] = decoded is num && decoded is! int
              ? decoded.toDouble()
              : decoded;
        } else if (decoded is List) {
          _memory[key] = decoded.map((item) => item.toString()).toList();
        }
      } catch (_) {
        // A malformed row is ignored; it cannot overwrite valid defaults.
      }
    }
  }

  Future<void> _importPreferences(SharedPreferences? preferences) async {
    if (preferences == null) return;
    for (final key in _allKeys) {
      if (!preferences.containsKey(key)) continue;
      final value = preferences.get(key);
      if (value is String) {
        _memory[key] = value;
      } else if (value is int) {
        _memory[key] = value;
      } else if (value is double) {
        _memory[key] = value;
      } else if (value is bool) {
        _memory[key] = value;
      } else if (value is List<String>) {
        _memory[key] = List<String>.from(value);
      }
    }
    if (_memory.isEmpty) return;
    await _database!.transaction((txn) async {
      for (final entry in _memory.entries) {
        await _writeDatabaseValue(txn, entry.key, entry.value);
      }
    });
  }

  Future<void> _writeDatabaseValue(
    DatabaseExecutor executor,
    String key,
    Object value,
  ) async {
    final type = switch (value) {
      String() => 'string',
      int() => 'int',
      double() => 'double',
      bool() => 'bool',
      List<String>() => 'string_list',
      _ => throw ArgumentError('Unsupported local value for $key'),
    };
    await executor.insert('app_kv', {
      'key': key,
      'value_type': type,
      'value_json': jsonEncode(value),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String get profileName => _readString(_profileNameKey) ?? 'Bo';
  int get dailyGoal => _readInt(_dailyGoalKey) ?? 10;
  int get points => _readInt(_pointsKey) ?? 0;
  int get streak => _readInt(_streakKey) ?? 0;
  int get sessions => _readInt(_sessionsKey) ?? 0;
  int get todayWords => _readInt(_todayWordsKey) ?? 0;
  String? get lastActivity => _readString(_lastActivityKey);
  Set<String> get learnedWords =>
      (_readStringList(_learnedWordsKey) ?? const <String>[]).toSet();
  Set<String> get favoriteWords =>
      (_readStringList(_favoriteWordsKey) ?? const <String>[]).toSet();
  bool get soundFx => _readBool(_soundFxKey) ?? true;
  bool get notifications => _readBool(_notificationsKey) ?? true;
  int get themeColor => _readInt(_themeColorKey) ?? 0;
  int get direction => _readInt(_directionKey) ?? 0;
  int get difficulty => _readInt(_difficultyKey) ?? 1;
  bool get bgMusic => _readBool(_bgMusicKey) ?? true;
  double get volume => _readDouble(_volumeKey) ?? 0.7;
  bool get vibrate => _readBool(_vibrateKey) ?? true;
  bool get dailyReminder => _readBool(_dailyReminderKey) ?? true;
  bool get darkMode => _readBool(_darkModeKey) ?? false;
  bool get onboardingComplete => _readBool(_onboardingCompleteKey) ?? false;

  List<VocabularyCollection> get collections {
    final encoded = _readString(_collectionsKey);
    if (encoded == null) return const [];
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return const [];
      return decoded
          .map(VocabularyCollection.fromJson)
          .whereType<VocabularyCollection>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Map<String, dynamic>? get learningDraft {
    final encoded = _readString(_learningDraftKey);
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // A corrupt draft must not prevent the rest of the app from opening.
    }
    return null;
  }

  AuthSession? get authSession {
    final encoded = _readString(_authSessionKey);
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) {
        return AuthSession.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {
      // An expired/corrupt session is treated as guest, never as a fatal boot
      // error. The learner's local catalog and progress remain available.
    }
    return null;
  }

  int get syncCursor => _readInt(_syncCursorKey) ?? 0;

  DateTime? get lastSyncedAt {
    final encoded = _readString(_lastSyncedAtKey);
    return encoded == null ? null : DateTime.tryParse(encoded);
  }

  Future<void> saveLearningDraft(Map<String, dynamic> draft) =>
      _writeString(_learningDraftKey, jsonEncode(draft));

  Map<String, dynamic> get spaceGameProgress {
    try {
      final value = jsonDecode(_readString(_spaceGameKey) ?? '{}');
      return value is Map ? Map<String, dynamic>.from(value) : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveSpaceGameProgress(Map<String, dynamic> progress) =>
      _writeString(_spaceGameKey, jsonEncode(progress));

  Future<void> clearLearningDraft() => _writeString(_learningDraftKey, '');

  Future<void> saveAuthSession(AuthSession session) =>
      _saveAuthSessionJson(jsonEncode(session.toJson()));

  Future<void> clearAuthSession() async {
    if (Platform.isAndroid) {
      try {
        await _secureTokenStore.delete(_authSessionKey);
        await _deleteDurableValue(_authSessionKey);
        _memory.remove(_authSessionKey);
        return;
      } catch (_) {
        _markPersistenceFailure();
        await _deleteDurableValue(_authSessionKey);
        _memory.remove(_authSessionKey);
        return;
      }
    }
    await _writeString(_authSessionKey, '');
  }

  Future<void> setSyncCursor(int value) =>
      _writeInt(_syncCursorKey, value < 0 ? 0 : value);

  Future<void> setLastSyncedAt(DateTime? value) async {
    if (value == null) {
      _memory.remove(_lastSyncedAtKey);
      await _deleteDurableValue(_lastSyncedAtKey);
      return;
    }
    await _writeString(_lastSyncedAtKey, value.toUtc().toIso8601String());
  }

  Future<void> setProfileName(String value) {
    final trimmed = value.trim();
    final safe = trimmed.isEmpty
        ? 'Bo'
        : trimmed.substring(0, trimmed.length.clamp(1, 24));
    return _writeString(_profileNameKey, safe);
  }

  Future<void> setDailyGoal(int value) =>
      _writeInt(_dailyGoalKey, value.clamp(5, 15));

  Future<void> setFavoriteWords(Iterable<String> values) {
    final normalized = values.toSet().toList()..sort();
    return _writeStringList(_favoriteWordsKey, normalized);
  }

  Future<void> setSoundFx(bool value) => _writeBool(_soundFxKey, value);
  Future<void> setNotifications(bool value) =>
      _writeBool(_notificationsKey, value);
  Future<void> setThemeColor(int value) => _writeInt(_themeColorKey, value);
  Future<void> setDirection(int value) => _writeInt(_directionKey, value);
  Future<void> setDifficulty(int value) => _writeInt(_difficultyKey, value);
  Future<void> setBgMusic(bool value) => _writeBool(_bgMusicKey, value);
  Future<void> setVolume(double value) => _writeDouble(_volumeKey, value);
  Future<void> setVibrate(bool value) => _writeBool(_vibrateKey, value);
  Future<void> setDailyReminder(bool value) =>
      _writeBool(_dailyReminderKey, value);
  Future<void> setDarkMode(bool value) => _writeBool(_darkModeKey, value);
  Future<void> setOnboardingComplete(bool value) =>
      _writeBool(_onboardingCompleteKey, value);

  Future<void> saveCollections(Iterable<VocabularyCollection> values) {
    final normalized = values
        .map(
          (collection) => collection.copyWith(
            name: collection.name.trim().isEmpty
                ? 'Bộ sưu tập'
                : collection.name.trim(),
          ),
        )
        .toList(growable: false);
    return _writeString(
      _collectionsKey,
      jsonEncode(normalized.map((collection) => collection.toJson()).toList()),
    );
  }

  Future<void> recordSession({
    required int correct,
    required int total,
    required Iterable<String> wordLabels,
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final date = _dateKey(current);
    final previousDate = lastActivity;
    final existingToday = previousDate == date;
    final wasYesterday =
        previousDate == _dateKey(current.subtract(const Duration(days: 1)));
    final nextStreak = existingToday
        ? streak
        : wasYesterday
        ? streak + 1
        : 1;
    final newWords = wordLabels.toSet().difference(learnedWords);
    final mergedWords = {...learnedWords, ...wordLabels};

    await _writeValues({
      _pointsKey: points + (correct.clamp(0, total) * 10),
      _streakKey: nextStreak,
      _sessionsKey: sessions + 1,
      _todayWordsKey: existingToday
          ? todayWords + newWords.length
          : wordLabels.toSet().length,
      _lastActivityKey: date,
      _learnedWordsKey: mergedWords.toList()..sort(),
    });
  }

  Future<void> recordAttempt({
    required String wordId,
    required bool correct,
    bool assisted = false,
    String questionType = 'unknown',
    String sessionId = '',
    DateTime? now,
  }) async {
    final current = now ?? DateTime.now();
    final scheduler = const ReviewScheduler();
    final previous = await reviewStateFor(wordId);
    final next = scheduler.apply(
      wordId: wordId,
      previous: previous,
      correct: correct,
      assisted: assisted,
      now: current,
    );
    final eventId = _nextEventId(current);
    final attempt = <String, Object?>{
      'event_id': eventId,
      'word_id': wordId,
      'correct': correct ? 1 : 0,
      'assisted': assisted ? 1 : 0,
      'question_type': questionType,
      'session_id': sessionId,
      'answered_at': current.toUtc().toIso8601String(),
      'review_level': next.level,
      'rules_version': 'review-v1',
    };
    final payload = <String, Object?>{
      'event_id': eventId,
      'event_type': 'learning_attempt',
      'word_id': wordId,
      'correct': correct,
      'assisted': assisted,
      'question_type': questionType,
      'session_id': sessionId,
      'answered_at': current.toUtc().toIso8601String(),
      'review_level': next.level,
      'rules_version': 'review-v1',
    };
    final outbox = <String, Object?>{
      'event_id': eventId,
      'event_type': 'learning_attempt',
      'payload_json': jsonEncode(payload),
      'created_at': current.toUtc().toIso8601String(),
      'attempts': 0,
      'next_retry_at': null,
    };
    final db = _database;
    if (db == null) {
      _reviewMemory[wordId] = next;
      _attemptMemory.add(attempt);
      _outboxMemory[eventId] = outbox;
      return;
    }
    try {
      await db.transaction((txn) async {
        await txn.insert(
          'review_states',
          next.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'learning_attempts',
          attempt,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'outbox',
          outbox,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      });
    } catch (_) {
      _markPersistenceFailure();
      _reviewMemory[wordId] = next;
      _attemptMemory.add(attempt);
      _outboxMemory[eventId] = outbox;
      return;
    }
    _reviewMemory[wordId] = next;
    _attemptMemory.add(attempt);
    _outboxMemory[eventId] = outbox;
  }

  String _nextEventId(DateTime now) =>
      '${now.microsecondsSinceEpoch}-${_eventCounter++}';

  /// Returns unsent events in creation order for authenticated sync.
  Future<List<Map<String, dynamic>>> pendingOutboxEvents() async {
    final db = _database;
    if (db == null) {
      return _outboxMemory.values
          .map((row) {
            final event = Map<String, dynamic>.from(row);
            final encoded = event['payload_json'];
            if (encoded is String) {
              try {
                event['payload'] = jsonDecode(encoded);
              } catch (_) {
                event['payload'] = const <String, dynamic>{};
              }
            }
            return event;
          })
          .toList(growable: false);
    }
    final rows = await db.query('outbox', orderBy: 'created_at ASC');
    return rows
        .map((row) {
          final event = Map<String, dynamic>.from(row);
          final encoded = event['payload_json'];
          if (encoded is String) {
            try {
              event['payload'] = jsonDecode(encoded);
            } catch (_) {
              event['payload'] = const <String, dynamic>{};
            }
          }
          return event;
        })
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> recentAttempts({int limit = 20}) async {
    final safeLimit = limit.clamp(1, 100);
    final db = _database;
    if (db == null) {
      return _attemptMemory.reversed
          .take(safeLimit)
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    final rows = await db.query(
      'learning_attempts',
      orderBy: 'answered_at DESC',
      limit: safeLimit,
    );
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  Future<void> acknowledgeOutbox(Iterable<String> eventIds) async {
    final ids = eventIds.where((id) => id.trim().isNotEmpty).toSet();
    if (ids.isEmpty) return;
    final db = _database;
    if (db == null) {
      for (final id in ids) {
        _outboxMemory.remove(id);
      }
      return;
    }
    try {
      await db.transaction((txn) async {
        for (final id in ids) {
          await txn.delete('outbox', where: 'event_id = ?', whereArgs: [id]);
        }
      });
    } catch (_) {
      _markPersistenceFailure();
      return;
    }
    for (final id in ids) {
      _outboxMemory.remove(id);
    }
  }

  /// Applies a server event exactly once without putting it back into the
  /// outbox. This is the inbound half of account sync; local attempts continue
  /// to use [recordAttempt], which always creates a new outbound event.
  Future<void> applyRemoteAttempt(Map<String, dynamic> event) async {
    final eventId = event['event_id'];
    final rawPayload = event['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    final wordId = payload['word_id'] ?? event['word_id'];
    if (eventId is! String ||
        eventId.isEmpty ||
        wordId is! String ||
        wordId.isEmpty) {
      return;
    }
    final db = _database;
    if (db == null) {
      if (_attemptMemory.any((row) => row['event_id'] == eventId)) return;
      final now =
          DateTime.tryParse(
            '${payload['answered_at'] ?? event['occurred_at']}',
          ) ??
          DateTime.now();
      final correct = payload['correct'] == true || payload['correct'] == 1;
      final assisted = payload['assisted'] == true || payload['assisted'] == 1;
      final next = const ReviewScheduler().apply(
        wordId: wordId,
        previous: _reviewMemory[wordId],
        correct: correct,
        assisted: assisted,
        now: now,
      );
      _reviewMemory[wordId] = next;
      _attemptMemory.add({
        'event_id': eventId,
        'word_id': wordId,
        'correct': correct ? 1 : 0,
        'assisted': assisted ? 1 : 0,
        'question_type': payload['question_type'] ?? 'unknown',
        'session_id': payload['session_id'] ?? '',
        'answered_at': now.toUtc().toIso8601String(),
        'review_level': next.level,
        'rules_version': payload['rules_version'] ?? 'review-v1',
      });
      return;
    }
    final existing = await db.query(
      'learning_attempts',
      columns: ['event_id'],
      where: 'event_id = ?',
      whereArgs: [eventId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;
    final now =
        DateTime.tryParse(
          '${payload['answered_at'] ?? event['occurred_at']}',
        ) ??
        DateTime.now();
    final correct = payload['correct'] == true || payload['correct'] == 1;
    final assisted = payload['assisted'] == true || payload['assisted'] == 1;
    final next = const ReviewScheduler().apply(
      wordId: wordId,
      previous: await reviewStateFor(wordId),
      correct: correct,
      assisted: assisted,
      now: now,
    );
    final attempt = <String, Object?>{
      'event_id': eventId,
      'word_id': wordId,
      'correct': correct ? 1 : 0,
      'assisted': assisted ? 1 : 0,
      'question_type': payload['question_type'] ?? 'unknown',
      'session_id': payload['session_id'] ?? '',
      'answered_at': now.toUtc().toIso8601String(),
      'review_level': next.level,
      'rules_version': payload['rules_version'] ?? 'review-v1',
    };
    try {
      await db.transaction((txn) async {
        await txn.insert(
          'review_states',
          next.toJson(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.insert(
          'learning_attempts',
          attempt,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      });
    } catch (_) {
      _markPersistenceFailure();
      return;
    }
    _reviewMemory[wordId] = next;
    _attemptMemory.add(attempt);
  }

  Future<ReviewState?> reviewStateFor(String wordId) async {
    final cached = _reviewMemory[wordId];
    if (cached != null) return cached;
    final db = _database;
    if (db == null) return null;
    final rows = await db.query(
      'review_states',
      where: 'word_id = ?',
      whereArgs: [wordId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final state = ReviewState.fromJson(rows.first);
    _reviewMemory[wordId] = state;
    return state;
  }

  Future<List<ReviewState>> dueReviewStates({DateTime? now}) async {
    final current = (now ?? DateTime.now()).toUtc().toIso8601String();
    final db = _database;
    if (db == null) {
      return _reviewMemory.values
          .where((state) => !state.dueAt.isAfter(now ?? DateTime.now()))
          .toList(growable: false);
    }
    final rows = await db.query(
      'review_states',
      where: 'due_at <= ?',
      whereArgs: [current],
      orderBy: 'due_at ASC',
    );
    return rows.map(ReviewState.fromJson).toList(growable: false);
  }

  Future<void> resetProgress() async {
    await _writeValues(
      {
        _pointsKey: 0,
        _streakKey: 0,
        _sessionsKey: 0,
        _todayWordsKey: 0,
        _lastActivityKey: '',
        _learnedWordsKey: <String>[],
        _learningDraftKey: '',
      },
      databaseAction: (txn) async {
        // Progress reset must remove the durable scheduler rows in the same
        // transaction as the counters, otherwise a fresh install/relaunch can
        // surface stale review cards after the user tapped “Xóa tiến độ”.
        await txn.delete('review_states');
        await txn.delete('learning_attempts');
        await txn.delete('outbox');
      },
    );
    _reviewMemory.clear();
    _attemptMemory.clear();
    _outboxMemory.clear();
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String? _readString(String key) {
    final value = _preferences?.getString(key) ?? _memory[key];
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<void> _saveAuthSessionJson(String encoded) async {
    if (!Platform.isAndroid) {
      await _writeString(_authSessionKey, encoded);
      return;
    }
    try {
      await _secureTokenStore.write(_authSessionKey, encoded);
      _memory[_authSessionKey] = encoded;
      await _deleteDurableValue(_authSessionKey);
    } catch (_) {
      _markPersistenceFailure();
      rethrow;
    }
  }

  Future<void> _migrateAuthSessionToSecureStorage() async {
    if (!Platform.isAndroid) return;
    try {
      final secure = await _secureTokenStore.read(_authSessionKey);
      final legacy = _readString(_authSessionKey);
      final value = secure ?? legacy;
      if (value != null && value.isNotEmpty) {
        if (secure == null) {
          await _secureTokenStore.write(_authSessionKey, value);
        }
        _memory[_authSessionKey] = value;
        await _deleteDurableValue(_authSessionKey);
      }
    } catch (_) {
      // Keep the old value available for a retry, but expose that the secure
      // migration did not complete instead of claiming a protected session.
      _markPersistenceFailure();
    }
  }

  Future<void> _deleteDurableValue(String key) async {
    try {
      await _database?.delete('app_kv', where: 'key = ?', whereArgs: [key]);
      await _preferences?.remove(key);
    } catch (_) {
      _markPersistenceFailure();
    }
  }

  int? _readInt(String key) {
    final value = _preferences?.getInt(key) ?? _memory[key];
    return value is int ? value : null;
  }

  double? _readDouble(String key) {
    final value = _preferences?.getDouble(key) ?? _memory[key];
    return value is double ? value : null;
  }

  bool? _readBool(String key) {
    final value = _preferences?.getBool(key) ?? _memory[key];
    return value is bool ? value : null;
  }

  List<String>? _readStringList(String key) {
    final value = _preferences?.getStringList(key) ?? _memory[key];
    return value is List<String> ? value : null;
  }

  Future<void> _writeString(String key, String value) async {
    final db = _database;
    if (db != null) {
      try {
        await _writeDatabaseValue(db, key, value);
      } catch (_) {
        _markPersistenceFailure();
      }
    }
    await _preferences?.setString(key, value);
    _memory[key] = value;
  }

  Future<void> _writeStringList(String key, List<String> value) async {
    final db = _database;
    if (db != null) {
      try {
        await _writeDatabaseValue(db, key, value);
      } catch (_) {
        _markPersistenceFailure();
      }
    }
    await _preferences?.setStringList(key, value);
    _memory[key] = value;
  }

  Future<void> _writeInt(String key, int value) async {
    final db = _database;
    if (db != null) {
      try {
        await _writeDatabaseValue(db, key, value);
      } catch (_) {
        _markPersistenceFailure();
      }
    }
    await _preferences?.setInt(key, value);
    _memory[key] = value;
  }

  Future<void> _writeDouble(String key, double value) async {
    final db = _database;
    if (db != null) {
      try {
        await _writeDatabaseValue(db, key, value);
      } catch (_) {
        _markPersistenceFailure();
      }
    }
    await _preferences?.setDouble(key, value);
    _memory[key] = value;
  }

  Future<void> _writeBool(String key, bool value) async {
    final db = _database;
    if (db != null) {
      try {
        await _writeDatabaseValue(db, key, value);
      } catch (_) {
        _markPersistenceFailure();
      }
    }
    await _preferences?.setBool(key, value);
    _memory[key] = value;
  }

  Future<void> _writeValues(
    Map<String, Object> values, {
    Future<void> Function(DatabaseExecutor txn)? databaseAction,
  }) async {
    final db = _database;
    if (db != null) {
      try {
        await db.transaction((txn) async {
          await databaseAction?.call(txn);
          for (final entry in values.entries) {
            await _writeDatabaseValue(txn, entry.key, entry.value);
          }
        });
        _memory.addAll(values);
        return;
      } catch (_) {
        _markPersistenceFailure();
        // Continue into the preference/memory fallback below. The visible
        // warning tells the learner that this copy is not durable yet.
      }
    }
    for (final entry in values.entries) {
      switch (entry.value) {
        case String value:
          await _preferences?.setString(entry.key, value);
        case int value:
          await _preferences?.setInt(entry.key, value);
        case double value:
          await _preferences?.setDouble(entry.key, value);
        case bool value:
          await _preferences?.setBool(entry.key, value);
        case List<String> value:
          await _preferences?.setStringList(entry.key, value);
        default:
          throw ArgumentError('Unsupported local value for ${entry.key}');
      }
    }
    _memory.addAll(values);
  }

  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening;
      } catch (_) {
        // The caller is shutting down; an already failed open has nothing to
        // close and must not mask the app's dispose path.
      }
    }
    final db = _database;
    _database = null;
    await db?.close();
  }
}
