// Vocab Vision product bootstrap and legacy compatibility screens.
// ProductShell is the active app entrypoint; the legacy screens below remain
// available to avoid breaking existing demo routes while features migrate.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'app_config.dart';
import 'catalog_data.dart';
import 'core/state/app_state.dart';
import 'core/learning/vocabulary_collection.dart';
import 'core/learning/review_scheduler.dart';
import 'core/network/catalog_api_client.dart';
import 'core/storage/catalog_media_cache.dart';
import 'core/text/search_normalizer.dart';
import 'core/theme/app_theme.dart';
import 'inference_service.dart';
import 'learning_screen.dart';
import 'features/space_words/space_words_page.dart';
import 'mascot/may_mascot.dart';
import 'mascot/may_corner_overlay.dart';
import 'research_results_screen.dart';
import 'result_screen.dart';
import 'vocabulary_data.dart';

part 'app/product_shell.dart';
part 'features/recognition/camera_screen.dart';

void main() {
  // Initialise plugin channels before AppState opens SQLite/SharedPreferences
  // on a cold Android launch. Integration tests initialise their own binding,
  // but a real APK must do this before the first asynchronous store call.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VocabApp());
}

// ─── Design tokens ───────────────────────────────────────────────────────────
class C {
  static const navy = AppColors.ink; // text #FFFFFF
  static const mint = AppColors.blue; // #2A7BE4
  static const mintLight = AppColors.blueTint; // #1B3A5C
  static const mintPale = AppColors.surfaceAlt; // #223444
  static const mintDark = AppColors.blueEdge; // #1B57AE
  static const indigo = AppColors.blueAccentText; // #6FB3FF
  static const indigoMid = AppColors.cardBorder; // #2C3E4C
  static const indigoSoft = AppColors.surface; // #1B2A35
  static const coral = AppColors.coral; // #FF5A5F
  static const coralSoft = AppColors.surfaceAlt; // #223444
  static const amber = AppColors.gold; // #FFC83D
  static const amberSoft = AppColors.surfaceAlt; // #223444
  static const orange = AppColors.orange; // #FF9A3D
  static const orangeSoft = AppColors.surfaceAlt; // #223444
  static const lavender = AppColors.surfaceAlt; // #223444
  static const purple = AppColors.purple; // #8A57E8
  static const muted = AppColors.secondaryText; // #A9BAC6
}

TextStyle t(
  double size, {
  FontWeight w = FontWeight.w700,
  Color? color,
  double? h,
}) => TextStyle(fontSize: size, fontWeight: w, color: color, height: h);

// ─── App root ────────────────────────────────────────────────────────────────
class VocabApp extends StatefulWidget {
  const VocabApp({super.key});

  @override
  State<VocabApp> createState() => _VocabAppState();
}

class _VocabAppState extends State<VocabApp> with WidgetsBindingObserver {
  late final AppState appState;
  late final VoidCallback _rootStateListener;
  var _rootReady = false;
  var _rootOnboardingComplete = false;
  var _rootThemeColor = 0;
  var _rootDarkMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appState = AppState();
    _captureRootState();
    _rootStateListener = _handleRootStateChanged;
    appState.addListener(_rootStateListener);
    unawaited(appState.load());
  }

  void _captureRootState() {
    _rootReady = appState.ready;
    _rootOnboardingComplete = appState.onboardingComplete;
    _rootThemeColor = appState.themeColor;
    _rootDarkMode = appState.darkMode;
  }

  void _handleRootStateChanged() {
    final changed =
        _rootReady != appState.ready ||
        _rootOnboardingComplete != appState.onboardingComplete ||
        _rootThemeColor != appState.themeColor ||
        _rootDarkMode != appState.darkMode;
    if (!changed) return;
    _captureRootState();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    appState.removeListener(_rootStateListener);
    appState.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // SQLite writes are transactional and happen at the action boundary. If
    // Android reported a transient open/write failure while the app was in
    // the background, retry as soon as the process is foregrounded again.
    // This makes the recovery path useful without claiming that a killed
    // process can run code after it has been terminated.
    if (state == AppLifecycleState.resumed &&
        appState.persistenceError != null) {
      unawaited(appState.retryPersistence());
    }
  }

  @override
  Widget build(BuildContext c) {
    final seedColor = switch (_rootThemeColor) {
      1 => C.indigo,
      2 => C.coral,
      3 => C.amber,
      4 => C.lavender,
      _ => C.mint,
    };
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildVocabTheme(
        brightness: Brightness.light,
        seedColor: seedColor,
      ),
      darkTheme: buildVocabTheme(
        brightness: Brightness.dark,
        seedColor: seedColor,
      ),
      themeMode: _rootDarkMode ? ThemeMode.dark : ThemeMode.light,
      // Keep MaterialApp/Navigator and the product shell stable for routine
      // progress, draft and sync notifications. Individual pages subscribe
      // to AppState only where they need fresh data.
      home: Platform.isAndroid && !_rootReady
          ? const _BootScreen()
          : Platform.isAndroid && !_rootOnboardingComplete
          ? OnboardingScreen(appState: appState)
          : ProductShell(appState: appState),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vocabColors.canvas,
    body: Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: context.vocabColors.accentDark,
        ),
      ),
    ),
  );
}

/// First-run setup stays deliberately short: it establishes only the values
/// needed to personalize Home. Camera and notification permissions are asked
/// by the feature that needs them, never during onboarding.
class OnboardingScreen extends StatefulWidget {
  final AppState appState;

  const OnboardingScreen({super.key, required this.appState});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  final _nameController = TextEditingController();
  int _page = 0;
  int _goal = 10;
  bool _saving = false;

