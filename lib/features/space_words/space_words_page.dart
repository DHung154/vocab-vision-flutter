import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/state/app_state.dart';
import '../../mascot/may_mascot.dart';
import 'space_data.dart';
import 'space_game_screen.dart';
import 'space_sprites.dart';

class _SpaceNodeMotion extends StatefulWidget {
  const _SpaceNodeMotion({
    required this.current,
    required this.locked,
    required this.onTap,
    required this.child,
  });
  final bool current, locked;
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_SpaceNodeMotion> createState() => _SpaceNodeMotionState();
}

class _SpaceNodeMotionState extends State<_SpaceNodeMotion>
    with TickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  bool _reduced = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.disableAnimationsOf(context);
    if (widget.current && !_reduced) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  void didUpdateWidget(covariant _SpaceNodeMotion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current && !_reduced) {
      _pulse.repeat(reverse: true);
    } else {
      _pulse.stop();
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      if (widget.locked && !_reduced) _shake.forward(from: 0);
      widget.onTap();
    },
    child: AnimatedBuilder(
      animation: Listenable.merge([_pulse, _shake]),
      child: widget.child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          _reduced
              ? 0
              : math.sin(_shake.value * math.pi * 6) * (1 - _shake.value) * 6,
          0,
        ),
        child: Transform.scale(
          scale: widget.current && !_reduced ? 1 + _pulse.value * .04 : 1,
          child: child,
        ),
      ),
    ),
  );
  @override
  void dispose() {
    _pulse.dispose();
    _shake.dispose();
    super.dispose();
  }
}

class SpaceWordsPage extends StatefulWidget {
  const SpaceWordsPage({super.key, required this.appState, this.config});
  final AppState appState;
  final SpaceConfig? config;
  @override
  State<SpaceWordsPage> createState() => _SpaceWordsPageState();
}

