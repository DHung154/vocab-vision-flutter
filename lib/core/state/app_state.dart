import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../catalog_data.dart';
import '../learning/review_scheduler.dart';
import '../learning/vocabulary_collection.dart';
import '../network/account_api_client.dart';
import '../network/catalog_api_client.dart';
import '../storage/catalog_database.dart';
import '../storage/catalog_media_cache.dart';
import '../storage/local_app_store.dart';

typedef CatalogReleaseFetcher = Future<CatalogRelease> Function();

class AppState extends ChangeNotifier {
  AppState({
    LocalAppStore? store,
    AccountApiClient? accountApi,
    CatalogApiClient? catalogApi,
    CatalogStore? catalogStore,
    CatalogMediaCache? catalogMediaCache,
    CatalogReleaseFetcher? catalogReleaseFetcher,
  }) : _store = store ?? LocalAppStore(),
       _accountApi = accountApi,
       _catalogApi = catalogApi,
       _catalogDatabase = catalogStore ?? CatalogDatabase(),
       _catalogMediaCache = catalogMediaCache ?? CatalogMediaCache(),
       _catalogReleaseFetcher = catalogReleaseFetcher;

  final LocalAppStore _store;
  AccountApiClient? _accountApi;

  LocalAppStore get store => _store;

  bool _ready = false;
  String _profileName = 'Bo';
  int _dailyGoal = 10;
  int _points = 0;
  int _streak = 0;
  int _sessions = 0;
  int _todayWords = 0;
  int _attemptRevision = 0;
  Set<String> _learnedWords = <String>{};
  Set<String> _favoriteWords = <String>{};
  bool _soundFx = true;
  bool _notifications = true;
  int _themeColor = 0;
  int _direction = 0;
  int _difficulty = 1;
  bool _bgMusic = true;
  double _volume = 0.7;
  bool _vibrate = true;
  bool _dailyReminder = true;
  bool _darkMode = false;
  bool _onboardingComplete = false;
  List<VocabularyCollection> _collections = const [];
  Map<String, dynamic>? _learningDraft;
  List<CatalogWord> _catalog = catalogWords;
  List<CatalogWord>? _catalogViewSource;
  List<CatalogWord>? _catalogView;
  String _catalogReleaseVersion = starterCatalogReleaseVersion;
  final CatalogStore _catalogDatabase;
  final CatalogMediaCache _catalogMediaCache;
  CatalogApiClient? _catalogApi;
  final CatalogReleaseFetcher? _catalogReleaseFetcher;
  Future<CatalogRelease>? _catalogDownloadInFlight;
  bool _catalogDownloadCancelRequested = false;
  double? _catalogDownloadProgress;
  Future<void>? _catalogWriteLock;
  AuthSession? _authSession;
  bool _syncing = false;
  String? _syncError;
  DateTime? _lastSyncedAt;
  bool _disposed = false;

  bool get ready => _ready;
  String get profileName => _profileName;
  int get dailyGoal => _dailyGoal;
  int get points => _points;
  int get streak => _streak;
  int get sessions => _sessions;
  int get todayWords => _todayWords;
  Set<String> get learnedWords => UnmodifiableSetView(_learnedWords);
  Set<String> get favoriteWords => UnmodifiableSetView(_favoriteWords);
  bool get soundFx => _soundFx;
  bool get notifications => _notifications;
  int get themeColor => _themeColor;
  int get direction => _direction;
  int get difficulty => _difficulty;
  bool get bgMusic => _bgMusic;
  double get volume => _volume;
  bool get vibrate => _vibrate;
  bool get dailyReminder => _dailyReminder;
  bool get darkMode => _darkMode;
  bool get onboardingComplete => _onboardingComplete;
  List<VocabularyCollection> get collections =>
      UnmodifiableListView(_collections);
  List<CatalogWord> get catalog {
    if (!identical(_catalog, _catalogViewSource)) {
      _catalogViewSource = _catalog;
      _catalogView = UnmodifiableListView(_catalog);
    }
    return _catalogView!;
  }

