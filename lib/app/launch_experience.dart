import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/media/display_image.dart';

const launchPaper = Color(0xFFFFF8ED);
const launchBlue = Color(0xFF155BB5);
const vocabLogoAsset = 'assets/brand/vocab_vision_logo.png';

/// A single cold-launch curtain. The destination stays mounted and stationary
/// while this opaque layer paints in, then translates completely off screen.
class LaunchExperience extends StatefulWidget {
  const LaunchExperience({
    super.key,
    required this.ready,
    required this.child,
    this.onLogoReady,
  });

  final bool ready;
  final Widget child;
  final VoidCallback? onLogoReady;

  @override
  State<LaunchExperience> createState() => _LaunchExperienceState();
}

class _LaunchExperienceState extends State<LaunchExperience>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _exit;
  Timer? _staticHold;
  bool _started = false;
  bool _minimumElapsed = false;
  bool _dismissed = false;
  bool _reduceMotion = false;
  bool _exiting = false;
  late ImageProvider<Object> _logoImage;

  @override
  void initState() {
    super.initState();
    _intro =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2300),
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            _minimumElapsed = true;
            _tryExit();
          }
        });
    _exit =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
          animationBehavior: AnimationBehavior.preserve,
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            setState(() => _dismissed = true);
          }
        });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!_started) {
      _started = true;
      _reduceMotion = reduceMotion;
      final markSize = math.min(180.0, MediaQuery.sizeOf(context).width * .46);
      _logoImage = imageForDisplay(
        const AssetImage(vocabLogoAsset),
        Size.square(markSize),
        MediaQuery.devicePixelRatioOf(context),
      );
      // Decode the local mark before starting the paint timeline so the first
      // recognizable logo always precedes the spreading color.
      unawaited(
        precacheImage(_logoImage, context).then((_) {
          if (!mounted || _dismissed) return;
          widget.onLogoReady?.call();
          if (_reduceMotion) {
            _staticHold = Timer(const Duration(milliseconds: 350), () {
              _minimumElapsed = true;
              _tryExit();
            });
          } else {
            _intro.forward();
          }
        }),
      );
    } else if (reduceMotion && !_reduceMotion && !_dismissed) {
      _reduceMotion = true;
      _intro.stop();
      _exit.stop();
      _staticHold?.cancel();
      _minimumElapsed = true;
      _tryExit();
    }
  }

  @override
  void didUpdateWidget(LaunchExperience oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) {
      // A post-frame exit guarantees the newly ready destination has laid out
      // before even its first pixels can be revealed.
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryExit());
    }
  }

  void _tryExit() {
    if (!mounted || _dismissed || !_minimumElapsed || !widget.ready) return;
    if (_reduceMotion) {
      setState(() => _dismissed = true);
    } else if (!_exiting) {
      _exiting = true;
      _exit.forward();
    }
  }

  @override
  void dispose() {
    _staticHold?.cancel();
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icons = Theme.of(context).brightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;
    // Keep a destination annotation after the curtain is removed. Otherwise
    // Android can retain the intro's light icons on a light page after resume.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        systemNavigationBarIconBrightness: icons,
      ),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return PopScope(
      canPop: _dismissed,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ExcludeSemantics(
            excluding: !_dismissed,
            child: IgnorePointer(
              ignoring: !_dismissed,
              child: TickerMode(
                enabled: _dismissed,
                child: RepaintBoundary(child: widget.child),
              ),
            ),
          ),
          if (!_dismissed)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _exit]),
                builder: (context, _) => LayoutBuilder(
                  builder: (context, constraints) {
                    final paint = _reduceMotion
                        ? 0.0
                        : const Interval(
                            400 / 2300,
                            1400 / 2300,
                            curve: Curves.easeInOutCubic,
                          ).transform(_intro.value);
                    final rise = Curves.easeInOutCubic.transform(_exit.value);
                    final markSize = math.min(
                      180.0,
                      constraints.maxWidth * .46,
                    );
                    final titleColor = Color.lerp(
                      const Color(0xFF123866),
                      Colors.white,
                      paint,
                    )!;
                    return AnnotatedRegion<SystemUiOverlayStyle>(
                      value: SystemUiOverlayStyle(
                        statusBarColor: Colors.transparent,
                        systemNavigationBarColor: Colors.transparent,
                        systemNavigationBarDividerColor: Colors.transparent,
                        statusBarIconBrightness: paint > .5
                            ? Brightness.light
                            : Brightness.dark,
                        systemNavigationBarIconBrightness: paint > .5
                            ? Brightness.light
                            : Brightness.dark,
                      ),
                      child: ClipRect(
                        child: Transform.translate(
                          key: const ValueKey('launch-curtain'),
                          offset: Offset(0, -constraints.maxHeight * rise),
                          child: Semantics(
                            label: 'Vocab Vision đang mở',
                            container: true,
                            liveRegion: true,
                            child: ColoredBox(
                              color: launchPaper,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CustomPaint(
                                    key: const ValueKey('launch-paint'),
                                    painter: LaunchPaintPainter(
                                      progress: paint,
                                    ),
                                  ),
                                  Center(
                                    child: Container(
                                      width: markSize + 24,
                                      height: markSize + 24,
                                      decoration: BoxDecoration(
                                        color: launchPaper,
                                        borderRadius: BorderRadius.circular(48),
                                      ),
                                      child: Center(
                                        child: Image(
                                          image: _logoImage,
                                          key: const ValueKey('launch-logo'),
                                          width: markSize,
                                          height: markSize,
                                          excludeFromSemantics: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top:
                                        constraints.maxHeight / 2 +
                                        markSize / 2 +
                                        32,
                                    left: 24,
                                    right: 24,
                                    child: Opacity(
                                      opacity: _reduceMotion
                                          ? 1
                                          : const Interval(
                                              .18,
                                              .55,
                                              curve: Curves.easeOut,
                                            ).transform(_intro.value),
                                      child: Text(
                                        'Vocab Vision',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineMedium!
                                            .copyWith(
                                              fontSize: 30,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: -.8,
                                              color: titleColor,
                                              decoration: TextDecoration.none,
                                            ),
                                      ),
                                    ),
                                  ),
                                  if (_minimumElapsed && !widget.ready)
                                    Positioned(
                                      bottom: 64,
                                      left: 24,
                                      right: 24,
                                      child: Text(
                                        'Đang chuẩn bị buổi học…',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium!
                                            .copyWith(
                                              fontSize: 14,
                                              color: titleColor,
                                              decoration: TextDecoration.none,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A stable organic edge, with a solid fill rather than transparency. The
/// maximum radius exceeds the furthest corner even at the edge's smallest lobe.
class LaunchPaintPainter extends CustomPainter {
  const LaunchPaintPainter({required this.progress});

  final double progress;
  static final _edge = List<Offset>.generate(181, (index) {
    final angle = index / 180 * math.pi * 2;
    final radius =
        1 + .055 * math.sin(5 * angle + .8) + .035 * math.sin(3 * angle - .4);
    return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  }, growable: false);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()..color = launchBlue;
    if (progress >= 1) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }
    final center = size.center(Offset.zero);
    final radius =
        math.sqrt(size.width * size.width + size.height * size.height) /
        2 *
        1.2 *
        progress;
    final path = Path();
    for (var index = 0; index < _edge.length; index++) {
      final point = center + _edge[index] * radius;
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(LaunchPaintPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