class _SpaceWordsPageState extends State<SpaceWordsPage> {
  late Future<SpaceConfig> _config;
  late SpaceProgress _progress;
  bool _map = false, _busy = false;
  final _scroll = ScrollController();
  late String _encouragement;
  int? _previousStage;
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );
    _config = widget.config != null
        ? Future.value(widget.config!)
        : SpaceConfig.load();
    _progress = SpaceProgress.fromJson(widget.appState.store.spaceGameProgress);
    _encouragement = '';
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setPreferredOrientations([]));
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.appState.store.saveSpaceGameProgress(_progress.toJson());
    if (widget.appState.store.persistenceError != null) {
      throw StateError(
        'Chưa lưu được tiến độ lâu dài. Hãy kiểm tra bộ nhớ ở Trang chủ.',
      );
    }
  }

  Future<void> _play(
    SpaceConfig config,
    SpaceLevel level, {
    bool replay = false,
  }) async {
    if (_busy) return;
    try {
      final words = config.wordsFor(level, widget.appState.catalog);
      setState(() => _busy = true);
      await precacheImage(
        AssetImage('${spaceAssets}background_${level.background}.png'),
        context,
      );
      if (!mounted) return;
      if (level.boss) {
        await precacheImage(
          const AssetImage('${spaceAssets}boss_atlas_v2.png'),
          context,
        );
        if (!mounted) return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => SpaceGameScreen(
            config: config,
            level: level,
            words: words,
            progress: _progress,
            tutorial: level.tutorial && (!_progress.tutorialDone || replay),
            onResult: (result) async {
              _previousStage = level.id;
              _progress.record(level.id, result);
              await _save();
              final sessionId =
                  'space-${DateTime.now().microsecondsSinceEpoch}';
              for (final attempt in result.attempts) {
                await widget.appState.recordAttempt(
                  wordId: attempt.word.id,
                  correct: attempt.correct,
                  assisted: attempt.assisted,
                  questionType: 'space_words',
                  sessionId: sessionId,
                );
              }
            },
          ),
        ),
      );
      if (mounted) {
        setState(() {
          _busy = false;
          _map = true;
        });
        _scrollToCurrent(config);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không mở được màn chơi: $error')));
    }
  }

  void _scrollToCurrent(SpaceConfig config) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final id = _progress.unlocked.clamp(1, config.levels.length);
      final level = config.levels[id - 1];
      final totalHeight = MediaQuery.sizeOf(context).width * 3;
      _scroll.animateTo(
        (totalHeight * level.mapY - _scroll.position.viewportDimension / 2)
            .clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _chooseLevel(SpaceConfig config, SpaceLevel level) async {
    if (level.id > _progress.unlocked) {
      setState(() => _encouragement = 'Hoàn thành màn trước nhé!');
      return;
    }
    final start = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Màn ${level.id}: ${level.title}',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Chương 1: ${level.topic} • ${_progress.stars[level.id] ?? 0}/3 sao',
              ),
              const SizedBox(height: 14),
              SpaceButton(
                config: config,
                label: 'Bắt đầu',
                onPressed: () => Navigator.pop(context, true),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Để sau'),
              ),
            ],
          ),
        ),
      ),
    );
    if (start == true && mounted) await _play(config, level);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SpaceConfig>(
    future: _config,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Sân chơi của Mây')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Không đọc được cấu hình game: ${snapshot.error}'),
                  TextButton(
                    onPressed: () =>
                        setState(() => _config = SpaceConfig.load()),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      final config = snapshot.data!;
      if (_encouragement.isEmpty) {
        final messages = (config.json['mapEncouragement'] as List)
            .cast<String>();
        _encouragement = messages[math.Random().nextInt(messages.length)];
      }
      return PopScope(
        canPop: !_map,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && mounted) setState(() => _map = false);
        },
        child: Scaffold(
          appBar: AppBar(
            leading: BackButton(
              onPressed: () {
                if (_map) {
                  setState(() => _map = false);
                } else {
                  Navigator.pop(context);
                }
              },
            ),
            title: Text(_map ? 'Chương 1: Động vật' : 'Sân chơi của Mây'),
            actions: [
              SpaceSprite('star_full', config: config, width: 26),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 16, 0),
                child: Center(child: Text('${_progress.totalStars}')),
              ),
            ],
          ),
          body: _map ? _buildMap(config) : _buildMenu(config),
        ),
      );
    },
  );

  Widget _buildMenu(SpaceConfig config) => Stack(
    children: [
      Positioned.fill(
        child: Image.asset(
          '${spaceAssets}background_sky.png',
          fit: BoxFit.cover,
          cacheWidth: 768,
        ),
      ),
      SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Phi đội từ vựng',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: const Color(0xFF183047),
                fontWeight: FontWeight.w900,
                fontSize: 26,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SpaceSprite(_progress.ship, config: config, width: 104),
                const SizedBox(width: 16),
                const MayMascot(size: 96, animation: MayAnimation.greetWave),
              ],
            ),
            const SizedBox(height: 12),
            SpacePanel(
              config: config,
              minHeight: 74,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Kéo để lái, chọn nghĩa để bắn!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF183047),
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Học từ mới cùng Mây.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2B5678),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SpaceButton(
              config: config,
              height: 58,
              label: 'Khám phá bản đồ',
              onPressed: _busy
                  ? null
                  : () {
                      setState(() => _map = true);
                      _scrollToCurrent(config);
                    },
            ),
            const SizedBox(height: 12),
            SpaceButton(
              config: config,
              height: 58,
              label: _progress.tutorialDone
                  ? 'Xem lại hướng dẫn'
                  : 'Tập lái cùng Mây',
              sprite: 'ammo_selected',
              onPressed: _busy
                  ? null
                  : () => _play(config, config.levels.first, replay: true),
            ),
            const SizedBox(height: 20),
            // Header for Ship Selection - separated from ship container
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'Chọn phi thuyền',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF183047),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            // Ship Selection Container with consistent baseline and clear status indicators
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF4A89C8), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.18),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  for (final ship in config.json['ships'] as List) ...[
                    Expanded(
                      child: _buildShipItem(
                        config,
                        ship as Map<String, dynamic>,
                      ),
                    ),
                    if (ship != (config.json['ships'] as List).last)
                      const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Audio Settings Card - roomy and cleanly aligned
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFF4A89C8), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E3A5F).withValues(alpha: 0.18),
                    offset: const Offset(0, 4),
                    blurRadius: 8,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Row 1: Phát âm từ
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Phát âm từ',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF183047),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Đọc to từ vựng tiếng Anh khi chơi',
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(
                                  0xFF183047,
                                ).withValues(alpha: 0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch.adaptive(
                        value: _progress.sound,
                        activeTrackColor: const Color(0xFF22C55E),
                        onChanged: (v) async {
                          setState(() => _progress.sound = v);
                          try {
                            await _save();
                          } catch (e) {
                            _saveWarning(e);
                          }
                        },
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(color: Color(0xFFD6E6F2), height: 1),
                  ),
                  // Row 2: Nhạc nền
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Nhạc nền',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF183047),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Nhạc nhỏ • tự hạ khi đọc từ',
                              style: TextStyle(
                                fontSize: 13,
                                color: const Color(
                                  0xFF183047,
                                ).withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Switch.adaptive(
                        value: _progress.music,
                        activeTrackColor: const Color(0xFF22C55E),
                        onChanged: config.json['audio']['music'] == null
                            ? null
                            : (v) async {
                                setState(() => _progress.music = v);
                                try {
                                  await _save();
                                } catch (e) {
                                  _saveWarning(e);
                                }
                              },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Offline TTS notice in dedicated sub-area
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF5FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFBFDBFE),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Phát âm offline cần giọng tiếng Anh đã cài trên máy.',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E40AF),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildShipItem(SpaceConfig config, Map<String, dynamic> ship) {
    final shipId = ship['id'] as String;
    final starsRequired = ship['stars'] as int;
    final isSelected = _progress.ship == shipId;
    final isUnlocked = _progress.totalStars >= starsRequired;
    final reduced = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      button: true,
      label:
          'Phi thuyền $shipId, cần $starsRequired sao, ${isSelected
              ? 'đang dùng'
              : isUnlocked
              ? 'đã mở khóa'
              : 'đã khóa'}',
      selected: isSelected,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          if (!isUnlocked) return;
          setState(() => _progress.ship = shipId);
          try {
            await _save();
          } catch (e) {
            _saveWarning(e);
          }
        },
        child: AnimatedContainer(
          duration: reduced ? Duration.zero : const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFFFEF3C7)
                : isUnlocked
                ? const Color(0xFFF0F9FF)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFF59E0B)
                  : isUnlocked
                  ? const Color(0xFFBAE6FD)
                  : const Color(0xFFCBD5E1),
              width: isSelected ? 2.5 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      offset: const Offset(0, 3),
                      blurRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Consistent 66dp height container to maintain the exact same baseline across all 3 ships
              SizedBox(
                height: 66,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SpaceSprite(
                        shipId,
                        config: config,
                        width: 62,
                        opacity: isUnlocked ? 1.0 : 0.45,
                      ),
                      if (!isUnlocked)
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF1E293B,
                            ).withValues(alpha: 0.75),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Status label with bottom padding
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFFF59E0B)
                      : isUnlocked
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isSelected ? 'Đang dùng' : '$starsRequired sao',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? Colors.white
                        : isUnlocked
                        ? const Color(0xFF0369A1)
                        : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveWarning(Object error) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Chưa lưu được: $error')));
    }
  }

  Widget _buildMap(SpaceConfig config) {
    final current = _progress.unlocked.clamp(1, config.levels.length);
    final mapHeight = MediaQuery.sizeOf(context).width * 3;
    final level = config.levels[current - 1];
    final previous = _previousStage == null
        ? level
        : config.levels[(_previousStage! - 1).clamp(
            0,
            config.levels.length - 1,
          )];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SpacePanel(
            config: config,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              children: [
                const MayMascot(size: 52, animation: MayAnimation.encourage),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _encouragement,
                    style: const TextStyle(
                      color: Color(0xFF183047),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _scroll,
            child: SizedBox(
              height: mapHeight,
              child: LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(
                        '${spaceAssets}map_cosmos.png',
                        fit: BoxFit.fill,
                        cacheWidth: 768,
                      ),
                    ),
                    for (final stage in config.levels)
                      Positioned(
                        left: stage.mapX * constraints.maxWidth - 48,
                        top: stage.mapY * mapHeight - 48,
                        child: SizedBox(
                          width: 96,
                          child: Column(
                            children: [
                              Semantics(
                                button: true,
                                label:
                                    'Màn ${stage.id}: ${stage.title}, '
                                    '${stage.id > _progress.unlocked ? 'đã khóa' : 'có thể chơi'}',
                                child: _SpaceNodeMotion(
                                  current: stage.id == current,
                                  locked: stage.id > _progress.unlocked,
                                  onTap: () => _chooseLevel(config, stage),
                                  child: SizedBox(
                                    width: 80,
                                    height: 80,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SpaceSprite(
                                          stage.id > _progress.unlocked
                                              ? 'node_locked'
                                              : stage.boss
                                              ? 'node_boss'
                                              : (_progress.stars[stage.id] ??
                                                        0) >
                                                    0
                                              ? 'node_complete'
                                              : 'node_open',
                                          config: config,
                                          width: 80,
                                        ),
                                        if (!stage.boss &&
                                            stage.id <= _progress.unlocked)
                                          Text(
                                            '${stage.id}',
                                            style: const TextStyle(
                                              color: Color(0xFF183047),
                                              fontSize: 23,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  for (var s = 0; s < 3; s++)
                                    SpaceSprite(
                                      s < (_progress.stars[stage.id] ?? 0)
                                          ? 'star_full'
                                          : 'star_empty',
                                      config: config,
                                      width: 22,
                                    ),
                                ],
                              ),
                              Text(
                                'Màn ${stage.id}',
                                style: const TextStyle(
                                  color: Color(0xFF183047),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    TweenAnimationBuilder<double>(
                      key: ValueKey(current),
                      tween: Tween(begin: 0, end: 1),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(milliseconds: 950),
                      curve: Curves.easeInOutCubic,
                      builder: (context, t, child) => Positioned(
                        left:
                            (previous.mapX + (level.mapX - previous.mapX) * t) *
                                constraints.maxWidth -
                            22,
                        top:
                            (previous.mapY + (level.mapY - previous.mapY) * t) *
                                mapHeight -
                            95,
                        child: child!,
                      ),
                      child: SpaceSprite(
                        _progress.ship,
                        config: config,
                        width: 44,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
