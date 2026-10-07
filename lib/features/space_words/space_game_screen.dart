import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show FramePhase;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../catalog_data.dart';
import '../../mascot/may_mascot.dart';
import 'space_data.dart';
import 'space_engine.dart';
import 'space_sprites.dart';

class SpaceGameScreen extends StatefulWidget {
  const SpaceGameScreen({
    super.key,
    required this.config,
    required this.level,
    required this.words,
    required this.progress,
    required this.tutorial,
    required this.onResult,
    this.musicRandom,
  });
  final SpaceConfig config;
  final SpaceLevel level;
  final List<CatalogWord> words;
  final SpaceProgress progress;
  final bool tutorial;
  final Future<void> Function(SpaceResult result) onResult;
  final math.Random? musicRandom;
  @override
  State<SpaceGameScreen> createState() => _SpaceGameScreenState();
}

class _SpaceGameScreenState extends State<SpaceGameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _tts = MethodChannel('vocab_vision/tts');
  static const _audio = MethodChannel('vocab_vision/game_audio');
  late SpaceEngine _engine;
  late Ticker _ticker;
  Duration? _lastTick;
  bool _handled = false, _saving = false, _listenUsable = true;
  bool _ttsVerified = false;
  String? _musicTrack;
  int _lastReaction = 0;
  String? _saveError, _audioWarning;
  String _device = Platform.operatingSystem;
  final List<double> _frameMillis = [];
  int _renderedFrames = 0;
  int? _firstVsync, _lastVsync;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenUsable = widget.progress.sound;
    _makeEngine();
    if (!_listenUsable && _engine.listening) {
      _audioWarning =
          'Đã tắt phát âm. Màn này hiện từ tiếng Anh để bé chơi tiếp.';
    }
    _ticker = createTicker((elapsed) {
      final previous = _lastTick;
      _lastTick = elapsed;
      if (previous != null) {
        _engine.update((elapsed - previous).inMicroseconds / 1000000);
      }
    })..start();
    SchedulerBinding.instance.addTimingsCallback(_timings);
    unawaited(_loadDevice());
    if (widget.progress.music) unawaited(_playAudio('music'));
  }

  Future<void> _loadDevice() async {
    try {
      final value = await _audio.invokeMapMethod<String, dynamic>('device');
      _device = value?['model'] as String? ?? _device;
    } catch (_) {
      /* Native channel is Android-only. */
    }
  }

  void _timings(List<FrameTiming> timings) {
    if (!mounted || _engine.paused || _engine.result != null) return;
    for (final t in timings) {
      final vsync = t.timestampInMicroseconds(FramePhase.vsyncStart);
      _firstVsync ??= vsync;
      _lastVsync = vsync;
      _renderedFrames++;
      if (_frameMillis.length < 600) {
        _frameMillis.add(
          (t.buildDuration + t.rasterDuration).inMicroseconds / 1000,
        );
      }
    }
  }

  void _resetMetrics() {
    _frameMillis.clear();
    _renderedFrames = 0;
    _firstVsync = null;
    _lastVsync = null;
  }

  void _makeEngine() {
    _musicTrack = widget.config.musicFor(
      widget.level.boss,
      widget.musicRandom ?? math.Random(),
    );
    _lastReaction = 0;
    _handled = false;
    _saving = false;
    _saveError = null;
    _engine = SpaceEngine(
      config: widget.config,
      level: widget.level,
      words: widget.words,
      priorityIds: widget.progress.mistakes.keys,
      replayTutorial: widget.tutorial,
      onSpeak: (word) => unawaited(_speak(word.english)),
      onShot: () => unawaited(_playAudio('shot')),
    );
    _engine.hud.addListener(_onHud);
  }

  Future<void> _speak(String text) async {
    if (!widget.progress.sound) return;
    try {
      if (!_ttsVerified) {
        final available = await _tts.invokeMethod<bool>('available');
        if (available != true) {
          throw StateError('Chưa có giọng tiếng Anh offline.');
        }
        _ttsVerified = true;
      }
      await _tts.invokeMethod<void>('speak', {'text': text});
      if (mounted && !_listenUsable) {
        setState(() {
          _listenUsable = true;
          _audioWarning = null;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _listenUsable = false;
        _audioWarning =
            'Chưa phát âm được. Màn này hiện chữ để bé vẫn chơi được.';
      });
    }
  }

  Future<void> _playAudio(String key) async {
    final path = key == 'music'
        ? _musicTrack
        : widget.config.json['audio'][key] as String?;
    if (path == null ||
        !(key == 'music' ? widget.progress.music : widget.progress.sound)) {
      return;
    }
    try {
      await _audio.invokeMethod<void>(key == 'music' ? 'music' : 'effect', {
        'asset': path,
      });
    } catch (_) {
      if (mounted) {
        setState(() => _audioWarning = 'Chưa mở được file âm thanh game.');
      }
    }
  }

  void _onHud() {
    if (!mounted) return;
    if (_engine.reactionId != _lastReaction) {
      _lastReaction = _engine.reactionId;
      final sound = _engine.soundEvent;
      if (sound != null) unawaited(_playAudio(sound));
    }
    final result = _engine.result;
    if (result != null && !_handled) {
      _handled = true;
      _ticker.stop();
      setState(() => _saving = true);
      unawaited(_saveResult(result));
    }
  }

  Future<void> _saveResult(SpaceResult result) async {
    await _stopAudio();
    unawaited(
      _playAudio(
        result.won ? (widget.level.boss ? 'bossExplosion' : 'win') : 'lose',
      ),
    );
    try {
      await widget.onResult(result);
    } catch (error) {
      _saveError = 'Chưa lưu được: $error';
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _stopAudio() async {
    try {
      await _tts.invokeMethod<void>('stop');
    } catch (_) {}
    try {
      await _audio.invokeMethod<void>('stop');
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _engine.setPaused(true);
      _lastTick = null;
      _ticker.stop();
      unawaited(_stopAudio());
      if (mounted) setState(() {});
    } else {
      _lastTick = null;
      _resetMetrics();
      if (mounted) setState(() {});
    }
  }

  Future<void> _pause() async {
    if (_engine.result != null) return;
    if (_engine.paused) {
      _resume();
      return;
    }
    _engine.setPaused(true);
    _ticker.stop();
    _lastTick = null;
    unawaited(_stopAudio());
    if (mounted) setState(() {});
  }

  void _leaveGame() {
    unawaited(_stopAudio());
    Navigator.pop(context);
  }

  void _resume() {
    _lastTick = null;
    _resetMetrics();
    _engine.setPaused(false);
    if (!_ticker.isActive) _ticker.start();
    if (widget.progress.music) unawaited(_playAudio('music'));
    if (_engine.listening && _engine.target != null) {
      unawaited(_speak(_engine.target!.word.english));
    }
    setState(() {});
  }

  void _retry() {
    _engine.hud.removeListener(_onHud);
    _engine.dispose();
    _lastTick = null;
    _resetMetrics();
    _makeEngine();
    if (!_ticker.isActive) _ticker.start();
    if (widget.progress.music) unawaited(_playAudio('music'));
    setState(() {});
  }

  MayAnimation _expression(String value) => MayAnimation.values.firstWhere(
    (e) => e.name == value,
    orElse: () => MayAnimation.encourage,
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _engine.result != null && !_saving,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !_saving) _leaveGame();
    },
    child: Scaffold(
      body: SafeArea(
        child: _engine.result != null
            ? _resultView(_engine.result!)
            : Column(
                children: [
                  ValueListenableBuilder<int>(
                    valueListenable: _engine.hud,
                    builder: (context, _, _) => _hud(),
                  ),
                  Expanded(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _engine,
                        builder: (context, _) => _board(),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<int>(
                    valueListenable: _engine.hud,
                    builder: (context, _, _) => _ammo(),
                  ),
                ],
              ),
      ),
    ),
  );

  Widget _hud() => Padding(
    padding: EdgeInsets.fromLTRB(12, widget.level.boss ? 2 : 8, 12, 4),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              SpaceSprite(
                'heart',
                config: widget.config,
                width: widget.level.boss ? 22 : 28,
                opacity: i < _engine.hearts ? 1.0 : 0.25,
              ),
            ],
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Màn ${widget.level.id} • Combo ${_engine.combo}',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFF0F8FF)
                      : const Color(0xFF183047),
                  fontSize: widget.level.boss ? 15 : 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Semantics(
              button: true,
              label: 'Tạm dừng',
              child: GestureDetector(
                onTap: _pause,
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: SpaceSprite(
                      'pause',
                      config: widget.config,
                      width: widget.level.boss ? 36 : 44,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (widget.level.boss)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 2),
            child: Column(
              children: [
                Text(
                  'Thủ lĩnh sao biển • HP ${_engine.bossHp}/${_engine.bossMaxHp}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  label: 'Máu boss',
                  value: '${_engine.bossHp}/${_engine.bossMaxHp}',
                  child: LinearProgressIndicator(
                    value: _engine.bossHp / _engine.bossMaxHp,
                    minHeight: 8,
                    color: const Color(0xFFFF6E72),
                    backgroundColor: const Color(0xFFCEEAF6),
                  ),
                ),
              ],
            ),
          ),
        if (widget.level.boss)
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_engine.needsPickups ? 'Nhặt đạn' : 'Nghe & chọn'} • ×${_engine.ammoMultiplier}',
                    maxLines: 2,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (_engine.listening)
                  TextButton.icon(
                    key: const ValueKey('boss-listen-again'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(96, 48),
                      fixedSize: const Size(120, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    icon: const Icon(Icons.volume_up_rounded, size: 18),
                    label: const Text(
                      'Nghe lại',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () {
                      if (_engine.target != null) {
                        unawaited(_speak(_engine.target!.word.english));
                      }
                    },
                  ),
              ],
            ),
          ),
        if (!widget.level.boss && widget.level.pickups)
          Text(
            'Hỏa lực ×${_engine.ammoMultiplier}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        if (widget.level.boss &&
            widget.progress.music &&
            _musicTrack == widget.config.json['audio']['rareBossMusic'])
          const Padding(
            padding: EdgeInsets.only(top: 0, bottom: 2),
            child: Text(
              "you're gonna have a bad time :))",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        if (_audioWarning != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _audioWarning!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFFDE68A)
                    : const Color(0xFFB45309),
              ),
            ),
          ),
        if (_engine.listening && !widget.level.boss)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: SizedBox(
              width: 180,
              height: 48,
              child: SpaceButton(
                config: widget.config,
                sprite: 'ammo_selected',
                height: 48,
                label: 'Nghe lại',
                onPressed: _engine.needsPickups
                    ? null
                    : () {
                        if (_engine.target != null) {
                          unawaited(_speak(_engine.target!.word.english));
                        }
                      },
              ),
            ),
          ),
      ],
    ),
  );

  Widget _board() => LayoutBuilder(
    builder: (context, box) {
      final width = box.maxWidth, height = box.maxHeight;
      final offset = MediaQuery.disableAnimationsOf(context)
          ? 0.0
          : _engine.backgroundOffset * height;
      final enemySize = widget.level.boss
          ? math.min(width * .72, height * .42)
          : math.min(58.0, width * .16);
      final enemyHeight = widget.level.boss ? enemySize * 1.13 : enemySize;
      final shipSize = math.min(
        math.min(82.0, width * .22),
        widget.level.boss ? height * .15 : 82.0,
      );
      Widget at(double x, double y, double w, double h, Widget child) =>
          Positioned(
            left: x * width - w / 2,
            top: y * height - h / 2,
            width: w,
            height: h,
            child: child,
          );
      return GestureDetector(
        key: const ValueKey('space-playfield'),
        behavior: HitTestBehavior.opaque,
        onPanStart: (e) => _engine.move(
          e.localPosition.dx / width,
          e.localPosition.dy / height,
        ),
        onPanUpdate: (e) => _engine.move(
          e.localPosition.dx / width,
          e.localPosition.dy / height,
        ),
        child: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Sân bay. Kéo ngón tay để di chuyển phi thuyền.',
          value: '${(_engine.shipX * 100).round()}%',
          increasedValue:
              '${((_engine.shipX + .1).clamp(.08, .92) * 100).round()}%',
          decreasedValue:
              '${((_engine.shipX - .1).clamp(.08, .92) * 100).round()}%',
          onIncrease: () => _engine.move(_engine.shipX + .1, _engine.shipY),
          onDecrease: () => _engine.move(_engine.shipX - .1, _engine.shipY),
          child: ClipRect(
            child: Stack(
              children: [
                for (final y in [offset - height, offset])
                  Positioned(
                    left: 0,
                    right: 0,
                    top: y,
                    height: height + .5,
                    child: Image.asset(
                      '${spaceAssets}background_${widget.level.background}.png',
                      fit: BoxFit.fill,
                      cacheWidth: 768,
                    ),
                  ),
                if (_engine.tutorialActive &&
                    ['ship', 'target'].contains(_engine.highlight))
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(color: Color(0x77000000)),
                    ),
                  ),
                if (widget.level.boss && _engine.target != null)
                  ..._bossSprites(width, height, enemySize, enemyHeight, at),
                for (final e in _engine.enemies)
                  if (e.alive) ...[
                    if (!widget.level.boss && identical(e, _engine.target))
                      at(
                        e.x,
                        e.y,
                        enemySize + 28,
                        enemySize + 28,
                        SpaceSprite(
                          'target_ring',
                          config: widget.config,
                          width: enemySize + 28,
                          opacity: .75 + math.sin(_engine.elapsed * 3) * .2,
                        ),
                      ),
                    at(
                      e.x,
                      e.y,
                      enemySize,
                      enemyHeight,
                      Transform.translate(
                        offset: Offset(
                          e.hit > 0 ? math.sin(_engine.elapsed * 70) * 3 : 0,
                          0,
                        ),
                        child: SpaceSprite(
                          key: widget.level.boss
                              ? const ValueKey('boss-body')
                              : null,
                          widget.level.boss
                              ? e.hit > 0
                                    ? 'boss_v2_hit'
                                    : e.angry > 0
                                    ? 'boss_v2_angry'
                                    : 'boss_v2'
                              : '${e.word.id.hashCode.isEven ? 'enemy_green' : 'enemy_lilac'}'
                                    '${e.hit > 0
                                        ? '_hit'
                                        : e.angry > 0
                                        ? '_angry'
                                        : ''}',
                          config: widget.config,
                          width: enemySize,
                          height: enemyHeight,
                          opacity: identical(e, _engine.target) ? 1 : .5,
                        ),
                      ),
                    ),
                    if (identical(e, _engine.target)) ...[
                      at(
                        e.x,
                        e.y +
                            (widget.level.boss
                                ? enemyHeight / height / 2 + .055
                                : .105),
                        math.min(138, width * .38),
                        46,
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Positioned.fill(
                              child: SpaceSprite(
                                'word_panel',
                                config: widget.config,
                                width: 138,
                                height: 46,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              child: Text(
                                _engine.listening && _listenUsable
                                    ? 'Nghe từ nhé!'
                                    : e.word.english,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF183047),
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!widget.level.boss)
                        at(
                          e.x,
                          e.y - .105,
                          62,
                          5,
                          LinearProgressIndicator(
                            value: e.hp / e.maxHp,
                            color: const Color(0xFF4CCB57),
                            backgroundColor: const Color(0xFFF0E8FF),
                          ),
                        ),
                    ],
                  ],
                for (final b in _engine.bullets)
                  if (b.active)
                    at(
                      b.x,
                      b.y,
                      b.kind == SpaceBulletKind.enemy ? 17 : 15,
                      b.kind == SpaceBulletKind.enemy ? 17 : 28,
                      SpaceSprite(
                        b.kind == SpaceBulletKind.enemy
                            ? b.color.isEven
                                  ? 'bullet_enemy'
                                  : 'bullet_enemy_diamond'
                            : [
                                'bullet_blue',
                                'bullet_gold',
                                'bullet_lilac',
                              ][b.color],
                        config: widget.config,
                        width: 18,
                        height: 28,
                      ),
                    ),
                for (final e in _engine.effects)
                  if (e.active)
                    at(
                      e.x,
                      e.y - e.age * .08,
                      95,
                      95,
                      SpaceSprite(
                        'explosion_${(e.age / widget.config.p('effectDuration') * 3).floor().clamp(0, 2)}',
                        config: widget.config,
                        width: 95,
                      ),
                    ),
                for (final pickup in _engine.pickups)
                  if (pickup.active)
                    at(
                      pickup.x,
                      pickup.y,
                      math.min(90, width / 4),
                      44 + MediaQuery.textScalerOf(context).scale(15) * 2.4,
                      Column(
                        children: [
                          SpaceSprite(
                            'pickup',
                            config: widget.config,
                            width: 40,
                            height: 40,
                          ),
                          Text(
                            _engine.choices[pickup.index].vietnamese,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF183047),
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                if (_engine.highlight == 'ship')
                  at(
                    _engine.shipX,
                    _engine.shipY,
                    shipSize + 34,
                    shipSize + 34,
                    SpaceSprite(
                      'target_ring',
                      config: widget.config,
                      width: shipSize + 34,
                    ),
                  ),
                at(
                  _engine.shipX,
                  _engine.shipY,
                  shipSize,
                  shipSize,
                  SpaceSprite(
                    key: const ValueKey('space-player-ship'),
                    widget.progress.ship,
                    config: widget.config,
                    width: shipSize,
                    opacity:
                        _engine.invulnerable > 0 &&
                            (_engine.elapsed * 10).floor().isEven
                        ? .35
                        : 1,
                  ),
                ),
                if (_engine.paused)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.82),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: const Color(0xFF38BDF8),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tạm dừng',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: 200,
                            height: 56,
                            child: SpaceButton(
                              config: widget.config,
                              height: 56,
                              label: 'Tiếp tục chơi',
                              onPressed: _resume,
                            ),
                          ),
                          TextButton(
                            onPressed: _leaveGame,
                            child: const Text(
                              'Về bản đồ',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _bossSprites(
    double width,
    double height,
    double bodyWidth,
    double bodyHeight,
    Widget Function(double, double, double, double, Widget) at,
  ) {
    final attack = _engine.bossAttack;
    final charge = _engine.bossCharge;
    final firing = _engine.bossFiring;
    final nodes = <Widget>[];
    final boss = _engine.target!;
    for (var side = 0; side < 2; side++) {
      final left = side == 0;
      final aimX = left ? attack?.x : attack?.otherX;
      // Root is a shoulder joint on the MOVING body, never a viewport edge.
      final rootX = boss.x * width + (left ? -.32 : .32) * bodyWidth;
      final rootY = boss.y * height + bodyHeight * .08;
      final idleTipX =
          rootX +
          (left ? -1 : 1) * width * .08 +
          math.sin(_engine.elapsed * 2 + side) * 9;
      final idleTipY = rootY + height * .31;
      final attackTipY = attack == null
          ? idleTipY
          : (attack.laser ? .55 : attack.y) * height;
      final tipX = attack == null
          ? idleTipX
          : idleTipX + (aimX! * width - idleTipX) * charge;
      final tipY = attack == null
          ? idleTipY
          : idleTipY + (attackTipY - idleTipY) * charge;
      final dx = tipX - rootX, dy = tipY - rootY;
      final tentacleH = math.sqrt(dx * dx + dy * dy) / .885;
      final tentacleW = width * .18;
      final rootU = left ? .38 : .62;
      final angle = math.atan2(-dx, dy);
      nodes.add(
        Positioned(
          left: rootX - rootU * tentacleW,
          top: rootY - .035 * tentacleH,
          width: tentacleW,
          height: tentacleH,
          child: Transform.rotate(
            angle: angle,
            alignment: Alignment(rootU * 2 - 1, .035 * 2 - 1),
            child: Transform.flip(
              flipX: !left,
              child: SpaceSprite(
                'boss_tentacle',
                key: ValueKey('boss-tentacle-${left ? 'left' : 'right'}'),
                config: widget.config,
                width: tentacleW,
                height: tentacleH,
              ),
            ),
          ),
        ),
      );
      if (attack != null) {
        if (attack.laser) {
          // Telegraph and damaging beam share the SAME fixed lane coordinates.
          nodes.add(
            at(
              aimX!,
              .55 + .45 * (firing ? 1 : .15 + charge * .85) / 2,
              width * (firing ? .095 : .026),
              height * .45 * (firing ? 1 : .15 + charge * .85),
              SpaceSprite(
                'boss_beam',
                config: widget.config,
                width: width * (firing ? .095 : .026),
                height: height * .45 * (firing ? 1 : .15 + charge * .85),
                opacity: firing ? .95 : .35 + charge * .3,
              ),
            ),
          );
          nodes.add(
            at(
              aimX,
              .55,
              24 + charge * 34,
              24 + charge * 34,
              SpaceSprite(
                'boss_charge',
                config: widget.config,
                width: 24 + charge * 34,
                opacity: .6 + charge * .4,
              ),
            ),
          );
        } else {
          nodes.add(
            at(
              aimX!,
              attack.y,
              width * .22,
              width * .22,
              SpaceSprite(
                firing ? 'explosion_1' : 'target_ring',
                config: widget.config,
                width: width * .22,
                opacity: firing ? 1 : .3 + charge * .5,
              ),
            ),
          );
        }
      }
    }
    if (attack != null && !firing) {
      nodes.add(
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: IgnorePointer(
            child: Text(
              attack.laser
                  ? '⚡ Né vệt sáng — laser sắp bắn!'
                  : 'Né vòng sáng — xúc tu sắp quật!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF183047),
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }
    return nodes;
  }

  Widget _ammo() {
    final tutorial = _engine.tutorialActive;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final boss = widget.level.boss;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Semantics(
                label: 'Mascot Mây',
                child: SizedBox(
                  width: tutorial
                      ? 58
                      : boss
                      ? 38
                      : 46,
                  height: tutorial
                      ? 62
                      : boss
                      ? 40
                      : 50,
                  child: MayMascot(
                    size: tutorial
                        ? 58
                        : boss
                        ? 38
                        : 46,
                    animation: _expression(
                      tutorial
                          ? _engine.step!['expression'] as String
                          : _engine.reaction,
                    ),
                    replayId: _engine.reactionId,
                    autoReturnToIdle: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) =>
                      FadeTransition(opacity: animation, child: child),
                  child: SpacePanel(
                    key: ValueKey(_engine.speech),
                    config: widget.config,
                    padding: boss
                        ? const EdgeInsets.fromLTRB(24, 8, 18, 8)
                        : const EdgeInsets.fromLTRB(34, 16, 26, 16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: tutorial
                            ? 56
                            : boss
                            ? 26
                            : 38,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _engine.speech,
                          maxLines: boss ? 2 : null,
                          overflow: boss ? TextOverflow.ellipsis : null,
                          style: TextStyle(
                            fontSize: tutorial
                                ? 14
                                : boss
                                ? 12.5
                                : 13.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF183047),
                            height: 1.25,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (tutorial) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFBAE6FD),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      'Hướng dẫn ${_engine.tutorialIndex + 1}/${widget.config.tutorial.length}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0369A1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 96,
                  height: 48,
                  child: SpaceButton(
                    config: widget.config,
                    sprite: 'ammo_normal',
                    height: 48,
                    label: 'Bỏ qua',
                    onPressed: _engine.skipTutorial,
                  ),
                ),
                if (_engine.canNextStep) ...[
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 96,
                    height: 48,
                    child: SpaceButton(
                      config: widget.config,
                      height: 48,
                      label: 'Tiếp',
                      onPressed: _engine.nextStep,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (_engine.highlight == 'ammo') ...[
            const SizedBox(height: 4),
            SpaceSprite('arrow', config: widget.config, width: 26),
          ],
          const SizedBox(height: 6),
          if (_engine.answerCooldown > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  'Chọn lại sau ${_engine.cooldownSeconds}s',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          if (_engine.choices.isNotEmpty)
            for (var row = 0; row < (_engine.choices.length / 2).ceil(); row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    for (
                      var i = row * 2;
                      i < math.min(row * 2 + 2, _engine.choices.length);
                      i++
                    ) ...[
                      if (i > row * 2) const SizedBox(width: 8),
                      Expanded(
                        child: SpaceButton(
                          key: ValueKey('ammo-${_engine.choices[i].id}'),
                          config: widget.config,
                          height: boss ? 48 : 56,
                          sprite: _engine.wrongAmmoId == _engine.choices[i].id
                              ? 'ammo_wrong'
                              : _engine.selected == i
                              ? 'ammo_selected'
                              : 'ammo_normal',
                          wrong: _engine.wrongAmmoId == _engine.choices[i].id,
                          feedbackId: _engine.wrongFeedbackId,
                          selected: _engine.selected == i,
                          label:
                              '${_engine.choices[i].vietnamese}'
                              '${_engine.needsPickups && !_engine.collected.contains(i) ? ' • nhặt' : ''}',
                          onPressed:
                              _engine.answerCooldown > 0 || _engine.paused
                              ? null
                              : () => _engine.select(i),
                        ),
                      ),
                    ],
                    if (row * 2 + 1 >= _engine.choices.length) ...[
                      const SizedBox(width: 8),
                      const Expanded(child: SizedBox()),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Widget _resultView(SpaceResult result) {
    final errors = result.attempts
        .where((a) => !a.correct && !a.assisted)
        .map((a) => a.word.id)
        .toSet();
    final sorted = List<double>.from(_frameMillis)..sort();
    final p95 = sorted.isEmpty
        ? null
        : sorted[(sorted.length * .95).floor().clamp(0, sorted.length - 1)];
    final duration = _firstVsync == null || _lastVsync == _firstVsync
        ? 0
        : (_lastVsync! - _firstVsync!) / 1000000;
    final fps = duration <= 0 ? null : (_renderedFrames - 1) / duration;
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset(
            '${spaceAssets}background_sky.png',
            fit: BoxFit.cover,
            cacheWidth: 768,
          ),
        ),
        ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              result.won ? 'Tuyệt lắm, phi công nhỏ!' : 'Thử lại nhé!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF183047),
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
            Center(
              child: MayMascot(
                size: 125,
                animation: result.won
                    ? MayAnimation.memeLaugh
                    : MayAnimation.incorrectEncourage,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  SpaceSprite(
                    i < result.stars ? 'star_full' : 'star_empty',
                    config: widget.config,
                    width: 52,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SpacePanel(
              config: widget.config,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Text(
                _engine.practice
                    ? 'Bài tập có hướng dẫn • nhận 1 sao, không tính độ chính xác độc lập.'
                    : '${result.hearts} tim • ${(result.accuracy * 100).round()}% chọn nghĩa đúng\n'
                          'Đây là kết quả học trong game, không phải độ chính xác mô hình E4.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF183047),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
            if (_saving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _saveError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFA62832),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            for (final word in result.words)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SpacePanel(
                  config: widget.config,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              word.english,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF183047),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              word.vietnamese,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2B5678),
                              ),
                            ),
                            if (errors.contains(word.id))
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Text(
                                  'Cần ôn thêm',
                                  style: TextStyle(
                                    color: Color(0xFFA62832),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        height: 52,
                        child: SpaceButton(
                          config: widget.config,
                          sprite: 'ammo_selected',
                          height: 52,
                          label: 'Nghe',
                          onPressed: () => _speak(word.english),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            SpaceButton(
              config: widget.config,
              height: 58,
              label: 'Chơi lại',
              onPressed: _saving ? null : _retry,
            ),
            const SizedBox(height: 12),
            SpaceButton(
              config: widget.config,
              height: 58,
              sprite: 'ammo_selected',
              label: 'Về bản đồ',
              onPressed: _saving ? null : () => Navigator.pop(context),
            ),
            if (fps != null && p95 != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  'Đo trên $_device: ${fps.toStringAsFixed(1)} FPS khung hình Flutter; '
                  'build+raster p95 ${p95.toStringAsFixed(1)} ms (${sorted.length} mẫu). '
                  'Chỉ gameplay đang hoạt động kể từ lần tiếp tục gần nhất; không gồm TTS/lưu dữ liệu.',
                  style: const TextStyle(
                    color: Color(0xFF183047),
                    fontSize: 11,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SchedulerBinding.instance.removeTimingsCallback(_timings);
    _ticker.dispose();
    _engine.hud.removeListener(_onHud);
    _engine.dispose();
    unawaited(_stopAudio());
    super.dispose();
  }
}
