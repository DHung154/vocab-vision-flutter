import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import 'may_mascot.dart';

typedef MayNowProvider = DateTime Function();

class MayCornerOverlay extends StatefulWidget {
  const MayCornerOverlay({
    super.key,
    this.enabled = true,
    this.eligible = true,
    this.suppressed = false,
    this.reduceMotion = false,
    this.soundEnabled = false,
    this.size = 120,
    this.margin = const EdgeInsets.only(right: 12, bottom: 12),
    this.minDelay = const Duration(seconds: 60),
    this.maxDelay = const Duration(seconds: 120),
    this.stayDuration = const Duration(seconds: 10),
    this.easterEggCooldown = const Duration(minutes: 5),
    this.random,
    this.now,
    this.debugForceEasterEgg = false,
    this.debugFastSchedule = false,
    this.onTapped,
    this.onClosed,
    this.onRequestPlaySound,
    this.onStopSound,
  });

  final bool enabled;
  final bool eligible;
  final bool suppressed;
  final bool reduceMotion;
  final bool soundEnabled;
  final double size;
  final EdgeInsets margin;
  final Duration minDelay;
  final Duration maxDelay;
  final Duration stayDuration;
  final Duration easterEggCooldown;
  final Random? random;
  final MayNowProvider? now;
  final bool debugForceEasterEgg;
  final bool debugFastSchedule;
  final VoidCallback? onTapped;
  final VoidCallback? onClosed;
  final VoidCallback? onRequestPlaySound;
  final VoidCallback? onStopSound;

  @override
  State<MayCornerOverlay> createState() => _MayCornerOverlayState();
}

