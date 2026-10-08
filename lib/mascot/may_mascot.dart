import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const String _mayAssetBasePath = 'assets/mascot/may/';

/// Available mascot clips shipped in assets/mascot/may/expressions_v3.json.
enum MayAnimation {
  idle,
  greetWave,
  correctJump,
  correctThumbs,
  correctClap,
  correctVictory,
  incorrectEncourage,
  completeCelebrate,
  loading,
  thinking,
  encourage,
  overlayWave,
  easterEgg,
  memeSurprised,
  memeLaugh,
  memePout,
}

extension MayAnimationKey on MayAnimation {
  String get clipKey {
    switch (this) {
      case MayAnimation.idle:
        return 'idle';
      case MayAnimation.greetWave:
        return 'greet_wave';
      case MayAnimation.correctJump:
        return 'correct_jump';
      case MayAnimation.correctThumbs:
        return 'correct_thumbs';
      case MayAnimation.correctClap:
        return 'correct_clap';
      case MayAnimation.correctVictory:
        return 'correct_victory';
      case MayAnimation.incorrectEncourage:
        return 'incorrect_encourage';
      case MayAnimation.completeCelebrate:
        return 'complete_celebrate';
      case MayAnimation.loading:
        return 'loading';
      case MayAnimation.thinking:
        return 'thinking';
      case MayAnimation.encourage:
        return 'encourage';
      case MayAnimation.overlayWave:
        return 'overlay_wave';
      case MayAnimation.easterEgg:
        return 'easter_egg';
      case MayAnimation.memeSurprised:
        return 'meme_surprised';
      case MayAnimation.memeLaugh:
        return 'meme_laugh';
      case MayAnimation.memePout:
        return 'meme_pout';
    }
  }

  bool get isLoopingPreferred {
    switch (this) {
      case MayAnimation.idle:
      case MayAnimation.loading:
      case MayAnimation.thinking:
        return true;
      default:
        return false;
    }
  }
}

class MayClipData {
  const MayClipData({
    required this.asset,
    required this.frameWidth,
    required this.frameHeight,
    required this.rows,
    required this.columns,
    required this.frames,
    required this.fps,
    required this.loop,
    required this.category,
    this.poses = const [],
  });

  factory MayClipData.fromJson(Map<String, dynamic> json) {
    return MayClipData(
      asset: json['asset'] as String,
      frameWidth: (json['frameWidth'] as num).toDouble(),
      frameHeight: (json['frameHeight'] as num).toDouble(),
      rows: json['rows'] as int,
      columns: json['columns'] as int,
      frames: json['frames'] as int,
      fps: json['fps'] as int,
      loop: json['loop'] as bool,
      category: (json['category'] ?? 'runtime') as String,
      poses: (json['poses'] as List<dynamic>? ?? const []).cast<int>(),
    );
  }

  final String asset;
  final double frameWidth;
  final double frameHeight;
  final int rows;
  final int columns;
  final int frames;
  final int fps;
  final bool loop;
  final String category;
  final List<int> poses;
}

/// Shared manifest + decoded image cache with a small LRU cap.
class MaySpriteRepository {
  MaySpriteRepository._();

  static final MaySpriteRepository instance = MaySpriteRepository._();

  static const int _maxDecodedImages = 8;

  Future<Map<String, MayClipData>>? _manifestFuture;
  final LinkedHashMap<String, ui.Image> _imageCache =
      LinkedHashMap<String, ui.Image>();
  final Map<String, Future<ui.Image>> _pending = <String, Future<ui.Image>>{};

  Future<Map<String, MayClipData>> _loadManifest() {
    return _manifestFuture ??= () async {
      final raw = await rootBundle.loadString(
        '${_mayAssetBasePath}expressions_v3.json',
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final animations = decoded['animations'] as Map<String, dynamic>;
      final result = <String, MayClipData>{};
      animations.forEach((key, value) {
        result[key] = MayClipData.fromJson(value as Map<String, dynamic>);
      });
      return result;
    }();
  }

  Future<MayClipData> clipFor(MayAnimation animation) async {
    final manifest = await _loadManifest();
    final clip = manifest[animation.clipKey];
    if (clip == null) {
      throw StateError(
        'Animation ${animation.clipKey} not found in animations.json',
      );
    }
    return clip;
  }

  Future<ui.Image> imageForAsset(String asset) {
    final cached = _imageCache.remove(asset);
    if (cached != null) {
      _imageCache[asset] = cached;
      return SynchronousFuture<ui.Image>(cached.clone());
    }
    final pending = _pending[asset];
    if (pending != null) return pending.then((image) => image.clone());

    final future = _decodeAsset(asset).then((image) {
      _pending.remove(asset);
      _imageCache[asset] = image;
      while (_imageCache.length > _maxDecodedImages) {
        final oldestKey = _imageCache.keys.first;
        final oldest = _imageCache.remove(oldestKey);
        oldest?.dispose();
      }
      return image;
    });
    _pending[asset] = future;
    return future.then((image) => image.clone());
  }

  Future<ui.Image> imageFor(MayAnimation animation) async {
    final clip = await clipFor(animation);
    return imageForAsset(clip.asset);
  }

  Future<ui.Image> _decodeAsset(String asset) async {
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  }

  void clear() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
  }
}