  String get catalogReleaseVersion => _catalogReleaseVersion;
  Map<String, dynamic>? get learningDraft =>
      _learningDraft == null ? null : Map.unmodifiable(_learningDraft!);
  AuthSession? get authSession => _authSession;
  bool get signedIn => _authSession != null;
  bool get syncing => _syncing;
  String? get syncError => _syncError;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  double? get catalogDownloadProgress => _catalogDownloadProgress;

  /// Changes only when recent attempt history may have changed.
  int get attemptRevision => _attemptRevision;
  String? get persistenceError => _store.persistenceError;

  int get achievementCount => List<bool>.generate(
    12,
    isAchievementUnlocked,
  ).where((value) => value).length;

  /// One source of truth for the badge list shown on profile and progress.
  /// Thresholds use the bundled 300-word starter catalog, while the final
  /// 3,000-word release can keep the same IDs and raise only the copy/targets.
  bool isAchievementUnlocked(int index) => switch (index) {
    0 => _streak >= 5,
    1 => _learnedWords.length >= 10,
    2 => _sessions >= 1,
    3 => _points >= 100,
    4 => _learnedWords.length >= 25,
    5 => _learnedWords.length >= 50,
    6 => _points >= 500,
    7 => _streak >= 30,
    8 => _sessions >= 10,
    9 => _learnedWords.length >= 100,
    10 => _sessions >= 20,
    11 => _learnedWords.length >= 300,
    _ => false,
  };

  Future<void> load() async {
    try {
      // A broken/locked Android database must never leave the user at the
      // native launch splash forever. The store keeps its in-memory fallback
      // and the shell exposes a retry action when this deadline is reached.
      final opening = _store.open();
      // Keep host/widget tests deterministic: their fake clock must not carry
      // a real-device timeout timer across widget disposal.
      await (Platform.isAndroid
          ? opening.timeout(const Duration(seconds: 12))
          : opening);
    } on TimeoutException {
      _store.markPersistenceUnavailable();
    } catch (_) {
      // LocalAppStore normally catches platform/database failures itself, but
      // keep the app usable if a plugin throws before that fallback runs.
      _store.markPersistenceUnavailable();
    }
    _syncFromStore();
    _ready = true;
    notifyListeners();
    unawaited(_refreshAuthIfNeeded());
    unawaited(_hydrateCatalog());
  }

  Future<void> recordSession({
    required int correct,
    required int total,
    required Iterable<String> wordLabels,
    DateTime? now,
  }) async {
    await _store.recordSession(
      correct: correct,
      total: total,
      wordLabels: wordLabels,
      now: now,
    );
    _syncFromStore();
    notifyListeners();
  }

  Future<void> retryPersistence() async {
    if (_store.persistenceError == null) return;
    try {
      await _store.open();
    } catch (_) {
      // LocalAppStore keeps the original persistenceError for the visible
      // warning; retrying must not crash the shell.
    }
    _syncFromStore();
    notifyListeners();
  }

  Future<void> recordAttempt({
    required String wordId,
    required bool correct,
    bool assisted = false,
    String questionType = 'unknown',
    String sessionId = '',
    DateTime? now,
  }) async {
    await _store.recordAttempt(
      wordId: wordId,
      correct: correct,
      assisted: assisted,
      questionType: questionType,
      sessionId: sessionId,
      now: now,
    );
    _attemptRevision++;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    final client = _configuredAccountApi();
    final session = await client.login(email: email, password: password);
    await _acceptAccountSession(session);
  }

  Future<void> _acceptAccountSession(AuthSession session) async {
    // A cursor belongs to one server account. Reset it when entering a new
    // account (including after logout) so a second learner on this device
    // cannot skip their own history because of the previous cursor.
    if (_authSession?.user.id != session.user.id) {
      await _store.setSyncCursor(0);
      await _store.setLastSyncedAt(null);
    }
    await _store.saveAuthSession(session);
    _authSession = session;
    _syncError = null;
    notifyListeners();
  }