class _MayCornerOverlayState extends State<MayCornerOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _slideController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  Random get _rng => widget.random ?? _internalRandom;
  DateTime Function() get _now => widget.now ?? DateTime.now;

  final Random _internalRandom = Random();
  Timer? _scheduleTimer;
  Timer? _hideTimer;
  bool _visible = false;
  bool _hiding = false;
  bool _appForeground = true;
  bool _isEasterEgg = false;
  DateTime? _lastEasterEggAt;
  MayAnimation _currentAnimation = MayAnimation.overlayWave;
  String _bubbleText = 'Học tiếp nhé!';
  int _replayId = 0;

  bool get _canSchedule =>
      widget.enabled &&
      widget.eligible &&
      !widget.suppressed &&
      !widget.reduceMotion &&
      _appForeground;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.1, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _slideController,
            curve: Curves.easeOutBack,
            reverseCurve: Curves.easeIn,
          ),
        );
    _fadeAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _scheduleNextIfNeeded();
  }

  @override
  void didUpdateWidget(covariant MayCornerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_canSchedule) {
      _cancelAllTimers();
      if (_visible) {
        _hide(immediate: false);
      }
      return;
    }
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.eligible != widget.eligible ||
        oldWidget.suppressed != widget.suppressed ||
        oldWidget.debugFastSchedule != widget.debugFastSchedule) {
      _scheduleNextIfNeeded(forceReschedule: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appForeground = state == AppLifecycleState.resumed;
    if (!_appForeground) {
      _cancelAllTimers();
      if (_visible) {
        _hide(immediate: true);
      }
    } else {
      _scheduleNextIfNeeded(forceReschedule: true);
    }
  }

  void _cancelAllTimers() {
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _scheduleNextIfNeeded({bool forceReschedule = false}) {
    if (!_canSchedule || _visible) return;
    if (_scheduleTimer != null && !forceReschedule) return;
    _scheduleTimer?.cancel();
    final minDelay = widget.debugFastSchedule
        ? const Duration(seconds: 3)
        : widget.minDelay;
    final maxDelay = widget.debugFastSchedule
        ? const Duration(seconds: 7)
        : widget.maxDelay;
    final delay = _randomDuration(minDelay, maxDelay);
    _scheduleTimer = Timer(delay, () {
      _scheduleTimer = null;
      if (!_canSchedule || _visible) return;
      _showOverlay();
    });
  }

  Duration _randomDuration(Duration min, Duration max) {
    if (max <= min) return min;
    final spanMs = max.inMilliseconds - min.inMilliseconds;
    return Duration(
      milliseconds: min.inMilliseconds + _rng.nextInt(spanMs + 1),
    );
  }

  bool get _easterEggAllowed {
    if (_lastEasterEggAt == null) return true;
    return _now().difference(_lastEasterEggAt!) >= widget.easterEggCooldown;
  }

  void _showOverlay() {
    _isEasterEgg =
        widget.debugForceEasterEgg ||
        (_easterEggAllowed && _rng.nextDouble() < 0.10);
    if (_isEasterEgg) {
      _lastEasterEggAt = _now();
      const choices = [
        MayAnimation.easterEgg,
        MayAnimation.memeSurprised,
        MayAnimation.memeLaugh,
      ];
      _currentAnimation = choices[_rng.nextInt(choices.length)];
      _bubbleText = 'Bất ngờ chưa! 🎤';
      if (widget.soundEnabled) {
        widget.onRequestPlaySound?.call();
      }
    } else {
      final normalChoices = <MayAnimation>[
        MayAnimation.overlayWave,
        MayAnimation.greetWave,
        MayAnimation.idle,
      ];
      _currentAnimation = normalChoices[_rng.nextInt(normalChoices.length)];
      _bubbleText = <String>[
        'Xin chào!',
        'Học cùng Mây nhé!',
        'Mây ghé thăm nè!',
        'Cố lên nhé!',
      ][_rng.nextInt(4)];
    }
    setState(() {
      _visible = true;
      _replayId++;
    });
    _slideController.forward(from: 0);
    _hideTimer?.cancel();
    _hideTimer = Timer(widget.stayDuration, () => _hide(immediate: false));
  }

  void _hide({required bool immediate}) {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (!_visible || _hiding) return;
    _hiding = true;
    Future<void> finish() async {
      if (!mounted) return;
      if (_isEasterEgg) widget.onStopSound?.call();
      setState(() {
        _visible = false;
        _hiding = false;
        _isEasterEgg = false;
      });
      widget.onClosed?.call();
      _scheduleNextIfNeeded(forceReschedule: true);
    }

    if (immediate) {
      _slideController.value = 0;
      finish();
      return;
    }
    _slideController.reverse().whenComplete(finish);
  }

  void _handleMascotCompleted(MayAnimation finished) {
    if (!_visible) return;
    if (_isEasterEgg) {
      setState(() {
        _currentAnimation = finished;
        _replayId++;
      });
      return;
    }
    if (finished != MayAnimation.idle) {
      setState(() {
        _currentAnimation = MayAnimation.idle;
        _replayId++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: widget.margin,
        child: Align(
          alignment: Alignment.bottomRight,
          child: IgnorePointer(
            ignoring: !_visible,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: RepaintBoundary(
                  child: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: widget.size * 1.55,
                      height: widget.size * 1.55,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: <Widget>[
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                widget.onTapped?.call();
                                if (_visible && !_isEasterEgg) {
                                  setState(() {
                                    _currentAnimation =
                                        MayAnimation.overlayWave;
                                    _replayId++;
                                  });
                                }
                              },
                              child: Semantics(
                                button: true,
                                label: 'Mascot Mây',
                                child: MayMascot(
                                  animation: _currentAnimation,
                                  replayId: _replayId,
                                  size: widget.size,
                                  visible: _visible,
                                  reduceMotion: widget.reduceMotion,
                                  autoReturnToIdle: true,
                                  onCompleted: _handleMascotCompleted,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            top: 8,
                            right: 40,
                            child: _OverlayBubble(text: _bubbleText),
                          ),
                          Positioned(
                            top: 8,
                            right: 6,
                            child: Semantics(
                              button: true,
                              label: 'Đóng mascot',
                              child: GestureDetector(
                                onTap: () => _hide(immediate: false),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFB8D8F8),
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Color(0xFF2B4C73),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.onStopSound?.call();
    WidgetsBinding.instance.removeObserver(this);
    _cancelAllTimers();
    _slideController.dispose();
    super.dispose();
  }
}

class _OverlayBubble extends StatelessWidget {
  const _OverlayBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: text,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFB8D8F8), width: 2),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x16000000),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2B4C73),
            ),
          ),
        ),
      ),
    );
  }
}