  @override
  void dispose() {
    _pages.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_saving) return;
    setState(() => _saving = true);
    final name = _nameController.text.trim();
    if (name.isNotEmpty) await widget.appState.setProfileName(name);
    await widget.appState.setDailyGoal(_goal);
    await widget.appState.completeOnboarding();
  }

  void _next() {
    if (_page == 2) {
      unawaited(_finish());
      return;
    }
    setState(() => _page++);
    unawaited(
      _pages.animateToPage(
        _page,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.vocabColors.canvas,
    body: SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _saving ? null : () => unawaited(_finish()),
              child: const Text('Bỏ qua'),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (value) => setState(() => _page = value),
              children: [
                const _OnboardingSlide(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Học vừa đủ, nhớ lâu hơn',
                  body:
                      'Vocab Vision chia bài học thành những phiên ngắn, có ôn lại đúng lúc và không làm rối màn hình bằng đồ trang trí.',
                ),
                _OnboardingProfileSlide(
                  controller: _nameController,
                  goal: _goal,
                  onGoalChanged: (value) => setState(() => _goal = value),
                ),
                const _OnboardingSlide(
                  icon: Icons.offline_bolt_outlined,
                  title: 'Nhận diện vẫn chạy offline',
                  body:
                      'E4 được đóng gói trên thiết bị. Bạn có thể học và nhận diện ảnh không cần Wi-Fi; mạng chỉ dùng cho nội dung mới và đồng bộ tùy chọn.',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var index = 0; index < 3; index++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == _page ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? context.vocabColors.accentDark
                              : context.vocabColors.accentSoft,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _next,
                    child: Text(_page == 2 ? 'Bắt đầu học' : 'Tiếp theo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _OnboardingSlide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            color: context.vocabColors.accentSoft,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Icon(icon, size: 52, color: context.vocabColors.accentDark),
        ),
        const SizedBox(height: 28),
        Text(
          title,
          textAlign: TextAlign.center,
          style: t(26, w: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: t(
            16,
            w: FontWeight.w500,
            color: context.vocabColors.textSecondary,
            h: 1.5,
          ),
        ),
      ],
    ),
  );
}

class _OnboardingProfileSlide extends StatelessWidget {
  final TextEditingController controller;
  final int goal;
  final ValueChanged<int> onGoalChanged;

  const _OnboardingProfileSlide({
    required this.controller,
    required this.goal,
    required this.onGoalChanged,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
    children: [
      Text('Thiết lập mục tiêu', style: t(26, w: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(
        'Chỉ mất vài giây. Bạn có thể đổi lại trong Cài đặt.',
        style: t(
          15,
          w: FontWeight.w500,
          color: context.vocabColors.textSecondary,
        ),
      ),
      const SizedBox(height: 28),
      TextField(
        controller: controller,
        textInputAction: TextInputAction.done,
        maxLength: 24,
        decoration: InputDecoration(
          labelText: 'Biệt danh (tùy chọn)',
          prefixIcon: Icon(Icons.person_outline),
          filled: true,
          fillColor: context.vocabColors.surface,
        ),
      ),
      const SizedBox(height: 20),
      Card(
        elevation: 0,
        color: context.vocabColors.surface,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$goal từ mỗi ngày', style: t(16, w: FontWeight.w800)),
              Slider(
                value: goal.toDouble(),
                min: 5,
                max: 15,
                divisions: 2,
                label: '$goal',
                onChanged: (value) => onGoalChanged(value.round()),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

// ─── Shell (tab state + overlays) ────────────────────────────────────────────
class Shell extends StatefulWidget {
  final AppState appState;

  const Shell({super.key, required this.appState});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int activeTab = 0;
  bool showMap = false;
  bool showSettings = false;

  bool get isCamera => activeTab == 2;
  bool get isProfile => activeTab == 4;
  bool get isHome => activeTab == 0;
  bool get isOverlay => showMap || showSettings;

  Widget _screen() {
    switch (activeTab) {
      case 0:
        return HomeScreen(
          onOpenMap: () => setState(() => showMap = true),
          onOpenVocabulary: () => setState(() => activeTab = 1),
          onOpenAchievements: () => setState(() => activeTab = 3),
          onOpenMode: (mode) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LearningScreen(
                mode: mode,
                direction: widget.appState.direction,
                difficulty: widget.appState.difficulty,
                loadDraft: () =>
                    widget.appState.learningDraft ??
                    widget.appState.store.learningDraft,
                saveDraft: widget.appState.saveLearningDraft,
                clearDraft: widget.appState.clearLearningDraft,
                onAttempt: (wordId, correct, assisted) =>
                    widget.appState.recordAttempt(
                      wordId: wordId,
                      correct: correct,
                      assisted: assisted,
                    ),
                onCompleted: (summary) => unawaited(
                  widget.appState.recordSession(
                    correct: summary.correct,
                    total: summary.total,
                    wordLabels: summary.wordLabels,
                  ),
                ),
              ),
            ),
          ),
          appState: widget.appState,
        );
      case 1:
        return VocabularyScreen(appState: widget.appState);
      case 2:
        return const CameraScreen();
      case 3:
        return AchievementsScreen(appState: widget.appState);
      case 4:
        return ProfileScreen(
          appState: widget.appState,
          onOpenSettings: () => setState(() => showSettings = true),
        );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isPhone = constraints.maxWidth < 600;
          final frameWidth = math.min(480.0, constraints.maxWidth);
          return Center(
            child: SizedBox(
              width: frameWidth,
              height: constraints.maxHeight,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: isPhone
                      ? BorderRadius.zero
                      : BorderRadius.circular(32),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [C.mint, C.mintLight, C.mintPale],
                    stops: [0.0, 0.55, 1.0],
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2A000000),
                      offset: Offset(0, 32),
                      blurRadius: 80,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            if (!isCamera)
                              const Positioned.fill(child: _BgDecor()),
                            if (!isCamera && !isOverlay)
                              Padding(
                                padding: EdgeInsets.only(
                                  top: isProfile ? 0 : 84,
                                ),
                                child: _screen(),
                              ),
                            if (isCamera) const CameraScreen(),
                            if (showMap)
                              LearningMapScreen(
                                appState: widget.appState,
                                onClose: () => setState(() => showMap = false),
                                onOpenMode: (mode) {
                                  setState(() => showMap = false);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => LearningScreen(
                                        mode: mode,
                                        direction: widget.appState.direction,
                                        difficulty: widget.appState.difficulty,
                                        loadDraft: () =>
                                            widget.appState.learningDraft ??
                                            widget.appState.store.learningDraft,
                                        saveDraft:
                                            widget.appState.saveLearningDraft,
                                        clearDraft:
                                            widget.appState.clearLearningDraft,
                                        onAttempt:
                                            (wordId, correct, assisted) =>
                                                widget.appState.recordAttempt(
                                                  wordId: wordId,
                                                  correct: correct,
                                                  assisted: assisted,
                                                ),
                                        onCompleted: (summary) => unawaited(
                                          widget.appState.recordSession(
                                            correct: summary.correct,
                                            total: summary.total,
                                            wordLabels: summary.wordLabels,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            if (showSettings)
                              SettingsScreen(
                                appState: widget.appState,
                                onClose: () =>
                                    setState(() => showSettings = false),
                              ),
                            if (!isCamera && !isProfile && !isOverlay)
                              Positioned(
                                top: 12,
                                left: 20,
                                right: 20,
                                child: _header(),
                              ),
                          ],
                        ),
                      ),
                      if (!isOverlay)
                        BottomCutoutNav(
                          activeTab: activeTab,
                          onTabChange: (i) => setState(() => activeTab = i),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x14000000),
          offset: Offset(0, 4),
          blurRadius: 20,
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [C.orange, C.coral]),
            boxShadow: [
              BoxShadow(
                color: Color(0x4DFF6B6B),
                offset: Offset(0, 4),
                blurRadius: 12,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.appState.profileName.isEmpty
                ? 'B'
                : widget.appState.profileName.substring(0, 1).toUpperCase(),
            style: t(20, w: FontWeight.w900, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.appState.profileName,
                style: t(18, w: FontWeight.w800),
              ),
              Text(
                '${widget.appState.streak} ngày liên tiếp',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(12, w: FontWeight.w600, color: C.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [C.mint, C.mintLight]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x59A0FFDD),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⭐', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                '${widget.appState.points}',
                style: t(15, w: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─── Home screen ─────────────────────────────────────────────────────────────
class HomeScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenVocabulary;
  final VoidCallback onOpenAchievements;
  final ValueChanged<LearningMode> onOpenMode;

  const HomeScreen({
    super.key,
    required this.appState,
    required this.onOpenMap,
    required this.onOpenVocabulary,
    required this.onOpenAchievements,
    required this.onOpenMode,
  });

  static const _features = [
    ('📖', 'Từ vựng', C.amberSoft),
    ('🎮', 'Ôn tập', C.indigoSoft),
    ('🏆', 'Thành tích', C.coralSoft),
  ];

  @override
  Widget build(BuildContext c) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Row(
          children: _features.map((f) {
            final onTap = switch (f.$2) {
              'Từ vựng' => onOpenVocabulary,
              'Ôn tập' => onOpenMap,
              _ => onOpenAchievements,
            };
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: f == _features.last ? 0 : 10),
                child: GestureDetector(
                  onTap: onTap,
                  behavior: HitTestBehavior.opaque,
                  child: _glassPill(f.$1, f.$2, f.$3),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        _progressCard(),
        const SizedBox(height: 14),
        _wordsCard(),
        const SizedBox(height: 18),
        Text('Chọn chế độ học 🎯', style: t(16, w: FontWeight.w800)),
        const SizedBox(height: 12),
        _modesGrid(),
      ],
    );
  }

  // 4 ô trò chơi (chế độ học)
  static const _modes = [
    (
      '🃏',
      'Flashcard',
      'lật thẻ',
      [AppColors.purple, AppColors.purpleEdge],
      LearningMode.flashcard,
    ),
    (
      '🧩',
      'Ghép hình',
      'chọn cặp',
      [AppColors.green, AppColors.greenEdge],
      LearningMode.matching,
    ),
    (
      '✏️',
      'Điền từ',
      'nhập đáp án',
      [AppColors.coral, AppColors.coralEdge],
      LearningMode.fillWord,
    ),
    (
      '🎧',
      'Nghe & chọn',
      'nghe phát âm',
      [AppColors.orange, AppColors.orangeEdge],
      LearningMode.listening,
    ),
  ];

  Widget _modesGrid() => Column(
    children: [
      for (int i = 0; i < _modes.length; i += 2)
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < _modes.length ? 12 : 0),
          child: Row(
            children: [
              Expanded(child: _modeCard(_modes[i])),
              const SizedBox(width: 12),
              Expanded(child: _modeCard(_modes[i + 1])),
            ],
          ),
        ),
    ],
  );

  Widget _modeCard((String, String, String, List<Color>, LearningMode) m) =>
      GestureDetector(
        onTap: () => onOpenMode(m.$5),
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 190,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: m.$4,
            ),
            boxShadow: [
              BoxShadow(
                color: m.$4.last.withValues(alpha: 0.28),
                offset: const Offset(0, 5),
                blurRadius: 14,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.$1, style: const TextStyle(fontSize: 20)),
                  ),
                  const Text('⭐', style: TextStyle(fontSize: 16)),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    m.$2,
                    maxLines: 1,
                    style: t(16, w: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
              Text(
                m.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t(
                  11,
                  w: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Bắt đầu học',
                  maxLines: 1,
                  style: t(10.5, w: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _glassPill(String icon, String label, Color bg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(icon, style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t(11.5, w: FontWeight.w800),
          ),
        ),
      ],
    ),
  );

  Widget _progressCard() {
    final goal = appState.dailyGoal;
    final completed = appState.todayWords.clamp(0, goal);
    final ratio = goal == 0 ? 0.0 : completed / goal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.blueEdge, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.blueEdge,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Tiến độ hôm nay',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t(14, w: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$completed/$goal từ',
                style: t(
                  13,
                  w: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 10,
              color: AppColors.surfaceAlt,
              child: FractionallySizedBox(
                widthFactor: ratio,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: const BoxDecoration(color: AppColors.gold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wordsCard() {
    final words = vocabularyWords
        .where((word) => !appState.learnedWords.contains(word.apiLabel))
        .take(3)
        .toList();
    if (words.length < 3) {
      words.addAll(
        vocabularyWords
            .where((word) => !words.contains(word))
            .take(3 - words.length),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardEdge,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ôn hôm nay 📝', style: t(15, w: FontWeight.w800)),
          const SizedBox(height: 10),
          Row(
            children: words
                .map(
                  (w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(w.emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(height: 4),
                            Text(
                              w.vietnamese,
                              style: t(13, w: FontWeight.w800),
                            ),
                            Text(
                              w.english,
                              style: t(10, w: FontWeight.w600, color: C.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Vocabulary ──────────────────────────────────────────────────────────────
class VocabularyScreen extends StatefulWidget {
  final AppState appState;

  const VocabularyScreen({super.key, required this.appState});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _onlyFavorites = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (mounted) setState(() => _query = _searchController.text.trim());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<VocabularyWord> _filteredWords() {
    final query = _query.toLowerCase();
    return vocabularyWords.where((word) {
      final matchesQuery =
          query.isEmpty ||
          word.english.toLowerCase().contains(query) ||
          word.vietnamese.toLowerCase().contains(query);
      final matchesFavorite =
          !_onlyFavorites ||
          widget.appState.favoriteWords.contains(word.apiLabel);
      return matchesQuery && matchesFavorite;
    }).toList();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.appState,
    builder: (context, _) {
      final words = _filteredWords();
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Từ vựng', style: t(22, w: FontWeight.w900)),
                    Text(
                      '${vocabularyWords.length} đồ dùng học tập',
                      style: t(13, w: FontWeight.w600, color: C.muted),
                    ),
                    Text(
                      '${widget.appState.learnedWords.length} từ đã học',
                      style: t(12, w: FontWeight.w600, color: C.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: _onlyFavorites ? 'Hiện tất cả' : 'Chỉ hiện yêu thích',
                onPressed: () =>
                    setState(() => _onlyFavorites = !_onlyFavorites),
                icon: Icon(
                  _onlyFavorites
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: C.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm theo tiếng Anh hoặc tiếng Việt',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.clear_rounded),
                    ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.84),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (words.isEmpty)
            _emptyVocabulary()
          else
            for (final word in words) _wordTile(context, word),
        ],
      );
    },
  );

  Widget _emptyVocabulary() => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.8),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      children: [
        const Text('🔎', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),
        Text(
          _onlyFavorites ? 'Chưa có từ yêu thích' : 'Không tìm thấy từ phù hợp',
          textAlign: TextAlign.center,
          style: t(15, w: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          _onlyFavorites
              ? 'Nhấn ngôi sao trên một thẻ từ để lưu lại.'
              : 'Thử một từ khóa khác nhé.',
          textAlign: TextAlign.center,
          style: t(12, w: FontWeight.w600, color: C.muted),
        ),
      ],
    ),
  );

  Widget _wordTile(BuildContext context, VocabularyWord word) {
    final favorite = widget.appState.favoriteWords.contains(word.apiLabel);
    final learned = widget.appState.learnedWords.contains(word.apiLabel);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showWordDetails(context, word),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(word.emoji, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            word.english,
                            style: t(15, w: FontWeight.w800),
                          ),
                        ),
                        if (learned) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 16,
                            color: AppColors.green,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      word.vietnamese,
                      style: t(12, w: FontWeight.w600, color: C.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favorite ? 'Bỏ yêu thích' : 'Lưu yêu thích',
                onPressed: () =>
                    unawaited(widget.appState.toggleFavorite(word.apiLabel)),
                icon: Icon(
                  favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite ? C.amber : C.muted,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: C.muted),
            ],
          ),
        ),
      ),
    );
  }

  void _showWordDetails(BuildContext context, VocabularyWord word) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(word.emoji, style: const TextStyle(fontSize: 56)),
              const SizedBox(height: 8),
              Text(word.english, style: t(24, w: FontWeight.w900)),
              Text(
                word.vietnamese,
                style: t(16, w: FontWeight.w700, color: C.muted),
              ),
              const SizedBox(height: 18),
              Text(
                'Mã lớp E4: ${word.apiLabel}',
                style: t(12, w: FontWeight.w600, color: C.muted),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Đóng'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Profile screen ──────────────────────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback? onOpenSettings;
  const ProfileScreen({super.key, required this.appState, this.onOpenSettings});
  static const _ach = [
    (
      '🌟',
      'Học liên tiếp 5 ngày',
      'Không nghỉ ngày nào!',
      C.amber,
      C.amberSoft,
    ),
    ('🐣', 'Từ vựng đầu tiên', 'Học được 10 từ mới', C.mint, C.mintPale),
    (
      '🚀',
      'Màn học đầu tiên',
      'Hoàn thành một phiên học',
      C.indigo,
      C.indigoSoft,
    ),
    ('💯', 'Điểm chăm chỉ', 'Tích lũy 100 điểm', C.coral, C.coralSoft),
    ('📚', 'Mọt sách nhí', 'Học đủ 15 từ vựng', C.mint, C.mintPale),
    ('🦉', 'Cú đêm chăm chỉ', 'Học bài sau 22:00', C.purple, C.indigoSoft),
    ('🎯', 'Bậc thầy điểm số', 'Tích lũy 500 điểm', C.orange, C.orangeSoft),
    ('👑', 'Nhà vô địch tuần', 'Giữ streak 30 ngày', C.amber, C.amberSoft),
  ];
  @override
  Widget build(BuildContext ctx) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 56, 16, 120),
    children: [
      Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onTap: onOpenSettings,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cardBorder, width: 1.5),
            ),
            child: const Icon(Icons.settings, size: 20, color: AppColors.text),
          ),
        ),
      ),
      const SizedBox(height: 8),
      // avatar
      Center(
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [C.mint, C.orange]),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x6666FFCC),
                    offset: Offset(0, 6),
                    blurRadius: 28,
                  ),
                ],
              ),
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [C.orange, C.coral]),
                ),
                alignment: Alignment.center,
                child: Text(
                  appState.profileName.isEmpty
                      ? 'B'
                      : appState.profileName.substring(0, 1).toUpperCase(),
                  style: t(40, w: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(appState.profileName, style: t(22, w: FontWeight.w900)),
            Text(
              'Người học chăm chỉ 🌟',
              style: t(13, w: FontWeight.w600, color: C.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      // stats
      Row(
        children:
            [
                  (
                    '🔥',
                    '${appState.streak}',
                    'Ngày streak',
                    C.orange,
                    C.orangeSoft,
                  ),
                  (
                    '🏆',
                    '${appState.achievementCount}',
                    'Thành tích',
                    C.indigo,
                    C.indigoSoft,
                  ),
                  (
                    '📚',
                    '${appState.sessions}',
                    'Màn đã học',
                    C.mint,
                    C.mintPale,
                  ),
                ]
                .map(
                  (s) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.cardBorder,
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.cardEdge,
                              offset: Offset(0, 4),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: s.$5,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                s.$1,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(s.$2, style: t(22, w: FontWeight.w900)),
                            Text(
                              s.$3,
                              style: t(11, w: FontWeight.w700, color: C.muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 20),
      Text('Thành tích gần đây 🏅', style: t(15, w: FontWeight.w800)),
      const SizedBox(height: 12),
      ..._ach.indexed
          .where((entry) => _profileAchievementUnlocked(entry.$1))
          .map((entry) => entry.$2)
          .map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.cardEdge,
                      offset: Offset(0, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: a.$5,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: Text(a.$1, style: const TextStyle(fontSize: 22)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.$2, style: t(13, w: FontWeight.w800)),
                          Text(
                            a.$3,
                            style: t(11, w: FontWeight.w600, color: C.muted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: a.$4, size: 20),
                  ],
                ),
              ),
            ),
          ),
    ],
  );

  bool _profileAchievementUnlocked(int index) =>
      appState.isAchievementUnlocked(index);
}

// ─── Bottom Nav (cutout notch) ───────────────────────────────────────────────
class BottomCutoutNav extends StatelessWidget {
  final int activeTab;
  final ValueChanged<int> onTabChange;
  const BottomCutoutNav({
    super.key,
    required this.activeTab,
    required this.onTabChange,
  });

  static const _labels = [
    'Trang chủ',
    'Từ vựng',
    'Camera',
    'Thành tích',
    'Hồ sơ',
  ];
  static const _icons = [
    Icons.home_rounded,
    Icons.menu_book_rounded,
    Icons.camera_alt_rounded,
    Icons.emoji_events_rounded,
    Icons.person_rounded,
  ];

  @override
  Widget build(BuildContext c) {
    const barH = 68.0;
    return SizedBox(
      height: barH + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // bar with notch
          Positioned.fill(child: CustomPaint(painter: _NavBarPainter())),
          // labels + icons
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            bottom: 0,
            child: Row(
              children: List.generate(5, (i) {
                final active = i == activeTab;
                final isCam = i == 2;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTabChange(i),
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isCam)
                          Icon(
                            _icons[i],
                            size: 22,
                            color: active
                                ? C.navy
                                : C.navy.withValues(alpha: 0.42),
                          ),
                        if (!isCam) const SizedBox(height: 3),
                        Text(
                          _labels[i],
                          style: t(
                            active ? 11 : 10,
                            w: active ? FontWeight.w800 : FontWeight.w700,
                            color: isCam
                                ? C.navy
                                : (active
                                      ? C.navy
                                      : C.navy.withValues(alpha: 0.55)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // camera bubble centered against the actual responsive width
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [C.mint, C.mintLight]),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.72),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x8C66FFCC),
                    offset: Offset(0, 6),
                    blurRadius: 22,
                  ),
                  BoxShadow(
                    color: Color(0x1A000000),
                    offset: Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: GestureDetector(
                onTap: () => onTabChange(2),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: C.navy,
                  size: 30,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final notchCx = s.width / 2;
    const depth = 38.0, spread = 44.0;
    final barTop = s.height - 68;
    final path = Path()
      ..moveTo(0, barTop)
      ..lineTo(notchCx - spread, barTop)
      ..cubicTo(
        notchCx - spread + 18,
        barTop,
        notchCx - 16,
        barTop + depth,
        notchCx,
        barTop + depth,
      )
      ..cubicTo(
        notchCx + 16,
        barTop + depth,
        notchCx + spread - 18,
        barTop,
        notchCx + spread,
        barTop,
      )
      ..lineTo(s.width, barTop)
      ..lineTo(s.width, s.height)
      ..lineTo(0, s.height)
      ..close();
    // fill
    c.drawPath(path, Paint()..color = AppColors.bar);
    // top border line
    c.drawPath(
      path,
      Paint()
        ..color = AppColors.cardBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Learning Map (3D isometric) ─────────────────────────────────────────────
class LMNode {
  final int id;
  final String theme, emoji, state;
  final double x, y;
  final Color g1, g2, s1, s2;
  const LMNode(
    this.id,
    this.theme,
    this.emoji,
    this.state,
    this.x,
    this.y,
    this.g1,
    this.g2,
    this.s1,
    this.s2,
  );
}

const List<LMNode> _nodes = [
  LMNode(
    1,
    'Làm quen',
    '👋',
    'done',
    248,
    1730,
    Color(0xFFFF9550),
    Color(0xFFFFBE38),
    Color(0xFFC85500),
    Color(0xFFC8800A),
  ),
  LMNode(
    2,
    'Bàn học',
    '✏️',
    'done',
    110,
    1510,
    Color(0xFFFF6B6B),
    Color(0xFFFF9550),
    Color(0xFFC83030),
    Color(0xFFC85500),
  ),
  LMNode(
    3,
    'Sách và vở',
    '📚',
    'done',
    262,
    1300,
    Color(0xFF6C63FF),
    Color(0xFF9C8FFF),
    Color(0xFF3A34C0),
    Color(0xFF5A54D0),
  ),
  LMNode(
    4,
    '15 đồ dùng học tập',
    '🎒',
    'active',
    110,
    1070,
    Color(0xFF66FFCC),
    Color(0xFF00E5AA),
    Color(0xFF00A070),
    Color(0xFF00C090),
  ),
  LMNode(
    5,
    'Luyện nghe',
    '🎧',
    'locked',
    262,
    840,
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
    Color(0xFF708090),
    Color(0xFF808898),
  ),
  LMNode(
    6,
    'Ghép từ',
    '🧩',
    'locked',
    110,
    605,
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
    Color(0xFF708090),
    Color(0xFF808898),
  ),
  LMNode(
    7,
    'Nhận diện bằng ảnh',
    '📷',
    'locked',
    262,
    400,
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
    Color(0xFF708090),
    Color(0xFF808898),
  ),
  LMNode(
    8,
    'Kiểm tra cuối',
    '🏆',
    'locked',
    188,
    205,
    Color(0xFFB0BEC5),
    Color(0xFF90A4AE),
    Color(0xFF708090),
    Color(0xFF808898),
  ),
];

class LearningMapScreen extends StatelessWidget {
  final AppState appState;
  final VoidCallback onClose;
  final ValueChanged<LearningMode>? onOpenMode;

  const LearningMapScreen({
    super.key,
    required this.appState,
    required this.onClose,
    this.onOpenMode,
  });

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.background,
    child: Column(
      children: [
        Container(
          height: 70,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: AppColors.bar,
            border: Border(
              bottom: BorderSide(color: AppColors.cardBorder, width: 2),
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    size: 22,
                    color: AppColors.text,
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Lộ trình học',
                    style: t(18, w: FontWeight.w900, color: AppColors.text),
                  ),
                ),
              ),
              _pill(
                '⭐',
                '${appState.points}',
                AppColors.surfaceAlt,
                AppColors.gold,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _progressSummary(),
              const SizedBox(height: 18),
              Text('Các chặng học', style: t(16, w: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                'Hoàn thành từng chặng để mở khóa bài tiếp theo.',
                style: t(12, w: FontWeight.w600, color: C.muted),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _nodes.length; i++) ...[
                _lessonTile(context, _nodes[i]),
                if (i < _nodes.length - 1)
                  Container(
                    width: 3,
                    height: 12,
                    margin: const EdgeInsets.only(left: 31),
                    color:
                        _nodes[i].id <=
                            math.min(_nodes.length, appState.sessions)
                        ? AppColors.blue
                        : AppColors.locked,
                  ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _progressSummary() {
    final completed = math.min(_nodes.length, appState.sessions);
    final ratio = completed / _nodes.length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blue,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.blueEdge, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.blueEdge,
            offset: Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Bạn đã hoàn thành $completed/${_nodes.length} chặng',
                  style: t(14, w: FontWeight.w800, color: Colors.white),
                ),
              ),
              Text(
                '${(ratio * 100).round()}%',
                style: t(14, w: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: AppColors.surfaceAlt,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Chặng tiếp theo: 15 đồ dùng học tập',
            style: t(12, w: FontWeight.w600, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _lessonTile(BuildContext context, LMNode node) {
    final completed = math.min(_nodes.length, appState.sessions);
    final done = node.id <= completed;
    final active = node.id == completed + 1;
    final locked = !done && !active;
    final color = active
        ? AppColors.blue
        : (done ? AppColors.green : AppColors.locked);
    final practicedToday = math.min(appState.todayWords, appState.dailyGoal);
    final subtitle = done
        ? 'Đã hoàn thành'
        : active
        ? 'Đang học • $practicedToday/${appState.dailyGoal} từ hôm nay'
        : 'Hoàn thành chặng trước để mở khóa';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: active ? () => onOpenMode?.call(LearningMode.flashcard) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: active ? AppColors.blueTint : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.blue : AppColors.cardBorder,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardEdge,
                offset: Offset(0, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: done || active ? 0.18 : 0.12),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  locked ? '🔒' : node.emoji,
                  style: const TextStyle(fontSize: 23),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chặng ${node.id} • ${node.theme}',
                      style: t(14, w: FontWeight.w800),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: t(11.5, w: FontWeight.w600, color: C.muted),
                    ),
                  ],
                ),
              ),
              if (done)
                const Icon(Icons.check_circle_rounded, color: AppColors.green)
              else if (active)
                const Icon(Icons.arrow_forward_rounded, color: C.indigo),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(String e, String v, Color bg, Color col) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(e, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          v,
          style: t(13, w: FontWeight.w800, color: col),
        ),
      ],
    ),
  );
  // ignore: unused_element
  Widget _resPill(String e, String v, Color bg) => Container(
    width: 68,
    height: 30,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(15),
      boxShadow: [
        BoxShadow(
          color: bg.withValues(alpha: 0.4),
          offset: const Offset(0, 3),
          blurRadius: 10,
        ),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(e, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Text(
          v,
          style: t(12, w: FontWeight.w700, color: Colors.white),
        ),
      ],
    ),
  );

  // ignore: unused_element
  Widget _activeCard(LMNode n) => Container(
    width: 224,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.97),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x2E000000),
          offset: Offset(0, 10),
          blurRadius: 36,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${n.emoji} ${n.theme}', style: t(14, w: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(
          '12 từ vựng · ⭐ +50 điểm',
          style: t(11, w: FontWeight.w600, color: C.muted),
        ),
        const SizedBox(height: 12),
        Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(colors: [C.coral, C.orange]),
            boxShadow: const [
              BoxShadow(
                color: Color(0x80FF6B6B),
                offset: Offset(0, 5),
                blurRadius: 16,
              ),
            ],
          ),
          child: Text(
            'BẮT ĐẦU HỌC! →',
            style: t(13, w: FontWeight.w900, color: Colors.white),
          ),
        ),
      ],
    ),
  );

  // ignore: unused_element
  List<Widget> _rewards() {
    const rewards = [
      ('⭐', 190, 1620, -15.0),
      ('💎', 192, 1405, 12.0),
      ('🎁', 193, 1185, -8.0),
      ('⭐', 188, 955, 20.0),
      ('💎', 188, 718, -10.0),
      ('🎁', 186, 502, 15.0),
      ('⭐', 220, 298, -12.0),
    ];
    return rewards
        .map(
          (r) => Positioned(
            left: r.$2 - 13,
            top: r.$3 - 13,
            child: Transform.rotate(
              angle: r.$4 * math.pi / 180,
              child: Text(r.$1, style: const TextStyle(fontSize: 22)),
            ),
          ),
        )
        .toList();
  }
}

// ignore: unused_element
class _ZLabel extends StatelessWidget {
  final String label;
  final Color color;
  const _ZLabel(this.label, this.color);
  @override
  Widget build(BuildContext c) => Text(
    label,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      color: color,
      shadows: const [
        Shadow(color: Color(0x4D000000), offset: Offset(0, 1), blurRadius: 3),
      ],
    ),
  );
}

// ─── Hex node widget with 3D pillar ──────────────────────────────────────────
// ignore: unused_element
class _HexNodeWidget extends StatelessWidget {
  final LMNode node;
  final double pulse;
  const _HexNodeWidget({required this.node, required this.pulse});
  @override
  Widget build(BuildContext c) {
    final isActive = node.state == 'active';
    final isDone = node.state == 'done';
    final isLocked = node.state == 'locked';
    return SizedBox(
      width: 90,
      height: 110,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // pulse rings
          if (isActive) ...[
            Positioned(
              top: -6,
              left: -6,
              child: Opacity(
                opacity: 1 - (pulse * 0.5),
                child: Transform.scale(
                  scale: 1 + pulse * 0.15,
                  child: Container(
                    width: 102,
                    height: 102,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: C.mint.withValues(alpha: 0.65),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -14,
              left: -14,
              child: Opacity(
                opacity: 1 - (((pulse + 0.14) % 1) * 0.5),
                child: Container(
                  width: 118,
                  height: 118,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: C.mint.withValues(alpha: 0.42),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
            // bounce arrow
            Positioned(
              top: -34 + math.sin(pulse * math.pi * 2) * 5,
              left: 30,
              child: const Text('👆', style: TextStyle(fontSize: 18)),
            ),
          ],
          // hex pillar
          Positioned.fill(child: CustomPaint(painter: _HexPainter(node))),
          // emoji
          Positioned(
            top: 22,
            left: 0,
            right: 12,
            child: Text(
              isLocked ? '🔒' : node.emoji,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24),
            ),
          ),
          // gold star badge for done
          if (isDone)
            Positioned(
              top: -2,
              right: 6,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE44D), Color(0xFFFF9800)],
                  ),
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x99FF9600),
                      offset: Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('⭐', style: TextStyle(fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  final LMNode node;
  _HexPainter(this.node);
  static const double r = 32, isoSx = 12, isoSy = 20;

  List<Offset> _hex(
    double cx,
    double cy,
    double R, {
    double ox = 0,
    double oy = 0,
  }) => List.generate(6, (i) {
    final a = math.pi / 3 * i - math.pi / 2;
    return Offset(cx + ox + R * math.cos(a), cy + oy + R * math.sin(a));
  });

  Path _poly(List<Offset> v) {
    final p = Path()..moveTo(v[0].dx, v[0].dy);
    for (var i = 1; i < v.length; i++) {
      p.lineTo(v[i].dx, v[i].dy);
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2 - 6, cy = s.height / 2 - 5;
    final top = _hex(cx, cy, r);
    final bot = _hex(cx, cy, r, ox: isoSx, oy: isoSy);
    final isLocked = node.state == 'locked';

    // drop shadow
    c.drawPath(
      _poly(bot.map((p) => Offset(p.dx + 2, p.dy + 4)).toList()),
      Paint()
        ..color = Colors.black26
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Side faces — for pairs (1,2)(2,3)(3,4)(4,5)
    final sideColor = isLocked ? const Color(0xFF708090) : node.s1;
    final sideColor2 = isLocked ? const Color(0xFF808898) : node.s2;
    final faceIdx = [
      [1, 2, 0.65],
      [2, 3, 0.50],
      [3, 4, 0.40],
      [4, 5, 0.55],
    ];
    for (final f in faceIdx) {
      final i = f[0] as int, j = f[1] as int;
      final quad = [top[i], top[j], bot[j], bot[i]];
      final col = Color.lerp(sideColor, sideColor2, (f[2] as double))!;
      c.drawPath(_poly(quad), Paint()..color = col);
    }

    // Top face
    final topPaint = Paint()
      ..shader = LinearGradient(
        colors: isLocked
            ? const [Color(0xFFB0BEC5), Color(0xFF90A4AE)]
            : [node.g1, node.g2],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
    c.drawPath(_poly(top), topPaint);

    // Top face border
    c.drawPath(
      _poly(top),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = node.state == 'active'
            ? Colors.white.withValues(alpha: 0.95)
            : (isLocked
                  ? Colors.white24
                  : Colors.white.withValues(alpha: 0.75)),
    );

    // Shine overlay
    if (!isLocked) {
      c.drawPath(
        _poly(top),
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x73FFFFFF), Color(0x0DFFFFFF), Color(0x1A000000)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)),
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Main map background painter (zones + iso tiles + path + cliffs) ────────
// ignore: unused_element
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    _drawZone(c, 0, 500, const [
      Color(0xFF4A8FD4),
      Color(0xFF6EB4E8),
      Color(0xFFA8D8F0),
      Color(0xFFC8EAF8),
    ]);
    _drawZone(c, 500, 700, const [
      Color(0xFF52B840),
      Color(0xFF44A032),
      Color(0xFF35882A),
    ]);
    _drawZone(c, 1200, 400, const [
      Color(0xFF0090C0),
      Color(0xFF0070A0),
      Color(0xFF004E80),
    ]);
    _drawZone(c, 1600, 400, const [
      Color(0xFF6B4018),
      Color(0xFF4E2C10),
      Color(0xFF2A1408),
    ]);

    _isoTiles(c, 0, 500, const Color(0xFF7EC8F0), const Color(0xFF6BB8E4));
    _isoTiles(c, 500, 1200, const Color(0xFF4CAE38), const Color(0xFF56C040));
    _isoTiles(c, 1200, 1600, const Color(0xFF0080B0), const Color(0xFF0070A0));
    _isoTiles(c, 1600, 2000, const Color(0xFF5A3A12), const Color(0xFF4A2C0A));

    _cliff(
      c,
      500,
      const Color(0xFF2A6018),
      const Color(0xFF3A8028),
      const Color(0xFF52A840),
    );
    _cliff(
      c,
      1200,
      const Color(0xFF004470),
      const Color(0xFF006090),
      const Color(0xFF0090C0),
    );
    _cliff(
      c,
      1600,
      const Color(0xFF3E2010),
      const Color(0xFF6B4018),
      const Color(0xFF8B5A2A),
    );

    _drawPath(c);
  }

  void _drawZone(Canvas c, double y, double h, List<Color> colors) {
    final rect = Rect.fromLTWH(0, y, 375, h);
    c.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ).createShader(rect),
    );
  }

  void _isoTiles(Canvas c, double y0, double y1, Color light, Color dark) {
    const tw = 40.0, th = 20.0;
    final paintL = Paint()..color = light.withValues(alpha: 0.22);
    final paintD = Paint()..color = dark.withValues(alpha: 0.22);
    for (double y = y0; y < y1 + th; y += th) {
      for (double x = -tw; x < 375 + tw; x += tw) {
        final ox = ((y / th) % 2 == 0) ? 0.0 : tw / 2;
        final cx = x + ox, cy = y;
        final path = Path()
          ..moveTo(cx, cy - th / 2)
          ..lineTo(cx + tw / 2, cy)
          ..lineTo(cx, cy + th / 2)
          ..lineTo(cx - tw / 2, cy)
          ..close();
        c.drawPath(path, ((x + y) / tw).round() % 2 == 0 ? paintL : paintD);
      }
    }
  }

  void _cliff(Canvas c, double y, Color c1, Color c2, Color c3) {
    // Layer 1 (deepest)
    final p1 = Path()
      ..moveTo(0, y - 22)
      ..cubicTo(80, y - 18, 200, y - 26, 375, y - 20)
      ..lineTo(375, y + 30)
      ..lineTo(0, y + 30)
      ..close();
    c.drawPath(p1, Paint()..color = c1);
    // Layer 2
    final p2 = Path()
      ..moveTo(0, y - 12)
      ..cubicTo(90, y - 8, 200, y - 16, 375, y - 10)
      ..lineTo(375, y + 30)
      ..lineTo(0, y + 30)
      ..close();
    c.drawPath(p2, Paint()..color = c2);
    // Layer 3 (top rim)
    final p3 = Path()
      ..moveTo(0, y - 4)
      ..cubicTo(90, y, 200, y - 8, 375, y - 2)
      ..lineTo(375, y + 30)
      ..lineTo(0, y + 30)
      ..close();
    c.drawPath(p3, Paint()..color = c3);
  }

  void _drawPath(Canvas c) {
    final path = _parsePath();
    // shadow
    c.save();
    c.translate(8, 16);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0x40000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 54
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    c.restore();
    // road wall
    c.save();
    c.translate(8, 14);
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF8B6010)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 50
        ..strokeCap = StrokeCap.round,
    );
    c.restore();
    // road surface
    c.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFF8E7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.round,
    );
    // dashed centerline
    final dashPaint = Paint()
      ..color = const Color(0xFFFFD93D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    _dashPath(c, path, dashPaint, dash: 14, gap: 12);
  }

  void _dashPath(
    Canvas c,
    Path p,
    Paint pt, {
    double dash = 10,
    double gap = 6,
  }) {
    for (final metric in p.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        c.drawPath(metric.extractPath(d, d + dash), pt);
        d += dash + gap;
      }
    }
  }

  Path _parsePath() {
    // Handcoded from PATH_D string
    return Path()
      ..moveTo(248, 1730)
      ..cubicTo(195, 1630, 155, 1600, 110, 1510)
      ..cubicTo(65, 1420, 228, 1368, 262, 1300)
      ..cubicTo(296, 1232, 162, 1120, 110, 1070)
      ..cubicTo(58, 1020, 238, 882, 262, 840)
      ..cubicTo(286, 798, 155, 648, 110, 605)
      ..cubicTo(65, 562, 262, 447, 262, 400)
      ..cubicTo(262, 352, 216, 262, 188, 205);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─── Icon trang trí mờ ở nền ─────────────────────────────────────────────────
class _BgDecor extends StatelessWidget {
  const _BgDecor();

  // (emoji, left%, top%, size, opacity, xoay)
  static const _items = [
    ('🍎', 0.08, 0.10, 34.0, 0.14, -0.2),
    ('🐶', 0.80, 0.08, 38.0, 0.13, 0.2),
    ('📚', 0.85, 0.30, 32.0, 0.12, 0.1),
    ('⭐', 0.14, 0.32, 26.0, 0.16, -0.3),
    ('🎈', 0.05, 0.55, 30.0, 0.12, 0.15),
    ('🧩', 0.82, 0.55, 30.0, 0.12, -0.15),
    ('🌈', 0.10, 0.78, 34.0, 0.12, 0.1),
    ('🎧', 0.78, 0.76, 30.0, 0.13, -0.2),
    ('🐱', 0.45, 0.16, 24.0, 0.12, 0.2),
    ('✏️', 0.50, 0.62, 26.0, 0.12, -0.1),
  ];

  @override
  Widget build(BuildContext c) => IgnorePointer(
    child: LayoutBuilder(
      builder: (_, box) {
        return Stack(
          children: [
            for (final it in _items)
              Positioned(
                left: box.maxWidth * it.$2,
                top: box.maxHeight * it.$3,
                child: Opacity(
                  opacity: it.$5,
                  child: Transform.rotate(
                    angle: it.$6,
                    child: Text(it.$1, style: TextStyle(fontSize: it.$4)),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

// ─── Màn Cài đặt (bổ sung, khớp thiết kế Figma) ──────────────────────────────
class SettingsScreen extends StatefulWidget {
  final AppState appState;
  final VoidCallback onClose;
  const SettingsScreen({
    super.key,
    required this.appState,
    required this.onClose,
  });
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int direction = 0; // VN→GB / GB→VN
  int difficulty = 1; // Dễ / Vừa / Khó
  int goal = 1; // 5 / 10 / 15
  bool soundFx = true;
  bool bgMusic = true;
  double volume = 0.7;
  bool vibrate = true;
  bool notify = true;
  bool dailyReminder = true;
  bool darkMode = false;
  int themeColor = 0; // mint

  static const _swatches = [C.mint, C.indigo, C.coral, C.amber, C.lavender];
  static const _swatchNames = ['Mint', 'Indigo', 'Coral', 'Amber', 'Lavender'];

  @override
  void initState() {
    super.initState();
    direction = widget.appState.direction.clamp(0, 1);
    difficulty = widget.appState.difficulty.clamp(0, 2);
    goal = switch (widget.appState.dailyGoal) {
      5 => 0,
      15 => 2,
      _ => 1,
    };
    soundFx = widget.appState.soundFx;
    notify = widget.appState.notifications;
    bgMusic = widget.appState.bgMusic;
    volume = widget.appState.volume;
    vibrate = widget.appState.vibrate;
    dailyReminder = widget.appState.dailyReminder;
    darkMode = widget.appState.darkMode;
    themeColor = widget.appState.themeColor.clamp(0, _swatches.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [C.mint, C.mintLight, C.mintPale],
          stops: [0, 0.55, 1],
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _header(),
            const SizedBox(height: 18),
            _profileCard(),
            const SizedBox(height: 20),

            _label('HỌC TẬP'),
            _tile(
              '🌐',
              C.indigo,
              C.indigoSoft,
              'Ngôn ngữ',
              'Chọn hướng học từ vựng',
              _segmented(['VN→GB', 'GB→VN'], direction, (i) {
                setState(() => direction = i);
                unawaited(widget.appState.setDirection(i));
              }),
            ),
            _tile(
              '🎯',
              C.coral,
              C.coralSoft,
              'Độ khó',
              'Ảnh hưởng gợi ý và số nghĩa',
              _segmented(['Dễ', 'Vừa', 'Khó'], difficulty, (i) {
                setState(() => difficulty = i);
                unawaited(widget.appState.setDifficulty(i));
              }),
            ),
            _tile(
              '📗',
              C.mint,
              C.mintPale,
              'Mục tiêu mỗi ngày',
              'Học ${[5, 10, 15][goal]} từ vựng / ngày',
              _segmented(['5', '10', '15'], goal, (i) {
                setState(() => goal = i);
                unawaited(widget.appState.setDailyGoal([5, 10, 15][i]));
              }),
            ),

            const SizedBox(height: 6),
            _label('ÂM THANH'),
            _tile(
              '🔊',
              C.orange,
              C.orangeSoft,
              'Hiệu ứng âm thanh',
              'Tiếng khi bấm và trả lời',
              _switch(soundFx, (v) {
                setState(() => soundFx = v);
                unawaited(widget.appState.setSoundFx(v));
              }, C.orange),
            ),
            _tile(
              '🎵',
              C.indigo,
              C.indigoSoft,
              'Nhạc nền',
              'Nhạc êm dịu khi học',
              _switch(bgMusic, (v) {
                setState(() => bgMusic = v);
                unawaited(widget.appState.setBgMusic(v));
              }, C.indigo),
            ),
            _tile(
              '🎚️',
              C.mint,
              C.mintPale,
              'Âm lượng',
              '',
              SizedBox(
                width: 140,
                child: Row(
                  children: [
                    const Text('🔉', style: TextStyle(fontSize: 14)),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 5,
                          activeTrackColor: C.mint,
                          inactiveTrackColor: C.mint.withValues(alpha: 0.25),
                          thumbColor: AppColors.blue,
                          overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: volume,
                          onChanged: (v) {
                            setState(() => volume = v);
                            unawaited(widget.appState.setVolume(v));
                          },
                        ),
                      ),
                    ),
                    const Text('🔊', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 6),
            _label('THÔNG BÁO'),
            _tile(
              '🔔',
              C.coral,
              C.coralSoft,
              'Bật thông báo',
              'Cho phép app gửi thông báo',
              _switch(notify, (v) {
                setState(() => notify = v);
                unawaited(widget.appState.setNotifications(v));
              }, C.coral),
            ),
            _tile(
              '⏰',
              C.amber,
              C.amberSoft,
              'Nhắc học mỗi ngày',
              'Nhắc lúc 19:00 hằng ngày',
              _switch(dailyReminder, (v) {
                setState(() => dailyReminder = v);
                unawaited(widget.appState.setDailyReminder(v));
              }, C.amber),
            ),
            _tile(
              '📳',
              C.orange,
              C.orangeSoft,
              'Rung khi bấm',
              'Rung phản hồi khi tương tác',
              _switch(vibrate, (v) {
                setState(() => vibrate = v);
                unawaited(widget.appState.setVibrate(v));
              }, C.orange),
            ),

            const SizedBox(height: 6),
            _label('HIỂN THỊ'),
            _tile(
              '🌙',
              C.indigo,
              C.indigoSoft,
              'Chế độ tối',
              'Dịu mắt vào buổi tối',
              _switch(darkMode, (v) {
                setState(() => darkMode = v);
                unawaited(widget.appState.setDarkMode(v));
              }, C.indigo),
            ),
            _tile(
              '🎨',
              C.purple,
              C.indigoSoft,
              'Chủ đề màu',
              '${_swatchNames[themeColor]} · Đang chọn',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (int i = 0; i < _swatches.length; i++)
                    GestureDetector(
                      onTap: () {
                        setState(() => themeColor = i);
                        unawaited(widget.appState.setThemeColor(i));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: _swatches[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: themeColor == i ? C.navy : Colors.white,
                            width: themeColor == i ? 2 : 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),
            _label('PHỤ HUYNH'),
            _tile(
              '🔒',
              C.purple,
              C.indigoSoft,
              'Chế độ phụ huynh',
              'Cần mã PIN để mở',
              _chevron(),
            ),
            _tile(
              '⏳',
              C.amber,
              C.amberSoft,
              'Giới hạn thời gian',
              'Tối đa 45 phút mỗi ngày',
              _chevron(),
            ),

            const SizedBox(height: 6),
            _label('THÔNG TIN'),
            _tile(
              'ℹ️',
              C.indigo,
              C.indigoSoft,
              'Về ứng dụng',
              'Phiên bản 1.2.0',
              _chevron(),
            ),
            _tile(
              '⭐',
              C.amber,
              C.amberSoft,
              'Đánh giá ứng dụng',
              'Gửi cho chúng tôi 5 sao nhé!',
              _chevron(),
            ),
            _tile(
              '🛟',
              C.coral,
              C.coralSoft,
              'Trợ giúp & Hỗ trợ',
              '',
              _chevron(),
            ),
            _tile(
              '🛡️',
              C.mint,
              C.mintPale,
              'Chính sách bảo mật',
              '',
              _chevron(),
            ),

            const SizedBox(height: 8),
            _logoutButton(context),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton(BuildContext context) => GestureDetector(
    onTap: () => _confirmResetProgress(context),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: C.coralSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: C.coral.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.restart_alt_rounded, color: C.coral, size: 20),
          const SizedBox(width: 8),
          Text(
            'Đặt lại tiến độ',
            style: t(15, w: FontWeight.w800, color: C.coral),
          ),
        ],
      ),
    ),
  );

  void _confirmResetProgress(BuildContext context) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.cardBorder, width: 2),
        ),
        title: Text('Đặt lại tiến độ?', style: t(18, w: FontWeight.w900)),
        content: Text(
          'Toàn bộ điểm, streak và từ đã học trên thiết bị sẽ được xóa. Không thể hoàn tác.',
          style: t(14, w: FontWeight.w600, color: C.muted),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text(
              'Huỷ',
              style: t(14, w: FontWeight.w800, color: C.muted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dctx).pop();
              unawaited(widget.appState.resetProgress());
              widget.onClose();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã đặt lại tiến độ trên thiết bị.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: C.coral,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Xóa tiến độ',
              style: t(14, w: FontWeight.w800, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() => Row(
    children: [
      GestureDetector(
        onTap: widget.onClose,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardBorder, width: 1.5),
          ),
          child: const Icon(Icons.chevron_left, color: AppColors.text),
        ),
      ),
      const SizedBox(width: 12),
      Text('Cài đặt ⚙️', style: t(24, w: FontWeight.w900)),
    ],
  );

  Widget _profileCard() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [C.orange, C.coral]),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x40FF6B6B),
          offset: Offset(0, 6),
          blurRadius: 18,
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            shape: BoxShape.circle,
          ),
          child: Text(
            widget.appState.profileName.isEmpty
                ? 'B'
                : widget.appState.profileName.substring(0, 1).toUpperCase(),
            style: t(24, w: FontWeight.w900, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.appState.profileName,
                style: t(18, w: FontWeight.w800, color: Colors.white),
              ),
              Text(
                'Đã học ${widget.appState.sessions} màn · ${widget.appState.streak} ngày streak',
                style: t(
                  12,
                  w: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(14),
          ),
          child: InkWell(
            onTap: () => _editProfileName(context),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Sửa',
                style: t(13, w: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Future<void> _editProfileName(BuildContext context) async {
    final controller = TextEditingController(text: widget.appState.profileName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tên người học'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Nhập tên của bạn'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await widget.appState.setProfileName(name);
  }

  Widget _label(String s) => Padding(
    padding: const EdgeInsets.only(bottom: 10, top: 4),
    child: Text(
      s,
      style: t(
        12,
        w: FontWeight.w800,
        color: C.muted,
      ).copyWith(letterSpacing: 1),
    ),
  );

  Widget _tile(
    String emoji,
    Color c,
    Color bg,
    String title,
    String sub,
    Widget trailing,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.cardBorder, width: 2),
      boxShadow: const [
        BoxShadow(
          color: AppColors.cardEdge,
          offset: Offset(0, 4),
          blurRadius: 0,
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 19)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t(15, w: FontWeight.w800)),
              if (sub.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: t(12, w: FontWeight.w600, color: C.muted),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        trailing,
      ],
    ),
  );

  Widget _chevron() => const Icon(Icons.chevron_right, color: C.muted);

  Widget _switch(bool v, ValueChanged<bool> onChanged, Color c) => Switch(
    value: v,
    onChanged: onChanged,
    activeThumbColor: Colors.white,
    activeTrackColor: c,
  );

  Widget _segmented(
    List<String> labels,
    int selected,
    ValueChanged<int> onTap,
  ) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < labels.length; i++)
          GestureDetector(
            onTap: () => onTap(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: selected == i ? AppColors.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: selected == i
                    ? Border.all(color: AppColors.cardBorder, width: 1.5)
                    : null,
              ),
              child: Text(
                labels[i],
                style: t(
                  11.5,
                  w: FontWeight.w700,
                  color: selected == i ? C.amber : C.muted,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

// ─── Màn Thành tích (tab cúp) ────────────────────────────────────────────────
class AchievementsScreen extends StatelessWidget {
  final AppState appState;

  const AchievementsScreen({super.key, required this.appState});

  // (emoji, tên, mô tả, màu, nền, đã mở khóa)
  static const _all = [
    (
      '🌟',
      'Học liên tiếp 5 ngày',
      'Không nghỉ ngày nào!',
      C.amber,
      C.amberSoft,
      true,
    ),
    ('🐣', 'Từ vựng đầu tiên', 'Học được 10 từ mới', C.mint, C.mintPale, true),
    (
      '🚀',
      'Màn học đầu tiên',
      'Hoàn thành một phiên học',
      C.indigo,
      C.indigoSoft,
      true,
    ),
    ('💯', 'Điểm chăm chỉ', 'Tích lũy 100 điểm', C.coral, C.coralSoft, true),
    ('📚', 'Mọt sách nhí', 'Học đủ 15 từ vựng', C.mint, C.mintPale, true),
    (
      '🦉',
      'Cú đêm chăm chỉ',
      'Học bài sau 22:00',
      C.purple,
      C.indigoSoft,
      true,
    ),
    (
      '🎯',
      'Bậc thầy điểm số',
      'Tích lũy 500 điểm',
      C.orange,
      C.orangeSoft,
      true,
    ),
    (
      '👑',
      'Nhà vô địch tuần',
      'Giữ streak 30 ngày',
      C.amber,
      C.amberSoft,
      true,
    ),
    (
      '🔥',
      'Chuỗi lửa 10 màn',
      'Hoàn thành 10 màn học',
      C.orange,
      C.orangeSoft,
      false,
    ),
    (
      '🏆',
      'Bậc thầy từ vựng',
      'Học đủ 15 từ vựng',
      C.indigo,
      C.indigoSoft,
      false,
    ),
    ('⚡', 'Thần tốc', 'Hoàn thành 10 màn học', C.coral, C.coralSoft, false),
    ('🌍', 'Nhà thám hiểm', 'Học đủ 15 lớp E4', C.mint, C.mintPale, false),
  ];

  @override
  Widget build(BuildContext ctx) {
    final all = _all.indexed
        .map(
          (entry) => (
            entry.$2.$1,
            entry.$2.$2,
            entry.$2.$3,
            entry.$2.$4,
            entry.$2.$5,
            _isUnlocked(entry.$1),
          ),
        )
        .toList();
    final unlocked = all.where((a) => a.$6).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Text('Thành tích 🏆', style: t(22, w: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(
          'Sưu tầm huy hiệu khi học nhé!',
          style: t(13, w: FontWeight.w600, color: C.muted),
        ),
        const SizedBox(height: 16),
        _progress(unlocked, _all.length),
        const SizedBox(height: 18),
        Text('Đã mở khóa ✨', style: t(15, w: FontWeight.w800)),
        const SizedBox(height: 12),
        ...all.where((a) => a.$6).map(_card),
        const SizedBox(height: 6),
        Text('Chưa mở khóa 🔒', style: t(15, w: FontWeight.w800)),
        const SizedBox(height: 12),
        ...all.where((a) => !a.$6).map(_card),
      ],
    );
  }

  bool _isUnlocked(int index) => appState.isAchievementUnlocked(index);

  Widget _progress(int done, int total) {
    final ratio = done / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [C.indigo, C.indigoMid]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x475B56F0),
            offset: Offset(0, 4),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tiến độ sưu tầm',
                style: t(14, w: FontWeight.w800, color: Colors.white),
              ),
              Text(
                '$done/$total',
                style: t(15, w: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 12,
              color: Colors.white.withValues(alpha: 0.22),
              child: FractionallySizedBox(
                widthFactor: ratio,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [C.amber, C.orange]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card((String, String, String, Color, Color, bool) a) {
    final unlocked = a.$6;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: unlocked ? AppColors.surface : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder, width: 2),
          boxShadow: unlocked
              ? const [
                  BoxShadow(
                    color: AppColors.cardEdge,
                    offset: Offset(0, 4),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: unlocked ? a.$5 : AppColors.locked,
                shape: BoxShape.circle,
              ),
              child: unlocked
                  ? Text(a.$1, style: const TextStyle(fontSize: 24))
                  : Opacity(
                      opacity: 0.5,
                      child: Text(a.$1, style: const TextStyle(fontSize: 22)),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.$2,
                    style: t(
                      15,
                      w: FontWeight.w800,
                      color: unlocked ? C.navy : C.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.$3,
                    style: t(12, w: FontWeight.w600, color: C.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            unlocked
                ? Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: a.$4,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 16,
                      color: Colors.white,
                    ),
                  )
                : const Text('🔒', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