class MayMascot extends StatefulWidget {
  const MayMascot({
    super.key,
    this.animation = MayAnimation.idle,
    this.idleAnimation = MayAnimation.idle,
    this.size = 160,
    this.enabled = true,
    this.visible = true,
    this.reduceMotion = false,
    this.replayId = 0,
    this.autoReturnToIdle = true,
    this.onCompleted,
  });

  final MayAnimation animation;
  final MayAnimation idleAnimation;
  final double size;
  final bool enabled;
  final bool visible;
  final bool reduceMotion;

  /// Change [replayId] to force the same animation to replay.
  final int replayId;
  final bool autoReturnToIdle;
  final ValueChanged<MayAnimation>? onCompleted;

  @override
  State<MayMascot> createState() => _MayMascotState();
}

class _MayMascotState extends State<MayMascot> with WidgetsBindingObserver {
  final ValueNotifier<int> _frameNotifier = ValueNotifier<int>(0);
  final MaySpriteRepository _repository = MaySpriteRepository.instance;

  Timer? _timer;
  MayAnimation _displayedAnimation = MayAnimation.idle;
  MayClipData? _clip;
  ui.Image? _image;
  bool _appForeground = true;
  bool _tickerModeEnabled = true;
  bool _systemReduceMotion = false;
  int _loadToken = 0;
  int _lastReplayId = 0;
  Object? _error;