  Future<void> registerAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final client = _configuredAccountApi();
    final session = await client.register(
      email: email,
      password: password,
      displayName: displayName,
    );
    await _acceptAccountSession(session);
  }

  /// Requests a password-reset email. The backend intentionally returns a
  /// token only in the local development mail sink; production keeps the
  /// token inside the configured mail provider.
  Future<String?> requestPasswordReset(String email) async {
    return _configuredAccountApi().requestPasswordReset(email: email.trim());
  }

  Future<void> confirmPasswordReset({
    required String token,
    required String password,
  }) async {
    await _configuredAccountApi().confirmPasswordReset(
      token: token.trim(),
      password: password,
    );
  }

  Future<Map<String, dynamic>> exportAccountData() async {
    final current = _authSession;
    if (current == null) throw StateError('Chưa đăng nhập tài khoản');
    return _configuredAccountApi().exportAccount(
      accessToken: current.accessToken,
    );
  }

  Future<void> updateAccountDisplayName(String displayName) async {
    final current = _authSession;
    if (current == null) return;
    final user = await _configuredAccountApi().updateProfile(
      accessToken: current.accessToken,
      displayName: displayName,
    );
    final updated = AuthSession(
      accessToken: current.accessToken,
      refreshToken: current.refreshToken,
      accessExpiresAt: current.accessExpiresAt,
      refreshExpiresAt: current.refreshExpiresAt,
      user: user,
    );
    await _store.saveAuthSession(updated);
    _authSession = updated;
    notifyListeners();
  }

  Future<void> deleteAccount({required String password}) async {
    final current = _authSession;
    if (current == null) throw StateError('Chưa đăng nhập tài khoản');
    await _configuredAccountApi().deleteAccount(
      accessToken: current.accessToken,
      password: password,
    );
    await _store.clearAuthSession();
    await _store.setSyncCursor(0);
    await _store.setLastSyncedAt(null);
    _authSession = null;
    _syncError = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    final current = _authSession;
    if (current != null) {
      try {
        await _configuredAccountApi().logout(current.accessToken);
      } catch (_) {
        // Local sign-out must still work while offline.
      }
    }
    await _store.clearAuthSession();
    await _store.setSyncCursor(0);
    await _store.setLastSyncedAt(null);
    _authSession = null;
    _syncError = null;
    notifyListeners();
  }

  /// Rotates the refresh token only when the access token is close to expiry.
  /// A network failure is intentionally ignored during startup: guest/offline
  /// learning must remain available with the last local session.
  Future<void> _refreshAuthIfNeeded() async {
    final current = _authSession;
    if (current == null) return;
    final expiresAt = DateTime.tryParse(current.accessExpiresAt);
    if (expiresAt != null &&
        expiresAt.isAfter(
          DateTime.now().toUtc().add(const Duration(minutes: 1)),
        )) {
      return;
    }
    try {
      await refreshSession();
    } catch (_) {
      // The next explicit sync/login action reports a useful error instead.
    }
  }

  Future<AuthSession?> refreshSession() async {
    final current = _authSession;
    if (current == null) return null;
    final refreshed = await _configuredAccountApi().refresh(
      current.refreshToken,
    );
    // Sign-out may have completed while the network request was in flight.
    // Never resurrect that session after the learner explicitly left.
    if (_disposed || !identical(_authSession, current)) return null;
    await _store.saveAuthSession(refreshed);
    _authSession = refreshed;
    _syncError = null;
    notifyListeners();
    return refreshed;
  }

  /// Pushes durable local attempts and advances the server cursor. A failed
  /// sync leaves the outbox untouched so retry is safe and idempotent.
  Future<SyncSummary> syncNow() async {
    final current = _authSession;
    if (current == null) throw StateError('Chưa đăng nhập tài khoản');
    if (_syncing) return const SyncSummary(uploaded: 0, downloaded: 0);
    _syncing = true;
    _syncError = null;
    notifyListeners();
    try {
      final client = _configuredAccountApi();
      final pending = await _store.pendingOutboxEvents();
      final events = pending
          .map(
            (row) => <String, dynamic>{
              'event_id': row['event_id'],
              'event_type': row['event_type'],
              'occurred_at': row['created_at'],
              'payload': row['payload'] is Map
                  ? Map<String, dynamic>.from(row['payload'] as Map)
                  : <String, dynamic>{},
            },
          )
          .toList(growable: false);
      try {
        return await _syncOnce(
          client: client,
          accessToken: current.accessToken,
          events: events,
        );
      } catch (error) {
        if (!_isUnauthorized(error)) rethrow;
        final refreshed = await refreshSession();
        if (refreshed == null) rethrow;
        return _syncOnce(
          client: client,
          accessToken: refreshed.accessToken,
          events: events,
        );
      }
    } catch (error) {
      _syncError = _friendlySyncError(error);
      notifyListeners();
      rethrow;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<SyncSummary> _syncOnce({
    required AccountApiClient client,
    required String accessToken,
    required List<Map<String, dynamic>> events,
  }) async {
    final acknowledged = await client.pushEvents(
      accessToken: accessToken,
      events: events,
    );
    await _store.acknowledgeOutbox(acknowledged);
    var cursor = _store.syncCursor;
    var downloaded = 0;
    while (true) {
      final previousCursor = cursor;
      final page = await client.pullEvents(
        accessToken: accessToken,
        cursor: cursor,
      );
      downloaded += page.events.length;
      for (final event in page.events) {
        if (event['event_type'] == 'learning_attempt') {
          await _store.applyRemoteAttempt(event);
        }
      }
      if (page.cursor > cursor) {
        cursor = page.cursor;
        await _store.setSyncCursor(cursor);
      }
      if (!page.hasMore ||
          page.events.isEmpty ||
          page.cursor <= previousCursor) {
        break;
      }
    }
    final syncedAt = DateTime.now().toUtc();
    await _store.setLastSyncedAt(syncedAt);
    _lastSyncedAt = syncedAt;
    if (downloaded > 0) _attemptRevision++;
    notifyListeners();
    return SyncSummary(uploaded: acknowledged.length, downloaded: downloaded);
  }

  bool _isUnauthorized(Object error) =>
      error is HttpException && error.message.contains(' 401');

  Future<void> reportContent({
    required String wordId,
    required String reportType,
    required String note,
  }) async {
    final current = _authSession;
    if (current == null) {
      throw StateError('Đăng nhập để gửi báo lỗi nội dung.');
    }
    await _configuredAccountApi().reportContent(
      accessToken: current.accessToken,
      wordId: wordId,
      reportType: reportType,
      note: note,
    );
  }

  Future<List<Map<String, dynamic>>> adminReports({String? status}) async {
    final current = _authSession;
    if (current == null || current.user.role != 'admin') {
      throw StateError('Tài khoản không có quyền quản trị.');
    }
    return _configuredAccountApi().fetchAdminReports(
      accessToken: current.accessToken,
      status: status,
    );
  }

  Future<void> updateAdminReport({
    required String reportId,
    required String status,
  }) async {
    final current = _authSession;
    if (current == null || current.user.role != 'admin') {
      throw StateError('Tài khoản không có quyền quản trị.');
    }
    await _configuredAccountApi().updateAdminReport(
      accessToken: current.accessToken,
      reportId: reportId,
      status: status,
    );
  }

  Future<List<Map<String, dynamic>>> adminCatalogReleases() async {
    final current = _authSession;
    if (current == null || current.user.role != 'admin') {
      throw StateError('Tài khoản không có quyền quản trị.');
    }
    return _configuredAccountApi().fetchCatalogReleases(
      accessToken: current.accessToken,
    );
  }

  Future<Map<String, dynamic>> publishAdminCatalog(
    Map<String, dynamic> manifest,
  ) async {
    final current = _authSession;
    if (current == null || current.user.role != 'admin') {
      throw StateError('Tài khoản không có quyền quản trị.');
    }
    return _configuredAccountApi().publishCatalogRelease(
      accessToken: current.accessToken,
      manifest: manifest,
    );
  }

  Future<Map<String, dynamic>> rollbackAdminCatalog(String version) async {
    final current = _authSession;
    if (current == null || current.user.role != 'admin') {
      throw StateError('Tài khoản không có quyền quản trị.');
    }
    return _configuredAccountApi().rollbackCatalogRelease(
      accessToken: current.accessToken,
      version: version,
    );
  }

  Future<List<ReviewState>> dueReviewStates({DateTime? now}) =>
      _store.dueReviewStates(now: now);

  Future<List<Map<String, dynamic>>> recentAttempts({int limit = 20}) =>
      _store.recentAttempts(limit: limit);

  Future<void> saveLearningDraft(Map<String, dynamic> draft) async {
    await _store.saveLearningDraft(draft);
    _learningDraft = Map<String, dynamic>.from(draft);
    notifyListeners();
  }

  Future<void> clearLearningDraft() async {
    await _store.clearLearningDraft();
    _learningDraft = null;
    notifyListeners();
  }

  Future<void> setProfileName(String value) async {
    await _store.setProfileName(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setDailyGoal(int value) async {
    await _store.setDailyGoal(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> toggleFavorite(String apiLabel) async {
    final next = {..._favoriteWords};
    if (!next.add(apiLabel)) next.remove(apiLabel);
    await _store.setFavoriteWords(next);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setSoundFx(bool value) async {
    await _store.setSoundFx(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setNotifications(bool value) async {
    await _store.setNotifications(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setThemeColor(int value) async {
    await _store.setThemeColor(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setDirection(int value) async {
    await _store.setDirection(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setDifficulty(int value) async {
    await _store.setDifficulty(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setBgMusic(bool value) async {
    await _store.setBgMusic(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    await _store.setVolume(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setVibrate(bool value) async {
    await _store.setVibrate(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setDailyReminder(bool value) async {
    await _store.setDailyReminder(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    await _store.setDarkMode(value);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    await _store.setOnboardingComplete(true);
    _syncFromStore();
    notifyListeners();
  }

  Future<void> createCollection(String name) async {
    final cleaned = _collectionName(name);
    if (cleaned == null) return;
    final id = 'collection-${DateTime.now().microsecondsSinceEpoch}';
    final next = [
      ..._collections,
      VocabularyCollection(id: id, name: cleaned, wordIds: const []),
    ];
    await _store.saveCollections(next);
    _collections = next;
    notifyListeners();
  }

  Future<void> renameCollection(String id, String name) async {
    final cleaned = _collectionName(name);
    if (cleaned == null) return;
    final index = _collections.indexWhere((item) => item.id == id);
    if (index < 0) return;
    final next = [..._collections];
    next[index] = next[index].copyWith(name: cleaned);
    await _store.saveCollections(next);
    _collections = next;
    notifyListeners();
  }

  Future<void> deleteCollection(String id) async {
    final next = _collections.where((item) => item.id != id).toList();
    if (next.length == _collections.length) return;
    await _store.saveCollections(next);
    _collections = next;
    notifyListeners();
  }

  Future<void> toggleCollectionWord(String collectionId, String wordId) async {
    final index = _collections.indexWhere((item) => item.id == collectionId);
    if (index < 0 || wordId.trim().isEmpty) return;
    final collection = _collections[index];
    final words = {...collection.wordIds};
    if (!words.add(wordId)) words.remove(wordId);
    final next = [..._collections];
    next[index] = collection.copyWith(wordIds: words);
    await _store.saveCollections(next);
    _collections = next;
    notifyListeners();
  }

  static String? _collectionName(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return null;
    return cleaned.substring(0, cleaned.length.clamp(1, 40));
  }

  Future<void> resetProgress() async {
    await _store.resetProgress();
    _syncFromStore();
    _attemptRevision++;
    notifyListeners();
  }

  void _syncFromStore() {
    _profileName = _store.profileName;
    _dailyGoal = _store.dailyGoal;
    _points = _store.points;
    _streak = _store.streak;
    _sessions = _store.sessions;
    _todayWords = _store.todayWords;
    _learnedWords = _store.learnedWords;
    _favoriteWords = _store.favoriteWords;
    _soundFx = _store.soundFx;
    _notifications = _store.notifications;
    _themeColor = _store.themeColor;
    _direction = _store.direction;
    _difficulty = _store.difficulty;
    _bgMusic = _store.bgMusic;
    _volume = _store.volume;
    _vibrate = _store.vibrate;
    _dailyReminder = _store.dailyReminder;
    _darkMode = _store.darkMode;
    _onboardingComplete = _store.onboardingComplete;
    _collections = _store.collections;
    _learningDraft = _store.learningDraft;
    _authSession = _store.authSession;
    _lastSyncedAt = _store.lastSyncedAt;
  }

  AccountApiClient _configuredAccountApi() {
    final existing = _accountApi;
    if (existing != null) return existing;
    const baseUrl = String.fromEnvironment('VOCAB_API_BASE_URL');
    if (baseUrl.trim().isEmpty) {
      throw StateError(
        'Chưa cấu hình máy chủ tài khoản. Chạy với '
        '--dart-define=VOCAB_API_BASE_URL=http://…',
      );
    }
    return _accountApi = AccountApiClient(baseUrl.trim());
  }

  String _friendlySyncError(Object error) => error is StateError
      ? error.message.toString()
      : 'Không đồng bộ được lúc này. Dữ liệu offline vẫn an toàn, hãy thử lại.';

  /// Downloads the currently published catalog only after the API client has
  /// validated its pack list, manifest and complete word set. The SQLite
  /// release is replaced transactionally, so a failed request cannot discard
  /// the last usable offline catalog.
  Future<CatalogRelease> downloadPublishedCatalog() {
    final inFlight = _catalogDownloadInFlight;
    if (inFlight != null) return inFlight;

    final request = _downloadPublishedCatalog();
    _catalogDownloadInFlight = request;
    return request.whenComplete(() {
      if (identical(_catalogDownloadInFlight, request)) {
        _catalogDownloadInFlight = null;
      }
    });
  }

  void cancelCatalogDownload() {
    if (_catalogDownloadInFlight != null) {
      _catalogDownloadCancelRequested = true;
    }
  }

  void _setCatalogDownloadProgress(double? value) {
    final next = value?.clamp(0, 1).toDouble();
    final previous = _catalogDownloadProgress;
    _catalogDownloadProgress = next;
    // Media caching can report hundreds of tiny increments. Updating every
    // one rebuilds the whole vocabulary page for no visible benefit.
    final meaningfulChange =
        next == null ||
        previous == null ||
        next == 1.0 ||
        (previous - next).abs() >= 0.01;
    if (!_disposed && next != previous && meaningfulChange) {
      notifyListeners();
    }
  }

  Future<CatalogRelease> _downloadPublishedCatalog() async {
    _catalogDownloadCancelRequested = false;
    _setCatalogDownloadProgress(null);
    try {
      final configuredFetcher = _catalogReleaseFetcher;
      final release = configuredFetcher != null
          ? await configuredFetcher()
          : await _fetchPublishedCatalogFromApi();
      if (_catalogDownloadCancelRequested) {
        throw const CatalogDownloadCancelled();
      }
      if (release.words.isEmpty) {
        throw const FormatException('Máy chủ chưa có gói nội dung hợp lệ.');
      }
      final offlineRelease = await _catalogMediaCache.cacheRelease(
        version: release.version,
        words: release.words,
        isCancelled: () => _catalogDownloadCancelRequested,
        onProgress: (completed, total) {
          final fraction = total == 0 ? 1.0 : completed / total;
          _setCatalogDownloadProgress(fraction * 0.9);
        },
      );
      if (_catalogDownloadCancelRequested) {
        throw const CatalogDownloadCancelled();
      }
      _setCatalogDownloadProgress(0.95);
      await _persistCatalogRelease(
        version: release.version,
        words: offlineRelease,
      );
      _setCatalogDownloadProgress(1);
      return CatalogRelease(version: release.version, words: offlineRelease);
    } finally {
      _catalogDownloadCancelRequested = false;
      _setCatalogDownloadProgress(null);
    }
  }

  Future<CatalogRelease> _fetchPublishedCatalogFromApi() async {
    const baseUrl = String.fromEnvironment('VOCAB_API_BASE_URL');
    if (baseUrl.trim().isEmpty) {
      throw StateError(
        'Chưa cấu hình máy chủ nội dung. Gói offline hiện tại vẫn dùng được.',
      );
    }
    final api = _catalogApi ??= CatalogApiClient(baseUrl.trim());
    return api.fetchPackRelease();
  }

  /// Removes only the downloaded catalog release. Learner progress, review
  /// states, collections and attempts live in the separate app store and are
  /// intentionally preserved.
  Future<void> restoreStarterCatalog() async {
    await _persistCatalogRelease(
      version: starterCatalogReleaseVersion,
      words: catalogWords,
    );
  }

  Future<void> _persistCatalogRelease({
    required String version,
    required List<CatalogWord> words,
  }) async {
    await _withCatalogWriteLock(() async {
      await _catalogDatabase.replaceRelease(version: version, words: words);
      _catalog = words;
      _catalogReleaseVersion = version;
      if (!_disposed) notifyListeners();
    });
  }

  /// Serializes catalog swaps so a background hydration/download cannot
  /// interleave a delete-and-insert transaction with the restore action.
  Future<void> _withCatalogWriteLock(Future<void> Function() action) async {
    while (true) {
      final previous = _catalogWriteLock;
      if (previous != null) {
        await previous;
        continue;
      }
      final lock = Completer<void>();
      _catalogWriteLock = lock.future;
      try {
        await action();
      } finally {
        if (identical(_catalogWriteLock, lock.future)) {
          _catalogWriteLock = null;
        }
        lock.complete();
      }
      return;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _accountApi?.close();
    _catalogApi?.close();
    _catalogMediaCache.close();
    unawaited(_catalogDatabase.close());
    unawaited(_store.close());
    super.dispose();
  }

  Future<void> _hydrateCatalog() async {
    try {
      final stored = await _catalogDatabase.all();
      final storedVersion = await _catalogDatabase.releaseVersion;
      final shouldRefreshStarter =
          storedVersion != starterCatalogReleaseVersion &&
          (storedVersion == null || storedVersion.startsWith('starter-'));
      if (stored.isNotEmpty && !shouldRefreshStarter) {
        _catalog = stored
            .map((word) {
              final path = word.localImagePath?.trim();
              if (path != null && path.isNotEmpty && !File(path).existsSync()) {
                return word.withoutLocalImagePath();
              }
              return word;
            })
            .toList(growable: false);
        _catalogReleaseVersion = storedVersion ?? 'unknown';
        if (!_disposed) notifyListeners();
      } else {
        await _persistCatalogRelease(
          version: starterCatalogReleaseVersion,
          words: catalogWords,
        );
      }
    } catch (_) {
      // sqflite is unavailable on some desktop/widget targets; the immutable
      // starter remains a usable offline fallback.
    }
    const baseUrl = String.fromEnvironment('VOCAB_API_BASE_URL');
    if (baseUrl.trim().isEmpty) return;
    try {
      await downloadPublishedCatalog();
    } catch (_) {
      // Keep the last local release on network/API failure.
    }
  }
}

class SyncSummary {
  final int uploaded;
  final int downloaded;

  const SyncSummary({required this.uploaded, required this.downloaded});
}