  bool get _canAnimate {
    return widget.enabled &&
        widget.visible &&
        _appForeground &&
        _tickerModeEnabled &&
        !(widget.reduceMotion || _systemReduceMotion);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _displayedAnimation = widget.animation;
    _lastReplayId = widget.replayId;
    _prepareAnimation(_displayedAnimation, restartFrame: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickerModeEnabled = TickerMode.valuesOf(context).enabled;
    _systemReduceMotion = MediaQuery.disableAnimationsOf(context);
    _updateTimer();
  }

  @override
  void didUpdateWidget(covariant MayMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    final shouldRestart =
        widget.animation != oldWidget.animation ||
        widget.replayId != _lastReplayId;
    if (shouldRestart) {
      _lastReplayId = widget.replayId;
      _displayedAnimation = widget.animation;
      _prepareAnimation(_displayedAnimation, restartFrame: true);
    } else if (widget.enabled != oldWidget.enabled ||
        widget.visible != oldWidget.visible ||
        widget.reduceMotion != oldWidget.reduceMotion ||
        widget.size != oldWidget.size) {
      _updateTimer();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    _updateTimer();
  }

  Future<void> _prepareAnimation(
    MayAnimation animation, {
    required bool restartFrame,
  }) async {
    _timer?.cancel();
    if (restartFrame) {
      _frameNotifier.value = 0;
    }
    final int token = ++_loadToken;
    try {
      final clip = await _repository.clipFor(animation);
      final image = await _repository.imageForAsset(clip.asset);
      if (!mounted || token != _loadToken) {
        image.dispose();
        return;
      }
      setState(() {
        _image?.dispose();
        _clip = clip;
        _image = image;
        _error = null;
      });
      _updateTimer();
    } catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _error = error;
      });
    }
  }

  void _updateTimer() {
    _timer?.cancel();
    _timer = null;
    final clip = _clip;
    if (clip == null || !_canAnimate) return;
    if (widget.reduceMotion || _systemReduceMotion) {
      _frameNotifier.value = 0;
      return;
    }
    _timer = Timer.periodic(
      Duration(microseconds: (1000000 / clip.fps).round()),
      (_) => _tick(),
    );
  }

  void _tick() {
    final clip = _clip;
    if (clip == null) return;
    final next = _frameNotifier.value + 1;
    if (next < clip.frames) {
      _frameNotifier.value = next;
      return;
    }

    if (clip.loop) {
      _frameNotifier.value = 0;
      return;
    }

    final completed = _displayedAnimation;
    _timer?.cancel();
    _frameNotifier.value = clip.frames - 1;
    widget.onCompleted?.call(completed);
    if (widget.autoReturnToIdle && completed != widget.idleAnimation) {
      _displayedAnimation = widget.idleAnimation;
      _prepareAnimation(_displayedAnimation, restartFrame: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = Size.square(widget.size);
    if (!widget.visible) return SizedBox.fromSize(size: size);

    if (_clip == null || _image == null) {
      return RepaintBoundary(
        child: SizedBox.fromSize(
          size: size,
          child: _error == null ? null : const Icon(Icons.cloud_outlined),
        ),
      );
    }

    return RepaintBoundary(
      child: CustomPaint(
        size: size,
        painter: _MaySpritePainter(
          image: _image!,
          clip: _clip!,
          frame: _frameNotifier,
          staticPose: !_canAnimate,
          animation: _displayedAnimation,
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _loadToken++;
    _timer?.cancel();
    _frameNotifier.dispose();
    _image?.dispose();
    super.dispose();
  }
}

class _MaySpritePainter extends CustomPainter {
  _MaySpritePainter({
    required this.image,
    required this.clip,
    required this.frame,
    required this.staticPose,
    required this.animation,
  }) : super(repaint: frame);

  final ui.Image image;
  final MayClipData clip;
  final ValueListenable<int> frame;
  final bool staticPose;
  final MayAnimation animation;

  @override
  void paint(Canvas canvas, Size size) {
    if (clip.category == 'procedural' || clip.category == 'pose_atlas') {
      _paintCleanCharacter(canvas, size);
      return;
    }
    final int currentFrame = staticPose
        ? 0
        : frame.value.clamp(0, clip.frames - 1);
    final int column = currentFrame % clip.columns;
    final int row = currentFrame ~/ clip.columns;
    final Rect src = Rect.fromLTWH(
      column * clip.frameWidth.toDouble(),
      row * clip.frameHeight.toDouble(),
      clip.frameWidth.toDouble(),
      clip.frameHeight.toDouble(),
    );
    final Rect dst = Offset.zero & size;
    canvas.drawImageRect(
      image,
      src,
      dst,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  // Select a clean illustrated pose and add small procedural motion.
  // Meme clips use their own bust atlas; normal clips keep the full-body atlas.
  void _paintCleanCharacter(Canvas canvas, Size size) {
    final p = staticPose ? 0.0 : frame.value / math.max(1, clip.frames - 1);
    final pulse = math.sin(p * math.pi);
    var dy = 0.0;
    var dx = 0.0;
    var rotation = 0.0;
    var scale = 1.0;
    if (!staticPose) {
      switch (animation) {
        case MayAnimation.correctJump:
        case MayAnimation.completeCelebrate:
          dy = -size.height * 0.12 * pulse;
          rotation = math.sin(p * math.pi * 2) * 0.07;
          break;
        case MayAnimation.correctThumbs:
          scale = 1 + pulse * 0.06;
          rotation = pulse * -0.07;
          break;
        case MayAnimation.correctClap:
          dy = -math.sin(p * math.pi * 3).abs() * size.height * 0.04;
          break;
        case MayAnimation.correctVictory:
          dy = -pulse * size.height * 0.08;
          rotation = math.sin(p * math.pi * 2) * 0.13;
          break;
        case MayAnimation.greetWave:
        case MayAnimation.overlayWave:
          rotation = math.sin(p * math.pi * 4) * 0.07;
          dy = -pulse * size.height * 0.025;
          break;
        case MayAnimation.incorrectEncourage:
          rotation = math.sin(p * math.pi * 4) * 0.025 * (1 - p);
          dy = pulse * size.height * 0.015;
          break;
        case MayAnimation.easterEgg:
          dx = math.sin(p * math.pi * 4) * size.width * 0.07;
          dy = -math.sin(p * math.pi * 4).abs() * size.height * 0.06;
          rotation = math.sin(p * math.pi * 4) * 0.12;
          break;
        case MayAnimation.memeSurprised:
          scale = 1 + pulse * 0.06;
          rotation = math.sin(p * math.pi * 2) * 0.025;
          break;
        case MayAnimation.memeLaugh:
          dy = -math.sin(p * math.pi * 6).abs() * size.height * 0.025;
          rotation = math.sin(p * math.pi * 4) * 0.04;
          break;
        case MayAnimation.memePout:
          rotation = math.sin(p * math.pi * 4) * 0.02;
          break;
        case MayAnimation.thinking:
          rotation = pulse * 0.045;
          break;
        case MayAnimation.encourage:
          dy = math.sin(p * math.pi * 4) * size.height * 0.015;
          break;
        case MayAnimation.idle:
        case MayAnimation.loading:
          scale = 1 + pulse * 0.012;
          break;
      }
    }
    canvas.save();
    canvas.translate(size.width / 2 + dx, size.height * 0.88 + dy);
    canvas.rotate(rotation);
    canvas.scale(scale);
    canvas.translate(-size.width / 2, -size.height * 0.88);
    final pose = clip.poses.isEmpty
        ? 0
        : clip.poses[(staticPose ? 0 : frame.value).clamp(
            0,
            clip.poses.length - 1,
          )];
    final atlas = image;
    final columns = clip.columns;
    final rows = clip.rows;
    final index = pose;
    final width = atlas.width / columns;
    final height = atlas.height / rows;
    canvas.drawImageRect(
      atlas,
      Rect.fromLTWH(
        (index % columns) * width,
        (index ~/ columns) * height,
        width,
        height,
      ),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
    if (animation == MayAnimation.easterEgg && clip.category != 'pose_atlas') {
      // Props stay clear of the clean eyes; no second face is painted.
      final paint = Paint()..color = const Color(0xFF263648);
      canvas.drawLine(
        Offset(size.width * 0.73, size.height * 0.56),
        Offset(size.width * 0.69, size.height * 0.64),
        paint..strokeWidth = size.width * 0.025,
      );
      canvas.drawCircle(
        Offset(size.width * 0.74, size.height * 0.54),
        size.width * 0.035,
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MaySpritePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.clip != clip ||
        oldDelegate.staticPose != staticPose ||
        oldDelegate.animation != animation;
  }
}
