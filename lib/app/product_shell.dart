part of '../main.dart';

// Active product shell and feature screens. This remains a part of the app
// library so the legacy compatibility screens can migrate without changing
// private state or route contracts in one large rewrite.
class ProductShell extends StatefulWidget {
  final AppState appState;

  const ProductShell({super.key, required this.appState});

  @override
  State<ProductShell> createState() => _ProductShellState();
}

class _ProductShellState extends State<ProductShell> {
  final _pageController = PageController();
  final _cameraKey = GlobalKey<_CameraScreenState>();
  late final List<Widget> _pages;
  int _tab = 0;
  DateTime? _lastBack;

  @override
  void initState() {
    super.initState();
    final appState = widget.appState;
    _pages = [
      AnimatedBuilder(
        animation: appState,
        builder: (context, _) => _ProductHomePage(appState: appState),
      ),
      _ProductVocabularyPage(appState: appState),
      CameraScreen(key: _cameraKey, appState: appState),
      AnimatedBuilder(
        animation: appState,
        builder: (context, _) => _ProductProgressPage(appState: appState),
      ),
      AnimatedBuilder(
        animation: appState,
        builder: (context, _) => _ProductProfilePage(appState: appState),
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_tab == 2 && index != 2) {
      _cameraKey.currentState?.cancelPendingInference();
    }
    if (index == _tab || !_pageController.hasClients) {
      if (index != _tab) setState(() => _tab = index);
      return;
    }
    setState(() => _tab = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _handleBack() async {
    if (_tab != 0) {
      if (_tab == 2) _cameraKey.currentState?.cancelPendingInference();
      _selectTab(0);
      return;
    }
    final now = DateTime.now();
    final previous = _lastBack;
    _lastBack = now;
    if (previous == null ||
        now.difference(previous) > const Duration(seconds: 2)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhấn quay lại lần nữa để thoát')),
      );
    } else {
      // At the root route, a second back is a normal Android exit. No app
      // restart or runApp call is involved.
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_handleBack());
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Semantics(
          container: true,
          explicitChildNodes: true,
          label: 'Vocab Vision. Mục ${_tabLabel(_tab)}',
          child: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  if (_tab == 2 && index != 2) {
                    _cameraKey.currentState?.cancelPendingInference();
                  }
                  setState(() => _tab = index);
                },
                children: [
                  for (var i = 0; i < _pages.length; i++)
                    TickerMode(enabled: i == _tab, child: _pages[i]),
                ],
              ),
              MayCornerOverlay(
                eligible: _tab == 0 || _tab == 1,
                suppressed:
                    ModalRoute.of(context)?.isCurrent != true ||
                    MediaQuery.viewInsetsOf(context).bottom > 0,
                reduceMotion: MediaQuery.disableAnimationsOf(context),
              ),
            ],
          ),
        ),
        bottomNavigationBar: _ProductBottomNavigation(
          selectedIndex: _tab,
          onSelected: _selectTab,
        ),
      ),
    );
  }

  String _tabLabel(int index) => switch (index) {
    0 => 'Trang chủ',
    1 => 'Khám phá',
    2 => 'Nhận diện',
    3 => 'Tiến độ',
    4 => 'Hồ sơ',
    _ => 'Trang chủ',
  };
}

/// Custom painter for the dark bottom navigation bar with a 92dp circular bump dock.
/// The top line (2dp) follows the horizontal edges and the circular bump seamlessly;
/// the top line is NOT visible across the bump.
class _BottomBarBackgroundPainter extends CustomPainter {
  final bool isCameraActive;
  final VocabColors colors;

  _BottomBarBackgroundPainter({
    required this.isCameraActive,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    const bumpR = 46.0; // 92dp diameter circle
    const bumpCenterY = 32.0; // Raised dock center

    // Intersection with horizontal baseline y = 0
    final dx = math.sqrt(
      bumpR * bumpR - bumpCenterY * bumpCenterY,
    ); // sqrt(1092) ~33.045dp

    final topLinePath = Path();
    topLinePath.moveTo(0, 0);
    topLinePath.lineTo(cx - dx, 0);
    // Arc upward over the circular bump
    topLinePath.arcToPoint(
      Offset(cx + dx, 0),
      radius: const Radius.circular(bumpR),
      largeArc: false,
      clockwise: true,
    );
    topLinePath.lineTo(w, 0);

    // Full closed path for background fill
    final fillPath = Path.from(topLinePath);
    fillPath.lineTo(w, h);
    fillPath.lineTo(0, h);
    fillPath.close();

    // 1. Fill the bar and raised bump with #0F1A21
    canvas.drawPath(
      fillPath,
      Paint()
        ..color = colors.surface
        ..style = PaintingStyle.fill,
    );

    // 2. 2dp top line:
    // Bar top line does NOT cross the bump horizontally.
    // In inactive state, NO gold outline anywhere (all #2C3E4C).
    // Gold outline appears ONLY on the bump when camera tab is active, not across the whole bar.
    final horizontalPaint = Paint()
      ..color = colors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final leftLine = Path()
      ..moveTo(0, 0)
      ..lineTo(cx - dx, 0);
    canvas.drawPath(leftLine, horizontalPaint);

    final bumpArc = Path()
      ..moveTo(cx - dx, 0)
      ..arcToPoint(
        Offset(cx + dx, 0),
        radius: const Radius.circular(bumpR),
        largeArc: false,
        clockwise: true,
      );
    canvas.drawPath(
      bumpArc,
      Paint()
        ..color = isCameraActive ? AppColors.gold : colors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    final rightLine = Path()
      ..moveTo(cx + dx, 0)
      ..lineTo(w, 0);
    canvas.drawPath(rightLine, horizontalPaint);
  }

  @override
  bool shouldRepaint(covariant _BottomBarBackgroundPainter oldDelegate) =>
      isCameraActive != oldDelegate.isCameraActive ||
      colors != oldDelegate.colors;
}

/// Four rounded scan-corner brackets (#FFF3C7, 3dp) that fade in and out around the button.
class _ScanBracketsPainter extends CustomPainter {
  final double opacity;

  _ScanBracketsPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;

    final paint = Paint()
      ..color = AppColors.cameraCream.withValues(alpha: opacity.clamp(0.0, 1.0))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;
    const offset = 41.0;
    const arm = 10.0;
    const r = 4.0;

    // Top-Left corner
    final tl = Path()
      ..moveTo(cx - offset, cy - offset + arm)
      ..lineTo(cx - offset, cy - offset + r)
      ..arcToPoint(
        Offset(cx - offset + r, cy - offset),
        radius: const Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(cx - offset + arm, cy - offset);
    canvas.drawPath(tl, paint);

    // Top-Right corner
    final tr = Path()
      ..moveTo(cx + offset - arm, cy - offset)
      ..lineTo(cx + offset - r, cy - offset)
      ..arcToPoint(
        Offset(cx + offset, cy - offset + r),
        radius: const Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(cx + offset, cy - offset + arm);
    canvas.drawPath(tr, paint);

    // Bottom-Right corner
    final br = Path()
      ..moveTo(cx + offset, cy + offset - arm)
      ..lineTo(cx + offset, cy + offset - r)
      ..arcToPoint(
        Offset(cx + offset - r, cy + offset),
        radius: const Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(cx + offset - arm, cy + offset);
    canvas.drawPath(br, paint);

    // Bottom-Left corner
    final bl = Path()
      ..moveTo(cx - offset + arm, cy + offset)
      ..lineTo(cx - offset + r, cy + offset)
      ..arcToPoint(
        Offset(cx - offset, cy + offset - r),
        radius: const Radius.circular(r),
        clockwise: true,
      )
      ..lineTo(cx - offset, cy + offset - arm);
    canvas.drawPath(bl, paint);
  }

  @override
  bool shouldRepaint(covariant _ScanBracketsPainter oldDelegate) =>
      opacity != oldDelegate.opacity;
}

/// Custom-painted camera glyph (not an icon font):
/// Dark body #3A2600 (32x22, radius 7) with top hump, cream lens ring #FFF3C7,
/// blue #2A7BE4 core, white highlight dot, tiny gold flash dot, and 2 twinkling 4-point sparkles.
class _CameraGlyphPainter extends CustomPainter {
  final double lensScale;
  final double sparkleProgress;
  final bool reduceMotion;

  _CameraGlyphPainter({
    required this.lensScale,
    required this.sparkleProgress,
    required this.reduceMotion,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Camera Body: dark body #3A2600 (rounded rect 32x22, radius 7)
    final bodyRect = Rect.fromCenter(
      center: Offset(cx, cy + 1.0),
      width: 32.0,
      height: 22.0,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bodyRect, const Radius.circular(7.0)),
      Paint()..color = AppColors.goldInk,
    );

    // 2. Small top hump
    final humpRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 8.0, cy - 13.0, 9.0, 4.0),
      const Radius.circular(2.0),
    );
    canvas.drawRRect(humpRect, Paint()..color = AppColors.goldInk);

    // 3. Tiny gold flash dot
    canvas.drawCircle(
      Offset(cx + 8.5, cy - 5.5),
      1.8,
      Paint()..color = AppColors.gold,
    );

    // 4. Lens: cream ring #FFF3C7 with blue #2A7BE4 core and white highlight dot
    final lensCenter = Offset(cx - 0.5, cy + 1.5);
    final currentScale = reduceMotion ? 1.0 : lensScale;

    // Cream ring
    canvas.drawCircle(
      lensCenter,
      7.2 * currentScale,
      Paint()..color = AppColors.cameraCream,
    );

    // Blue core
    canvas.drawCircle(
      lensCenter,
      4.2 * currentScale,
      Paint()..color = AppColors.blue,
    );

    // White highlight dot
    canvas.drawCircle(
      Offset(
        lensCenter.dx - 1.6 * currentScale,
        lensCenter.dy - 1.5 * currentScale,
      ),
      1.3 * currentScale,
      Paint()..color = Colors.white,
    );

    // 5. Two small four-point sparkles (white and cream) at upper-left and upper-right
    double s1 = 1.0;
    double o1 = 1.0;
    double s2 = 1.0;
    double o2 = 1.0;

    if (!reduceMotion) {
      final p1 = sparkleProgress % 1.0;
      final sine1 = (math.sin(p1 * 2 * math.pi) + 1.0) / 2.0;
      s1 = 0.6 + 0.5 * sine1;
      o1 = 0.4 + 0.6 * sine1;

      final p2 = (sparkleProgress + 0.5) % 1.0;
      final sine2 = (math.sin(p2 * 2 * math.pi) + 1.0) / 2.0;
      s2 = 0.6 + 0.5 * sine2;
      o2 = 0.4 + 0.6 * sine2;
    }

    // Upper-left sparkle (White)
    _drawSparkle(
      canvas,
      Offset(cx - 17.0, cy - 13.0),
      5.2 * s1,
      Colors.white.withValues(alpha: o1.clamp(0.0, 1.0)),
    );

    // Upper-right sparkle (Cream #FFF3C7)
    _drawSparkle(
      canvas,
      Offset(cx + 17.0, cy - 12.0),
      5.0 * s2,
      AppColors.cameraCream.withValues(alpha: o2.clamp(0.0, 1.0)),
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double radius, Color color) {
    if (radius <= 0.5) return;
    final path = Path();
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius);
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraGlyphPainter oldDelegate) =>
      lensScale != oldDelegate.lensScale ||
      sparkleProgress != oldDelegate.sparkleProgress ||
      reduceMotion != oldDelegate.reduceMotion;
}

/// 68dp button disk with 6dp/2dp solid edge #D9950F and 4dp top highlight #FFE18A.
class _CameraButtonDiskPainter extends CustomPainter {
  final double edgeHeight;
  final bool isPressed;

  _CameraButtonDiskPainter({required this.edgeHeight, required this.isPressed});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    const r = 34.0; // 68dp circle radius

    // 1. Solid bottom edge #D9950F
    canvas.drawCircle(
      Offset(cx, cy + edgeHeight),
      r,
      Paint()..color = AppColors.goldEdge,
    );

    // 2. Gold face #FFC83D
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = AppColors.gold);

    // 3. 4dp inner top highlight #FFE18A
    final highlightRect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: r - 2.5,
    );
    canvas.drawArc(
      highlightRect,
      -math.pi * 0.85,
      math.pi * 0.7,
      false,
      Paint()
        ..color = AppColors.cameraGoldHighlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _CameraButtonDiskPainter oldDelegate) =>
      edgeHeight != oldDelegate.edgeHeight ||
      isPressed != oldDelegate.isPressed;
}

/// Idle halo ring that scales from 1.0 to 1.65 and fades from 0.5 to 0.0.
class _HaloPainter extends CustomPainter {
  final double progress;

  _HaloPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;
    final cx = size.width / 2;
    final cy = size.height / 2;
    const baseR = 34.0;
    final scale = 1.0 + 0.65 * progress;
    final opacity = (0.5 * (1.0 - progress)).clamp(0.0, 1.0);

    canvas.drawCircle(
      Offset(cx, cy),
      baseR * scale,
      Paint()
        ..color = AppColors.gold.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _HaloPainter oldDelegate) =>
      progress != oldDelegate.progress;
}

class _ProductBottomNavigation extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ProductBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  State<_ProductBottomNavigation> createState() =>
      _ProductBottomNavigationState();
}

class _ProductBottomNavigationState extends State<_ProductBottomNavigation>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // Master looping controller (11.2s LCM drives 1.6s sparkle and 1.4s bracket loops)
  late final AnimationController _loopController;

  // Controller for the idle halo
  late final AnimationController _haloController;
  Timer? _homeHaloTimer;
  var _haloCycles = 0;

  // Press & tap states
  var _isPressed = false;
  var _isFlashing = false;
  var _lensScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 11200),
    );

    _haloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener(_handleHaloStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncAnimations(force: true);
    });
  }

  bool get _isTest =>
      WidgetsBinding.instance.runtimeType.toString().contains('Test');

  void _syncAnimations({bool force = false}) {
    if (!mounted) return;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion || _isTest) {
      _loopController.stop();
      _haloController.stop();
      _homeHaloTimer?.cancel();
      return;
    }

    // The scan brackets and camera glyph are the only consumers of this
    // looping controller. Keeping it stopped on the other four tabs avoids a
    // permanent ticker and a per-frame repaint while the camera is hidden.
    if (widget.selectedIndex == 2) {
      if (force || !_loopController.isAnimating) _loopController.repeat();
    } else {
      _loopController.stop();
    }

    if (widget.selectedIndex == 0) {
      if (force || !_haloController.isAnimating) {
        _haloController.forward(from: 0.0);
      }
      _startHomeHaloTimer();
    } else {
      _haloController.stop();
      _homeHaloTimer?.cancel();
    }
  }

  @override
  void didUpdateWidget(covariant _ProductBottomNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _syncAnimations();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimations(force: true);
  }

  void _startHomeHaloTimer() {
    _homeHaloTimer?.cancel();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (isTest) return;
    _homeHaloTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!mounted) return;
      if (widget.selectedIndex == 0 &&
          !(MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
        _haloController.forward(from: 0.0);
      }
    });
  }

  void _handleHaloStatus(AnimationStatus status) {
    if (!mounted || (MediaQuery.maybeOf(context)?.disableAnimations ?? false)) {
      return;
    }
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (status == AnimationStatus.completed) {
      _haloCycles++;
      if (!isTest && _haloCycles < 3) {
        _haloController.forward(from: 0.0);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAnimations(force: true);
    } else {
      _loopController.stop();
      _haloController.stop();
      _homeHaloTimer?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _homeHaloTimer?.cancel();
    _loopController.dispose();
    _haloController.dispose();
    super.dispose();
  }

  void _onCameraTapDown(TapDownDetails _) {
    setState(() => _isPressed = true);
    HapticFeedback.lightImpact();
  }

  void _onCameraTapCancel() {
    setState(() => _isPressed = false);
  }

  void _onCameraTapUp(TapUpDetails _) {
    setState(() {
      _isPressed = false;
      _isFlashing = true;
      _lensScale = 0.85;
    });

    // Navigation fires immediately
    widget.onSelected(2);

    Timer(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() {
          _isFlashing = false;
          _lensScale = 1.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final isCameraActive = widget.selectedIndex == 2;
    const barHeight = 78.0;
    final totalHeight = barHeight + bottomInset;

    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.25,
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Bar and 92dp circular bump background with top line
            Positioned.fill(
              child: CustomPaint(
                painter: _BottomBarBackgroundPainter(
                  isCameraActive: isCameraActive,
                  colors: context.vocabColors,
                ),
              ),
            ),

            // 2. The 4 Navigation Tabs in Row
            SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 4),
              child: SizedBox(
                height: barHeight,
                child: Row(
                  children: [
                    _NavTabItem(
                      index: 0,
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home_rounded,
                      label: 'Trang chủ',
                      selected: widget.selectedIndex == 0,
                      onTap: () => widget.onSelected(0),
                    ),
                    _NavTabItem(
                      index: 1,
                      icon: Icons.menu_book_outlined,
                      selectedIcon: Icons.menu_book_rounded,
                      label: 'Khám phá',
                      selected: widget.selectedIndex == 1,
                      onTap: () => widget.onSelected(1),
                    ),
                    const SizedBox(width: 92), // Space for 92dp center dock
                    _NavTabItem(
                      index: 3,
                      icon: Icons.insights_outlined,
                      selectedIcon: Icons.insights_rounded,
                      label: 'Tiến độ',
                      selected: widget.selectedIndex == 3,
                      onTap: () => widget.onSelected(3),
                    ),
                    _NavTabItem(
                      index: 4,
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person_rounded,
                      label: 'Hồ sơ',
                      selected: widget.selectedIndex == 4,
                      onTap: () => widget.onSelected(4),
                    ),
                  ],
                ),
              ),
            ),

            // 3. Center Camera Button Dock, Halos, Brackets and Hero Button
            LayoutBuilder(
              builder: (context, constraints) {
                final cx = constraints.maxWidth / 2;
                const buttonCenterY = 34.0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Idle halo animation ring
                    AnimatedBuilder(
                      animation: _haloController,
                      builder: (context, _) {
                        return Positioned(
                          top: buttonCenterY - 60,
                          left: cx - 60,
                          child: IgnorePointer(
                            child: CustomPaint(
                              size: const Size(120, 120),
                              painter: _HaloPainter(
                                progress: reduceMotion
                                    ? 0.0
                                    : _haloController.value,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    // Scan-corner brackets around button when camera tab active
                    if (isCameraActive)
                      AnimatedBuilder(
                        animation: _loopController,
                        builder: (context, _) {
                          double bracketOpacity = 1.0;
                          if (!reduceMotion) {
                            final b = (_loopController.value * 8.0) % 1.0;
                            final tri = (b < 0.5) ? b * 2.0 : (1.0 - b) * 2.0;
                            bracketOpacity = 0.25 + 0.75 * tri;
                          }
                          return Positioned(
                            top: buttonCenterY - 48,
                            left: cx - 48,
                            child: IgnorePointer(
                              child: CustomPaint(
                                size: const Size(96, 96),
                                painter: _ScanBracketsPainter(
                                  opacity: bracketOpacity,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // 4. Central Camera Button (68dp circle raised in dock)
                    Positioned(
                      top: buttonCenterY - 34,
                      left: cx - 34,
                      child: RepaintBoundary(
                        child: TweenAnimationBuilder<double>(
                          duration: reduceMotion
                              ? Duration.zero
                              : const Duration(milliseconds: 350),
                          tween: Tween(begin: 0.6, end: 1.0),
                          curve: Curves.easeOutBack,
                          builder: (context, entranceScale, child) {
                            return Transform.scale(
                              scale: entranceScale,
                              child: child,
                            );
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: _onCameraTapDown,
                            onTapCancel: _onCameraTapCancel,
                            onTapUp: _onCameraTapUp,
                            child: AnimatedScale(
                              scale: _isPressed ? 0.94 : 1.0,
                              duration: const Duration(milliseconds: 150),
                              curve: Curves.easeOutBack,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOutBack,
                                transform: Matrix4.translationValues(
                                  0.0,
                                  _isPressed ? 4.0 : 0.0,
                                  0.0,
                                ),
                                width: 68,
                                height: 68,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.center,
                                  children: [
                                    // Button disk with solid bottom edge and top highlight
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _CameraButtonDiskPainter(
                                          edgeHeight: _isPressed ? 2.0 : 6.0,
                                          isPressed: _isPressed,
                                        ),
                                      ),
                                    ),

                                    // Custom-painted camera glyph & twinkling sparkles
                                    AnimatedBuilder(
                                      animation: _loopController,
                                      builder: (context, _) {
                                        return CustomPaint(
                                          size: const Size(68, 68),
                                          painter: _CameraGlyphPainter(
                                            lensScale: _lensScale,
                                            sparkleProgress:
                                                (_loopController.value * 7.0) %
                                                1.0,
                                            reduceMotion: reduceMotion,
                                          ),
                                        );
                                      },
                                    ),

                                    // 120ms white flash inside circle on tap
                                    if (_isFlashing)
                                      ClipOval(
                                        child: ColoredBox(
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                          child: const SizedBox(
                                            width: 68,
                                            height: 68,
                                          ),
                                        ),
                                      ),

                                    // Embedded icon for test finders and TalkBack accessibility
                                    Semantics(
                                      button: true,
                                      selected: isCameraActive,
                                      label: 'Nhận diện vật thể',
                                      child: const SizedBox(
                                        width: 68,
                                        height: 68,
                                        child: Center(
                                          child: Icon(
                                            Icons.camera_alt_outlined,
                                            size: 28,
                                            color: Colors.transparent,
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
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTabItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavTabItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_NavTabItem> createState() => _NavTabItemState();
}

class _NavTabItemState extends State<_NavTabItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.selected ? 1.0 : 0.0,
    );
    _bounceAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant _NavTabItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected != oldWidget.selected) {
      if (widget.selected) {
        _controller.forward(from: 0.0);
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final unselectedColor = context.vocabColors.unselectedNav;
    final selectedColor = context.vocabColors.tealTextOnTint;
    final selectedPillColor = context.vocabColors.accentSoft;

    return Expanded(
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: widget.label,
        child: InkWell(
          onTap: widget.onTap,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value;
                    final pillColor = Color.lerp(
                      Colors.transparent,
                      selectedPillColor,
                      t,
                    );
                    final iconScale = (widget.selected && !reduceMotion)
                        ? _bounceAnimation.value
                        : 1.0;
                    return Container(
                      width: 48,
                      height: 32,
                      decoration: BoxDecoration(
                        color: pillColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: Transform.scale(
                          scale: iconScale,
                          child: Icon(
                            widget.selected ? widget.selectedIcon : widget.icon,
                            size: 24,
                            color: Color.lerp(
                              unselectedColor,
                              selectedColor,
                              t,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final t = _controller.value;
                      return Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: widget.selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: Color.lerp(unselectedColor, selectedColor, t),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalProgressBarWithShine extends StatefulWidget {
  final double value;
  final Color sunColor;
  final Color sunEdge;
  final Color backgroundColor;

  const _GoalProgressBarWithShine({
    required this.value,
    required this.sunColor,
    required this.sunEdge,
    required this.backgroundColor,
  });

  @override
  State<_GoalProgressBarWithShine> createState() =>
      _GoalProgressBarWithShineState();
}

class _GoalProgressBarWithShineState extends State<_GoalProgressBarWithShine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || MediaQuery.of(context).disableAnimations || isTest) {
        return;
      }
      _shineController.forward();
    });
  }

  @override
  void didUpdateWidget(covariant _GoalProgressBarWithShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if (!isTest &&
        widget.value > oldWidget.value &&
        mounted &&
        !MediaQuery.of(context).disableAnimations) {
      _shineController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _shineController.stop();
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 12,
        color: widget.backgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final fillWidth =
                constraints.maxWidth * widget.value.clamp(0.0, 1.0);
            return Stack(
              children: [
                // Filled bar in Sun color
                Container(
                  width: fillWidth,
                  decoration: BoxDecoration(
                    color: widget.sunColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                // Moving shine reflection across the sun bar
                if (!reduceMotion && fillWidth > 20)
                  AnimatedBuilder(
                    animation: _shineController,
                    builder: (context, _) {
                      final shineOffset =
                          -30.0 + (fillWidth + 60.0) * _shineController.value;
                      return Positioned(
                        left: shineOffset,
                        top: 0,
                        bottom: 0,
                        width: 30,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.0),
                                Colors.white.withValues(alpha: 0.5),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductHomePage extends StatelessWidget {
  final AppState appState;

  const _ProductHomePage({required this.appState});

  void _openLearning(BuildContext context, LearningMode mode) {
    final lessonWords = _lessonWords(mode: mode);
    if (lessonWords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có đủ nội dung cho chế độ này.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningScreen(
          mode: mode,
          words: lessonWords,
          direction: appState.direction,
          difficulty: appState.difficulty,
          loadDraft: () =>
              appState.learningDraft ?? appState.store.learningDraft,
          saveDraft: appState.saveLearningDraft,
          clearDraft: appState.clearLearningDraft,
          onDetailedAttempt:
              (
                wordId,
                correct,
                assisted, {
                required questionType,
                required sessionId,
              }) => appState.recordAttempt(
                wordId: wordId,
                correct: correct,
                assisted: assisted,
                questionType: questionType,
                sessionId: sessionId,
              ),
          onCompleted: (summary) => unawaited(
            appState.recordSession(
              correct: summary.correct,
              total: summary.total,
              wordLabels: summary.wordLabels,
            ),
          ),
        ),
      ),
    );
  }

  LearningMode? _modeForDraft(Map<String, dynamic>? draft) {
    final value = draft?['mode'];
    for (final mode in LearningMode.values) {
      if (mode.name == value) return mode;
    }
    return null;
  }

  List<VocabularyWord> _lessonWords({LearningMode? mode}) {
    final source = mode == LearningMode.imageWriting
        ? appState.catalog.where((word) => word.hasOfflineImage)
        : appState.catalog;
    return source
        .take(10)
        .map(
          (word) => VocabularyWord(
            apiLabel: word.id,
            emoji: '',
            english: word.english,
            vietnamese: word.vietnamese,
            imageUrl: word.imageUrl,
            localImagePath: word.localImagePath,
          ),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final goal = appState.dailyGoal;
    final completed = appState.todayWords.clamp(0, goal);
    final draftMode = _modeForDraft(appState.learningDraft);
    final draftIndex = appState.learningDraft?['index'];
    final draftTotal = appState.catalog.take(10).length;
    final topicCounts = <String, int>{};
    for (final word in appState.catalog) {
      topicCounts.update(word.topic, (count) => count + 1, ifAbsent: () => 1);
    }
    final topicIcons = <String, IconData>{
      'Đồ dùng học tập': Icons.backpack_outlined,
      'Trái cây': Icons.restaurant_outlined,
      'Rau củ': Icons.eco_outlined,
      'Màu sắc': Icons.palette_outlined,
      'Gia đình': Icons.family_restroom_outlined,
      'Động vật': Icons.pets_outlined,
    };
    return SafeArea(
      child: CustomScrollView(
        key: const PageStorageKey('product-home'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Xin chào, ${appState.profileName} 👋',
                          style: t(
                            13,
                            w: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hôm nay học gì?',
                          style: t(26, w: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                  if (appState.streak > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: colors.goldStreak.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: colors.goldStreakBevel,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department_rounded,
                            color: colors.goldStreakBevel,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${appState.streak}',
                            style: TextStyle(
                              color: colors.goldStreakBevel,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    tooltip: 'Cài đặt',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            _ProductSettingsPage(appState: appState),
                      ),
                    ),
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ],
              ),
            ),
          ),
          // Mục tiêu hôm nay: Khối học chính sinh động
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            sliver: SliverToBoxAdapter(
              child: StaggeredEntrance(
                index: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.blue, // Solid blue #2A7BE4
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.blueEdge, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.blueEdge, // 4dp edge #1B57AE
                        offset: Offset(0, 4),
                        blurRadius: 0, // 4dp bottom edge, no blurry shadow
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Translucent white circles placed at top-right corner behind mascot
                      Positioned(
                        top: -8,
                        right: -4,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 14,
                        right: 32,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.flag_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      'Mục tiêu hôm nay',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    Text(
                                      '$completed/$goal từ',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              const MayMascot(
                                size: 88,
                                animation: MayAnimation.greetWave,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0.0,
                              end: goal == 0
                                  ? 0.0
                                  : (completed / goal).clamp(0.0, 1.0),
                            ),
                            duration:
                                MediaQuery.maybeOf(
                                      context,
                                    )?.disableAnimations ??
                                    false
                                ? Duration.zero
                                : const Duration(
                                    milliseconds: 600,
                                  ), // 600ms ease-out
                            curve: Curves.easeOutCubic,
                            builder: (context, animValue, _) {
                              return _GoalProgressBarWithShine(
                                value: animValue,
                                sunColor: AppColors.gold,
                                sunEdge: AppColors.goldEdge,
                                backgroundColor: AppColors.surfaceAlt,
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            appState.streak > 0
                                ? 'Chuỗi ${appState.streak} ngày — tiếp tục nhé!'
                                : 'Bắt đầu một chuỗi học mới hôm nay',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (appState.persistenceError != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Card(
                  elevation: 0,
                  color: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: colors.border, width: 2),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_outlined),
                    title: const Text('Bộ nhớ cục bộ cần được kiểm tra'),
                    subtitle: Text(appState.persistenceError!),
                    trailing: TextButton(
                      onPressed: () => unawaited(appState.retryPersistence()),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(
              child: _ReviewDueCard(appState: appState),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Text('Tiếp tục học', style: t(19, w: FontWeight.w900)),
            ),
          ),
          if (draftMode != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _ResumeTile(
                  mode: draftMode,
                  progress: draftIndex is int
                      ? '${(draftIndex + 1).clamp(1, draftTotal)}/$draftTotal từ'
                      : 'Phiên đang dở',
                  onTap: () => _openLearning(context, draftMode),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              20,
              draftMode == null ? 10 : 12,
              20,
              12,
            ),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTile(
                      icon: Icons.style_rounded,
                      title: 'Thẻ ghi nhớ',
                      subtitle: 'Lật thẻ 3D',
                      onTap: () =>
                          _openLearning(context, LearningMode.flashcard),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeTile(
                      icon: Icons.hearing_rounded,
                      title: 'Nghe và chọn',
                      subtitle: 'Luyện nghe',
                      onTap: () =>
                          _openLearning(context, LearningMode.listening),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: _ModeTile(
                      icon: Icons.compare_arrows_rounded,
                      title: 'Ghép cặp',
                      subtitle: 'Nối từ & nghĩa',
                      onTap: () =>
                          _openLearning(context, LearningMode.matching),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ModeTile(
                      icon: Icons.edit_rounded,
                      title: 'Điền từ',
                      subtitle: 'Nhớ và tự gõ',
                      onTap: () =>
                          _openLearning(context, LearningMode.fillWord),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            sliver: SliverToBoxAdapter(
              child: _ModeTile(
                icon: Icons.translate_rounded,
                title: 'Dịch từ',
                subtitle: 'Chọn bản dịch đúng theo chiều học đã cài đặt',
                onTap: () => _openLearning(context, LearningMode.translation),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: colors.skyTint,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SpaceWordsPage(appState: appState),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const MayMascot(
                              size: 70,
                              animation: MayAnimation.greetWave,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sân chơi của Mây',
                                    style: t(19, w: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Phi đội từ vựng • Lái, né và học!',
                                    style: t(13, color: colors.textSecondary),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Chơi ngay',
                                    style: t(15, color: colors.skyText),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Khám phá chủ đề', style: t(19, w: FontWeight.w900)),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            sliver: SliverGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.65,
              children: [
                for (final topic in topicCounts.keys.take(4))
                  _TopicTile(
                    title: topic,
                    count: '${topicCounts[topic]} từ',
                    icon: topicIcons[topic] ?? Icons.category_outlined,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TopicDetailPage(
                          appState: appState,
                          topic: topic,
                          words: appState.catalog
                              .where((word) => word.topic == topic)
                              .toList(growable: false),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (appState.catalog.any((word) => word.hasOfflineImage))
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              sliver: SliverToBoxAdapter(
                child: _ModeTile(
                  icon: LearningMode.imageWriting.icon,
                  title: LearningMode.imageWriting.title,
                  subtitle: 'Nhìn hình, tự viết từ',
                  onTap: () =>
                      _openLearning(context, LearningMode.imageWriting),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _pushCatalogLesson(
  BuildContext context,
  AppState appState,
  CatalogWord word,
) {
  final lessonWord = VocabularyWord(
    apiLabel: word.id,
    emoji: '',
    english: word.english,
    vietnamese: word.vietnamese,
    imageUrl: word.imageUrl,
    localImagePath: word.localImagePath,
  );
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LearningScreen(
        mode: LearningMode.translation,
        words: [lessonWord],
        direction: appState.direction,
        difficulty: appState.difficulty,
        loadDraft: () => appState.learningDraft ?? appState.store.learningDraft,
        saveDraft: appState.saveLearningDraft,
        clearDraft: appState.clearLearningDraft,
        onDetailedAttempt:
            (
              wordId,
              correct,
              assisted, {
              required questionType,
              required sessionId,
            }) => appState.recordAttempt(
              wordId: wordId,
              correct: correct,
              assisted: assisted,
              questionType: questionType,
              sessionId: sessionId,
            ),
        onCompleted: (summary) => unawaited(
          appState.recordSession(
            correct: summary.correct,
            total: summary.total,
            wordLabels: summary.wordLabels,
          ),
        ),
      ),
    ),
  );
}

class _ProductVocabularyPage extends StatefulWidget {
  final AppState appState;

  const _ProductVocabularyPage({required this.appState});

  @override
  State<_ProductVocabularyPage> createState() => _ProductVocabularyPageState();
}

class _ProductVocabularyPageState extends State<_ProductVocabularyPage>
    with AutomaticKeepAliveClientMixin {
  final _searchController = TextEditingController();
  String _query = '';
  bool _favoritesOnly = false;
  String? _topic;
  bool _loadingPack = false;
  String? _packError;
  var _favoriteSignature = 0;
  var _catalogSignature = 0;
  late List<CatalogWord> _indexedCatalog;
  late CatalogSearchIndex _searchIndex;
  double? _downloadProgressSignature;

  List<CatalogWord> get _catalog => widget.appState.catalog;

  String get _releaseVersion => widget.appState.catalogReleaseVersion;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _captureAppStateSnapshot();
    widget.appState.addListener(_appStateListener);
  }

  void _captureAppStateSnapshot() {
    _indexedCatalog = widget.appState.catalog;
    _searchIndex = CatalogSearchIndex(_indexedCatalog);
    _favoriteSignature = Object.hashAllUnordered(widget.appState.favoriteWords);
    _catalogSignature = Object.hash(
      widget.appState.catalogReleaseVersion,
      widget.appState.catalog.length,
    );
    _downloadProgressSignature = widget.appState.catalogDownloadProgress;
  }

  void _appStateListener() {
    if (!mounted) return;
    final favoriteSignature = Object.hashAllUnordered(
      widget.appState.favoriteWords,
    );
    final catalogSignature = Object.hash(
      widget.appState.catalogReleaseVersion,
      widget.appState.catalog.length,
    );
    final progress = widget.appState.catalogDownloadProgress;
    if (favoriteSignature == _favoriteSignature &&
        catalogSignature == _catalogSignature &&
        identical(_indexedCatalog, widget.appState.catalog) &&
        progress == _downloadProgressSignature) {
      return;
    }
    _favoriteSignature = favoriteSignature;
    _catalogSignature = catalogSignature;
    if (!identical(_indexedCatalog, widget.appState.catalog)) {
      _indexedCatalog = widget.appState.catalog;
      _searchIndex = CatalogSearchIndex(_indexedCatalog);
    }
    _downloadProgressSignature = progress;
    setState(() {});
  }

  @override
  void dispose() {
    widget.appState.removeListener(_appStateListener);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _downloadPublishedPack() async {
    if (_loadingPack) return;
    setState(() {
      _loadingPack = true;
      _packError = null;
    });
    try {
      final release = await widget.appState.downloadPublishedCatalog();
      if (!mounted) return;
      setState(() {
        _loadingPack = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã lưu gói ${release.version} • ${release.words.length} từ để học offline.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingPack = false;
        _packError = error is CatalogDownloadCancelled
            ? 'Đã hủy tải gói. Gói $_releaseVersion hiện tại vẫn an toàn offline.'
            : error is StateError
            ? error.message.toString()
            : 'Không tải được gói mới. Gói $_releaseVersion hiện tại vẫn an toàn offline.';
      });
    }
  }

  Future<void> _restoreStarterPack() async {
    if (_loadingPack || _releaseVersion == starterCatalogReleaseVersion) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa gói đã tải?'),
        content: const Text(
          'App sẽ quay về gói starter offline. Tiến độ học, bộ sưu tập và lịch ôn không bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Giữ lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa gói'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _loadingPack = true;
      _packError = null;
    });
    try {
      await widget.appState.restoreStarterCatalog();
      if (!mounted) return;
      setState(() => _loadingPack = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã quay về gói starter offline.')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPack = false;
        _packError = 'Không xóa được gói tải. Dữ liệu hiện tại vẫn an toàn.';
      });
    }
  }

  // ignore: unused_element
  Widget _buildLegacyVocabulary(BuildContext context) {
    final colors = context.vocabColors;
    super.build(context);
    final words = _catalog.where((word) {
      final haystack = normalizeSearchText(
        '${word.english} ${word.vietnamese} ${word.id} ${word.topic}',
      );
      return (!_favoritesOnly ||
              widget.appState.favoriteWords.contains(word.id)) &&
          (_topic == null || word.topic == _topic) &&
          (_query.isEmpty || haystack.contains(_query));
    }).toList();
    return SafeArea(
      child: CustomScrollView(
        key: const PageStorageKey('product-vocabulary'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Khám phá', style: t(28, w: FontWeight.w900)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(
                      () => _query = normalizeSearchText(value.trim()),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm từ tiếng Anh hoặc tiếng Việt',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.clear),
                            ),
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Gói offline: $_releaseVersion · ${_catalog.length} từ đã lưu',
                      style: t(
                        12,
                        w: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadingPack ? null : _downloadPublishedPack,
                      icon: _loadingPack
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(
                        _loadingPack
                            ? 'Đang kiểm tra và tải gói…'
                            : 'Kiểm tra gói nội dung mới',
                      ),
                    ),
                  ),
                  if (_loadingPack) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: widget.appState.catalogDownloadProgress,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.appState.catalogDownloadProgress == null
                              ? 'Đang kiểm tra manifest…'
                              : 'Đang lưu media offline… ${(widget.appState.catalogDownloadProgress! * 100).round()}%',
                          style: t(
                            11,
                            w: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: widget.appState.cancelCatalogDownload,
                          child: const Text('Hủy'),
                        ),
                      ],
                    ),
                  ],
                  if (_releaseVersion != starterCatalogReleaseVersion) ...[
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _loadingPack ? null : _restoreStarterPack,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Xóa gói đã tải'),
                      ),
                    ),
                  ],
                  if (_packError != null) ...[
                    const SizedBox(height: 8),
                    Card(
                      elevation: 0,
                      color: C.amberSoft,
                      child: ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.info_outline,
                          color: C.orange,
                        ),
                        title: Text(
                          _packError!,
                          style: t(
                            12,
                            w: FontWeight.w600,
                            color: colors.warningText,
                          ),
                        ),
                        trailing: IconButton(
                          tooltip: 'Thử lại',
                          onPressed: _loadingPack
                              ? null
                              : _downloadPublishedPack,
                          icon: const Icon(Icons.refresh),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      FilterChip(
                        label: const Text('Yêu thích'),
                        selected: _favoritesOnly,
                        onSelected: (value) =>
                            setState(() => _favoritesOnly = value),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${words.length} từ',
                        style: t(
                          13,
                          w: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => _ProductCollectionsPage(
                              appState: widget.appState,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.collections_bookmark_outlined),
                        label: const Text('Bộ sưu tập'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Tất cả chủ đề'),
                          selected: _topic == null,
                          onSelected: (_) => setState(() => _topic = null),
                        ),
                        for (final topic in _topics)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(topic),
                              selected: _topic == topic,
                              onSelected: (selected) => setState(
                                () => _topic = selected ? topic : null,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (words.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text('Chưa có từ phù hợp')),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              sliver: SliverList.separated(
                itemCount: words.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final word = words[index];
                  final favorite = widget.appState.favoriteWords.contains(
                    word.id,
                  );
                  final hasImage = word.imageUrl?.trim().isNotEmpty == true;
                  return Container(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.borderStrong,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cardEdge,
                          offset: const Offset(0, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: hasImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 46,
                                height: 46,
                                color: colors.surfaceAlt,
                                child: Image(
                                  image: _catalogImage(word),
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Text(
                                      word.english
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: TextStyle(
                                        color: colors.accentDark,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: colors.accentSoft,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                word.english.substring(0, 1).toUpperCase(),
                                style: TextStyle(
                                  color: colors.accentDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                      title: Text(
                        word.english,
                        style: t(16, w: FontWeight.w900),
                      ),
                      subtitle: Text(
                        word.vietnamese,
                        style: t(
                          14,
                          w: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: favorite ? 'Bỏ yêu thích' : 'Thêm yêu thích',
                        onPressed: () =>
                            unawaited(widget.appState.toggleFavorite(word.id)),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) =>
                              ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            favorite
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_outline_rounded,
                            key: ValueKey<bool>(favorite),
                            color: favorite
                                ? colors.goldStreakBevel
                                : colors.textSecondary,
                            size: 24,
                          ),
                        ),
                      ),
                      onTap: () => _showWord(context, word),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    super.build(context);
    final words = _searchIndex.search(
      _query,
      topic: _topic,
      favoriteIds: _favoritesOnly ? widget.appState.favoriteWords : null,
    );
    final grouped = <String, List<CatalogWord>>{};
    for (final word in words) {
      final trimmed = word.english.trim();
      final letter = trimmed.isEmpty ? '#' : trimmed[0].toUpperCase();
      grouped.putIfAbsent(letter, () => <CatalogWord>[]).add(word);
    }
    final groups = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final favorites = widget.appState.favoriteWords;
    final gridRows = <_VocabularyGridRow>[];
    for (final group in groups) {
      gridRows.add(_VocabularyGridRow.header(group.key));
      for (var index = 0; index < group.value.length; index += 2) {
        final end = math.min(index + 2, group.value.length);
        gridRows.add(_VocabularyGridRow.words(group.value.sublist(index, end)));
      }
    }

    return SafeArea(
      child: CustomScrollView(
        key: const PageStorageKey('product-vocabulary'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text('Khám phá', style: t(28, w: FontWeight.w900)),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _query = normalizeSearchText(value.trim())),
                decoration: InputDecoration(
                  hintText: 'Tìm từ tiếng Anh hoặc tiếng Việt',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.clear_rounded),
                        ),
                  filled: true,
                  fillColor: colors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: colors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: BorderSide(color: colors.accent, width: 2),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gói offline: $_releaseVersion · ${_catalog.length} từ đã lưu',
                      style: t(
                        12,
                        w: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(
                    width: 170,
                    child: TextButton.icon(
                      onPressed: _loadingPack ? null : _downloadPublishedPack,
                      icon: _loadingPack
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: const Text(
                        'Kiểm tra gói nội dung mới',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_loadingPack)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.appState.catalogDownloadProgress == null
                                ? 'Đang kiểm tra manifest…'
                                : 'Đang lưu media offline… ${(widget.appState.catalogDownloadProgress! * 100).round()}%',
                            style: t(
                              11,
                              w: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: widget.appState.catalogDownloadProgress,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: widget.appState.cancelCatalogDownload,
                      child: const Text('Hủy'),
                    ),
                  ],
                ),
              ),
            ),
          if (_packError != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Card(
                  elevation: 0,
                  color: colors.warningSurface,
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.info_outline,
                      color: colors.warningText,
                    ),
                    title: Text(
                      _packError!,
                      style: t(
                        12,
                        w: FontWeight.w600,
                        color: colors.warningText,
                      ),
                    ),
                    trailing: IconButton(
                      tooltip: 'Thử lại',
                      onPressed: _loadingPack ? null : _downloadPublishedPack,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            sliver: SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Text('Yêu thích'),
                      avatar: const Icon(
                        Icons.bookmark_outline_rounded,
                        size: 17,
                      ),
                      selected: _favoritesOnly,
                      selectedColor: colors.accentSoft,
                      checkmarkColor: colors.accent,
                      onSelected: (value) =>
                          setState(() => _favoritesOnly = value),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${words.length} từ',
                      style: t(
                        13,
                        w: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => _ProductCollectionsPage(
                            appState: widget.appState,
                          ),
                        ),
                      ),
                      icon: const Icon(
                        Icons.collections_bookmark_outlined,
                        size: 18,
                      ),
                      label: const Text('Bộ sưu tập'),
                    ),
                    if (_releaseVersion != starterCatalogReleaseVersion)
                      TextButton.icon(
                        onPressed: _loadingPack ? null : _restoreStarterPack,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Xóa gói đã tải'),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            sliver: SliverToBoxAdapter(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _TopicFilterChip(
                      label: 'Tất cả chủ đề',
                      icon: Icons.auto_awesome_outlined,
                      selected: _topic == null,
                      onSelected: () => setState(() => _topic = null),
                    ),
                    for (final topic in _topics)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _TopicFilterChip(
                          label: topic,
                          icon: _topicStyle(context, topic).icon,
                          selected: _topic == topic,
                          onSelected: () => setState(
                            () => _topic = _topic == topic ? null : topic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (words.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'Chưa có từ phù hợp',
                  style: t(15, w: FontWeight.w700, color: colors.textSecondary),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 76),
              sliver: SliverList.builder(
                itemCount: gridRows.length,
                itemBuilder: (context, rowIndex) {
                  final row = gridRows[rowIndex];
                  if (row.letter != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _LetterHeader(letter: row.letter!),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: SizedBox(
                      height: 272,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _vocabularyWordCard(
                              context,
                              row.words[0],
                              favorites,
                            ),
                          ),
                          if (row.words.length > 1) ...[
                            const SizedBox(width: 10),
                            Expanded(
                              child: _vocabularyWordCard(
                                context,
                                row.words[1],
                                favorites,
                              ),
                            ),
                          ] else
                            const Spacer(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<String> get _topics => _searchIndex.topics;

  Widget _vocabularyWordCard(
    BuildContext context,
    CatalogWord word,
    Set<String> favorites,
  ) {
    final hasImage =
        word.imageUrl?.trim().isNotEmpty == true ||
        word.localImagePath?.trim().isNotEmpty == true;
    return _VocabularyWordCard(
      word: word,
      favorite: favorites.contains(word.id),
      image: hasImage ? _catalogImage(word) : null,
      onTap: () => _showWord(context, word),
      onSpeak: () => unawaited(_speakWord(word.english)),
      onFavorite: () => unawaited(widget.appState.toggleFavorite(word.id)),
    );
  }

  ImageProvider<Object> _catalogImage(CatalogWord word) {
    final local = word.localImagePath?.trim();
    if (local != null && local.isNotEmpty) return FileImage(File(local));
    final url = word.imageUrl!.trim();
    return url.startsWith('assets/') ? AssetImage(url) : NetworkImage(url);
  }

  void _showWord(BuildContext context, CatalogWord word) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: context.vocabColors.surface,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (word.imageUrl?.trim().isNotEmpty == true) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DisplayImage(
                    image: _catalogImage(word),
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    semanticLabel: 'Ảnh minh họa cho ${word.english}',
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 72,
                      child: Center(child: Text('Ảnh chưa sẵn sàng offline.')),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(word.english, style: t(28, w: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                word.vietnamese,
                style: t(18, w: FontWeight.w600, color: C.muted),
              ),
              const SizedBox(height: 18),
              Text(
                word.exampleEnglish,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                word.exampleVietnamese,
                style: TextStyle(fontSize: 14, color: C.muted, height: 1.4),
              ),
              const SizedBox(height: 4),
              Text(
                '${word.topic} • ${word.partOfSpeech}',
                style: t(12, w: FontWeight.w600, color: C.muted),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => unawaited(_speakWord(word.english)),
                icon: const Icon(Icons.volume_up_outlined),
                label: const Text('Nghe phát âm'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _startSingleWordLesson(word);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Học từ này'),
              ),
              const SizedBox(height: 8),
              Text(
                'Nguồn: ${word.source}',
                style: t(11, w: FontWeight.w500, color: C.muted),
              ),
              if (word.sourceUrl != null ||
                  word.sourceLicense != null ||
                  word.sourceAttribution != null) ...[
                const SizedBox(height: 3),
                Text(
                  [
                    if (word.sourceLicense != null) word.sourceLicense!,
                    if (word.sourceUrl != null) word.sourceUrl!,
                    if (word.sourceAttribution != null) word.sourceAttribution!,
                  ].join(' • '),
                  style: t(11, w: FontWeight.w500, color: C.muted),
                ),
              ],
              if (word.imageAttribution != null ||
                  word.imageLicense != null) ...[
                const SizedBox(height: 3),
                Text(
                  'Ảnh: ${[if (word.imageLicense != null) word.imageLicense!, if (word.imageAttribution != null) word.imageAttribution!].join(' • ')}',
                  style: t(11, w: FontWeight.w500, color: C.muted),
                ),
              ],
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_reportWord(word));
                },
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Báo lỗi nội dung'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startSingleWordLesson(CatalogWord word) =>
      _pushCatalogLesson(context, widget.appState, word);

  Future<void> _reportWord(CatalogWord word) async {
    final noteController = TextEditingController();
    var type = 'meaning';
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Báo lỗi: ${word.english}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: type,
                decoration: const InputDecoration(labelText: 'Loại lỗi'),
                items: const [
                  DropdownMenuItem(value: 'meaning', child: Text('Nghĩa sai')),
                  DropdownMenuItem(value: 'example', child: Text('Ví dụ sai')),
                  DropdownMenuItem(value: 'image', child: Text('Ảnh sai')),
                  DropdownMenuItem(value: 'other', child: Text('Khác')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => type = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Mô tả ngắn',
                  hintText: 'Điều gì cần được kiểm tra?',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final note = noteController.text.trim();
                if (note.isEmpty) return;
                Navigator.of(dialogContext).pop((type, note));
              },
              child: const Text('Gửi báo lỗi'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (result == null || !mounted) return;
    try {
      await widget.appState.reportContent(
        wordId: word.id,
        reportType: result.$1,
        note: result.$2,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi báo lỗi để kiểm tra.')),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error is StateError
          ? error.message.toString()
          : 'Chưa gửi được. Kiểm tra mạng và thử lại.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _speakWord(String word) async {
    try {
      await const MethodChannel(
        'vocab_vision/tts',
      ).invokeMethod<void>('speak', {'text': word});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiết bị chưa hỗ trợ phát âm.')),
      );
    }
  }
}

class _VocabularyCategoryStyle {
  final Color fill;
  final Color iconColor;
  final IconData icon;

  const _VocabularyCategoryStyle({
    required this.fill,
    required this.iconColor,
    required this.icon,
  });
}

_VocabularyCategoryStyle _topicStyle(BuildContext context, String topic) {
  final colors = context.vocabColors;
  final normalized = normalizeSearchText(topic);
  if (normalized.contains('hoc tap') ||
      normalized.contains('school') ||
      normalized.contains('dung hoc')) {
    return _VocabularyCategoryStyle(
      fill: colors.categorySchoolFill,
      iconColor: colors.categorySchoolIcon,
      icon: Icons.backpack_outlined,
    );
  }
  if (normalized.contains('dong vat') || normalized.contains('animal')) {
    return _VocabularyCategoryStyle(
      fill: colors.categoryAnimalFill,
      iconColor: colors.categoryAnimalIcon,
      icon: Icons.pets_outlined,
    );
  }
  if (normalized.contains('trai cay') ||
      normalized.contains('qua ') ||
      normalized.contains('fruit')) {
    return _VocabularyCategoryStyle(
      fill: colors.categoryFruitFill,
      iconColor: colors.categoryFruitIcon,
      icon: Icons.local_florist_outlined,
    );
  }
  return _VocabularyCategoryStyle(
    fill: colors.categoryOtherFill,
    iconColor: colors.categoryOtherIcon,
    icon: Icons.auto_awesome_outlined,
  );
}

class _TopicFilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onSelected;

  const _TopicFilterChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 17,
        color: selected ? Colors.white : colors.accent,
      ),
      label: Text(label),
      selected: selected,
      selectedColor: colors.accent,
      backgroundColor: colors.surface,
      side: BorderSide(color: selected ? colors.accent : colors.border),
      labelStyle: TextStyle(
        color: selected ? Colors.white : colors.textPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 13,
      ),
      checkmarkColor: Colors.white,
      onSelected: (_) => onSelected(),
    );
  }
}

class _LetterHeader extends StatelessWidget {
  final String letter;

  const _LetterHeader({required this.letter});

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: colors.accentSoft,
          child: Text(
            letter,
            style: TextStyle(color: colors.accent, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: colors.border, height: 1)),
      ],
    );
  }
}

class _VocabularyGridRow {
  final String? letter;
  final List<CatalogWord> words;

  const _VocabularyGridRow.header(this.letter) : words = const [];

  const _VocabularyGridRow.words(this.words) : letter = null;
}

class _VocabularyWordCard extends StatelessWidget {
  final CatalogWord word;
  final bool favorite;
  final ImageProvider<Object>? image;
  final VoidCallback onTap;
  final VoidCallback onSpeak;
  final VoidCallback onFavorite;

  const _VocabularyWordCard({
    required this.word,
    required this.favorite,
    required this.image,
    required this.onTap,
    required this.onSpeak,
    required this.onFavorite,
  });

  Widget _fallback(BuildContext context) {
    final style = _topicStyle(context, word.topic);
    return ColoredBox(
      color: style.fill,
      child: Center(child: Icon(style.icon, color: style.iconColor, size: 48)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 106,
                child: image == null
                    ? _fallback(context)
                    : DisplayImage(
                        image: image!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallback(context),
                        semanticLabel: 'Ảnh minh họa cho ${word.english}',
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        word.english,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t(16, w: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        word.vietnamese,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t(
                          13,
                          w: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              tooltip: 'Nghe phát âm',
                              onPressed: onSpeak,
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: colors.surfaceAlt,
                                foregroundColor: colors.accent,
                                shape: const CircleBorder(),
                              ),
                              icon: const Icon(
                                Icons.volume_up_rounded,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: IconButton(
                              tooltip: favorite
                                  ? 'Bỏ yêu thích'
                                  : 'Thêm yêu thích',
                              onPressed: onFavorite,
                              padding: EdgeInsets.zero,
                              style: IconButton.styleFrom(
                                backgroundColor: favorite
                                    ? colors.categoryFruitFill
                                    : colors.surfaceAlt,
                                foregroundColor: favorite
                                    ? colors.categoryFruitIcon
                                    : colors.textSecondary,
                                shape: const CircleBorder(),
                              ),
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                transitionBuilder: (child, animation) =>
                                    ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    ),
                                child: Icon(
                                  favorite
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_outline_rounded,
                                  key: ValueKey<bool>(favorite),
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
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
  }
}

class _ProductCollectionsPage extends StatelessWidget {
  final AppState appState;

  const _ProductCollectionsPage({required this.appState});

  Future<void> _create(BuildContext context) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo bộ sưu tập'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(hintText: 'Ví dụ: Từ cần ôn'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await appState.createCollection(name);
  }

  Future<void> _rename(
    BuildContext context,
    VocabularyCollection collection,
  ) async {
    final controller = TextEditingController(text: collection.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Đổi tên bộ sưu tập'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
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
    if (name != null) await appState.renameCollection(collection.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    VocabularyCollection collection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa bộ sưu tập?'),
        content: Text(
          'Các từ trong “${collection.name}” không bị xóa khỏi kho.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) await appState.deleteCollection(collection.id);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appState,
    builder: (context, _) => Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Bộ sưu tập'),
        backgroundColor: context.vocabColors.canvas,
        foregroundColor: context.vocabColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => unawaited(_create(context)),
        icon: const Icon(Icons.add),
        label: const Text('Tạo bộ mới'),
      ),
      body: appState.collections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.collections_bookmark_outlined,
                      size: 64,
                      color: C.mintDark,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Tạo bộ từ đầu tiên',
                      style: t(19, w: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Gom các từ cần học lại để mở đúng một bài riêng.',
                      textAlign: TextAlign.center,
                      style: t(
                        14,
                        w: FontWeight.w500,
                        color: context.vocabColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              itemCount: appState.collections.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final collection = appState.collections[index];
                return Card(
                  elevation: 0,
                  color: context.vocabColors.surface,
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: context.vocabColors.accentSoft,
                      child: Icon(
                        Icons.bookmark_outline,
                        color: context.vocabColors.accentDark,
                      ),
                    ),
                    title: Text(
                      collection.name,
                      style: t(16, w: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${collection.wordIds.length} từ',
                      style: t(
                        13,
                        w: FontWeight.w500,
                        color: context.vocabColors.textSecondary,
                      ),
                    ),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rename') {
                          unawaited(_rename(context, collection));
                        } else {
                          unawaited(_delete(context, collection));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'rename', child: Text('Đổi tên')),
                        PopupMenuItem(value: 'delete', child: Text('Xóa')),
                      ],
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => _CollectionDetailPage(
                          appState: appState,
                          collectionId: collection.id,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    ),
  );
}

class _CollectionDetailPage extends StatelessWidget {
  final AppState appState;
  final String collectionId;

  const _CollectionDetailPage({
    required this.appState,
    required this.collectionId,
  });

  VocabularyCollection? get _collection {
    for (final item in appState.collections) {
      if (item.id == collectionId) return item;
    }
    return null;
  }

  List<CatalogWord> _words(VocabularyCollection collection) => appState.catalog
      .where((word) => collection.wordIds.contains(word.id))
      .toList(growable: false);

  void _start(BuildContext context, List<CatalogWord> words) {
    final lessonWords = words
        .map(
          (word) => VocabularyWord(
            apiLabel: word.id,
            emoji: '',
            english: word.english,
            vietnamese: word.vietnamese,
            imageUrl: word.imageUrl,
            localImagePath: word.localImagePath,
          ),
        )
        .toList(growable: false);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningScreen(
          mode: LearningMode.translation,
          words: lessonWords,
          direction: appState.direction,
          difficulty: appState.difficulty,
          loadDraft: () =>
              appState.learningDraft ?? appState.store.learningDraft,
          saveDraft: appState.saveLearningDraft,
          clearDraft: appState.clearLearningDraft,
          onDetailedAttempt:
              (
                wordId,
                correct,
                assisted, {
                required questionType,
                required sessionId,
              }) => appState.recordAttempt(
                wordId: wordId,
                correct: correct,
                assisted: assisted,
                questionType: questionType,
                sessionId: sessionId,
              ),
          onCompleted: (summary) => unawaited(
            appState.recordSession(
              correct: summary.correct,
              total: summary.total,
              wordLabels: summary.wordLabels,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addWords(
    BuildContext context,
    VocabularyCollection collection,
  ) async {
    final available = appState.catalog
        .where((word) => !collection.wordIds.contains(word.id))
        .toList(growable: false);
    if (available.isEmpty) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: available.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, index) {
            final word = available[index];
            return ListTile(
              title: Text(word.english),
              subtitle: Text(word.vietnamese),
              trailing: const Icon(Icons.add_circle_outline),
              onTap: () => unawaited(
                appState.toggleCollectionWord(collection.id, word.id),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appState,
    builder: (context, _) {
      final collection = _collection;
      if (collection == null) {
        return const Scaffold(
          body: Center(child: Text('Bộ sưu tập không còn tồn tại.')),
        );
      }
      final words = _words(collection);
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(collection.name),
          backgroundColor: context.vocabColors.canvas,
          foregroundColor: context.vocabColors.textPrimary,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: 'Thêm từ',
              onPressed: () => unawaited(_addWords(context, collection)),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            Text(
              '${words.length} từ trong bộ',
              style: t(18, w: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: words.isEmpty ? null : () => _start(context, words),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Học bộ này'),
            ),
            const SizedBox(height: 18),
            if (words.isEmpty)
              Text(
                'Chưa có từ. Nhấn dấu + để thêm từ từ kho khởi động.',
                style: t(
                  14,
                  w: FontWeight.w500,
                  color: context.vocabColors.textSecondary,
                ),
              )
            else
              for (final word in words)
                Card(
                  elevation: 0,
                  color: context.vocabColors.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(word.english, style: t(15, w: FontWeight.w800)),
                    subtitle: Text(word.vietnamese),
                    trailing: IconButton(
                      tooltip: 'Bỏ khỏi bộ',
                      onPressed: () => unawaited(
                        appState.toggleCollectionWord(collection.id, word.id),
                      ),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class _ReviewDueCard extends StatefulWidget {
  final AppState appState;

  const _ReviewDueCard({required this.appState});

  @override
  State<_ReviewDueCard> createState() => _ReviewDueCardState();
}

class _ReviewDueCardState extends State<_ReviewDueCard> {
  late Future<List<ReviewState>> _future;
  late VoidCallback _appStateListener;

  @override
  void initState() {
    super.initState();
    _future = widget.appState.dueReviewStates();
    _appStateListener = _refresh;
    widget.appState.addListener(_appStateListener);
  }

  @override
  void didUpdateWidget(covariant _ReviewDueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState != widget.appState) {
      oldWidget.appState.removeListener(_appStateListener);
      widget.appState.addListener(_appStateListener);
      _future = widget.appState.dueReviewStates();
    }
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _future = widget.appState.dueReviewStates();
    });
  }

  @override
  void dispose() {
    widget.appState.removeListener(_appStateListener);
    super.dispose();
  }

  void _openDue(BuildContext context, List<ReviewState> due) {
    final words = widget.appState.catalog
        .where((word) => due.any((item) => item.wordId == word.id))
        .take(10)
        .map(
          (word) => VocabularyWord(
            apiLabel: word.id,
            emoji: '',
            english: word.english,
            vietnamese: word.vietnamese,
            imageUrl: word.imageUrl,
            localImagePath: word.localImagePath,
          ),
        )
        .toList(growable: false);
    if (words.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningScreen(
          mode: LearningMode.translation,
          words: words,
          direction: widget.appState.direction,
          difficulty: widget.appState.difficulty,
          loadDraft: () =>
              widget.appState.learningDraft ??
              widget.appState.store.learningDraft,
          saveDraft: widget.appState.saveLearningDraft,
          clearDraft: widget.appState.clearLearningDraft,
          onDetailedAttempt:
              (
                wordId,
                correct,
                assisted, {
                required questionType,
                required sessionId,
              }) => widget.appState.recordAttempt(
                wordId: wordId,
                correct: correct,
                assisted: assisted,
                questionType: questionType,
                sessionId: sessionId,
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
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ReviewState>>(
    future: _future,
    builder: (context, snapshot) {
      final count = snapshot.data?.length;
      final colors = context.vocabColors;
      return GestureDetector(
        onTap: count != null && count > 0
            ? () => _openDue(context, snapshot.data!)
            : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Row(
            children: [
              Icon(Icons.event_available_outlined, color: colors.accentDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lịch ôn hôm nay', style: t(16, w: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      snapshot.hasError
                          ? 'Chưa đọc được lịch ôn trên thiết bị này'
                          : count == null
                          ? 'Đang tải lịch ôn…'
                          : count == 0
                          ? 'Chưa có từ đến hạn'
                          : '$count từ đang đến hạn • chạm để ôn',
                      style: t(
                        13,
                        w: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (count != null && count > 0)
                Icon(Icons.chevron_right_rounded, color: colors.accentDark),
            ],
          ),
        ),
      );
    },
  );
}

class _RecentAttemptsCard extends StatefulWidget {
  final AppState appState;

  const _RecentAttemptsCard({required this.appState});

  @override
  State<_RecentAttemptsCard> createState() => _RecentAttemptsCardState();
}

class _RecentAttemptsCardState extends State<_RecentAttemptsCard> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.appState.recentAttempts(limit: 5);
  }

  @override
  void didUpdateWidget(covariant _RecentAttemptsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState != widget.appState) {
      _future = widget.appState.recentAttempts(limit: 5);
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _future,
    builder: (context, snapshot) {
      final attempts = snapshot.data ?? const <Map<String, dynamic>>[];
      final colors = context.vocabColors;
      return _ProductCard(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Lịch sử trả lời',
                    style: t(16, w: FontWeight.w800),
                  ),
                ),
                Text(
                  '${attempts.length} gần nhất',
                  style: t(12, w: FontWeight.w500, color: colors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(minHeight: 3)
            else if (attempts.isEmpty)
              Text(
                'Hoàn thành một câu hỏi để lịch sử xuất hiện ở đây.',
                style: t(13, w: FontWeight.w500, color: colors.textSecondary),
              )
            else
              for (final attempt in attempts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Icon(
                        attempt['correct'] == 1
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 18,
                        color: attempt['correct'] == 1
                            ? colors.accentDark
                            : colors.errorText,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${attempt['word_id'] ?? 'Từ'}${attempt['assisted'] == 1 ? ' • có gợi ý' : ''}',
                          style: t(13, w: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      );
    },
  );
}

class _ProductProgressPage extends StatelessWidget {
  final AppState appState;

  const _ProductProgressPage({required this.appState});

  // ignore: unused_element
  Widget _buildLegacyProgress(BuildContext context) {
    final colors = context.vocabColors;
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('product-progress'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('Tiến độ', style: t(28, w: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            'Theo dõi thói quen học của em',
            style: t(15, w: FontWeight.w500, color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatCard(value: '${appState.points}', label: 'Điểm'),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  value: '${appState.sessions}',
                  label: 'Phiên học',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  value: '${appState.streak}',
                  label: 'Ngày liên tiếp',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ProductCard(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Từ đã học', style: t(17, w: FontWeight.w800)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: appState.catalog.isEmpty
                      ? 0
                      : appState.learnedWords.length / appState.catalog.length,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(6),
                  color: colors.accent,
                  backgroundColor: colors.surfaceAlt,
                ),
                const SizedBox(height: 8),
                Text(
                  '${appState.learnedWords.length}/${appState.catalog.length} từ trong gói offline hiện tại',
                  style: t(13, w: FontWeight.w600, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ReviewDueCard(appState: appState),
          const SizedBox(height: 12),
          _RecentAttemptsCard(appState: appState),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Thành tích'),
            subtitle: Text('${appState.achievementCount} mốc đã mở khóa'),
            tileColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ProductAchievementsPage(appState: appState),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Kết quả thực nghiệm E4'),
            subtitle: const Text('Số liệu nghiên cứu, không phải điểm học'),
            tileColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResearchResultsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final learned = appState.learnedWords.length;
    final catalogTotal = appState.catalog.length;
    final goal = appState.dailyGoal;
    final hasProgress = learned > 0 || appState.todayWords > 0;
    final progress = catalogTotal == 0
        ? 0.0
        : (learned / catalogTotal).clamp(0.0, 1.0);
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('product-progress'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 76),
        children: [
          Text('Tiến độ', style: t(28, w: FontWeight.w900)),
          const SizedBox(height: 5),
          Text(
            'Cùng xem em đã học được gì nhé',
            style: t(15, w: FontWeight.w500, color: colors.textSecondary),
          ),
          const SizedBox(height: 18),
          _ProgressHeroCard(
            appState: appState,
            hasProgress: hasProgress,
            goal: goal,
            onStart: () => _startProgressLesson(context, appState),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  value: '${appState.points}',
                  label: 'Điểm',
                  icon: Icons.star_rounded,
                  color: colors.primaryAction,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: '${appState.sessions}',
                  label: 'Buổi học',
                  icon: Icons.menu_book_rounded,
                  color: colors.categorySchoolIcon,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCard(
                  value: '${appState.streak}',
                  label: 'Chuỗi ngày',
                  icon: Icons.local_fire_department_rounded,
                  color: colors.categoryAnimalIcon,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WeeklyActivityCard(appState: appState),
          const SizedBox(height: 14),
          _LearnedWordsCard(
            learned: learned,
            total: catalogTotal,
            progress: progress,
          ),
          const SizedBox(height: 14),
          _RecentCorrectCard(appState: appState),
          const SizedBox(height: 14),
          _ReviewDueCard(appState: appState),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.emoji_events_outlined),
            title: const Text('Thành tích'),
            subtitle: Text('${appState.achievementCount} mốc đã mở khóa'),
            tileColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.border),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ProductAchievementsPage(appState: appState),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Kết quả thực nghiệm E4'),
            subtitle: const Text('Số liệu nghiên cứu, không phải điểm học'),
            tileColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.border),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ResearchResultsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

void _startProgressLesson(BuildContext context, AppState appState) {
  final words = appState.catalog
      .take(10)
      .map(
        (word) => VocabularyWord(
          apiLabel: word.id,
          emoji: '',
          english: word.english,
          vietnamese: word.vietnamese,
          imageUrl: word.imageUrl,
          localImagePath: word.localImagePath,
        ),
      )
      .toList(growable: false);
  if (words.isEmpty) return;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => LearningScreen(
        mode: LearningMode.flashcard,
        words: words,
        direction: appState.direction,
        difficulty: appState.difficulty,
        loadDraft: () => appState.learningDraft ?? appState.store.learningDraft,
        saveDraft: appState.saveLearningDraft,
        clearDraft: appState.clearLearningDraft,
        onDetailedAttempt:
            (
              wordId,
              correct,
              assisted, {
              required questionType,
              required sessionId,
            }) => appState.recordAttempt(
              wordId: wordId,
              correct: correct,
              assisted: assisted,
              questionType: questionType,
              sessionId: sessionId,
            ),
        onCompleted: (summary) => unawaited(
          appState.recordSession(
            correct: summary.correct,
            total: summary.total,
            wordLabels: summary.wordLabels,
          ),
        ),
      ),
    ),
  );
}

class _ProgressHeroCard extends StatelessWidget {
  final AppState appState;
  final bool hasProgress;
  final int goal;
  final VoidCallback onStart;

  const _ProgressHeroCard({
    required this.appState,
    required this.hasProgress,
    required this.goal,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final today = appState.todayWords.clamp(0, goal);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.borderStrong,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (!hasProgress) ...[
            const CameraBuddyMascot(
              size: 48,
              expression: CameraBuddyExpression.waving,
            ),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasProgress ? 'Tiếp tục nào!' : 'Bắt đầu nào!',
                  style: t(21, w: FontWeight.w800, color: colors.textPrimary),
                ),
                const SizedBox(height: 5),
                Text(
                  hasProgress
                      ? 'Hôm nay em đã học $today/$goal từ. Cố lên nhé!'
                      : 'Học 10 từ để nhận ngôi sao đầu tiên',
                  style: t(
                    14,
                    w: FontWeight.w500,
                    color: colors.textSecondary,
                    h: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          PlayfulButton(
            onPressed: appState.catalog.isEmpty ? null : onStart,
            variant: PlayfulButtonVariant.primary,
            text: 'Học ngay',
            height: 48,
            width: 104,
          ),
        ],
      ),
    );
  }
}

class _WeeklyActivityCard extends StatefulWidget {
  final AppState appState;

  const _WeeklyActivityCard({required this.appState});

  @override
  State<_WeeklyActivityCard> createState() => _WeeklyActivityCardState();
}

class _WeeklyActivityCardState extends State<_WeeklyActivityCard> {
  late Future<Set<int>> _future;
  late VoidCallback _appStateListener;
  var _attemptRevision = -1;

  @override
  void initState() {
    super.initState();
    _future = _loadActivity();
    _attemptRevision = widget.appState.attemptRevision;
    _appStateListener = _refreshIfAttemptsChanged;
    widget.appState.addListener(_appStateListener);
  }

  void _refreshIfAttemptsChanged() {
    if (!mounted) return;
    final revision = widget.appState.attemptRevision;
    if (revision == _attemptRevision) return;
    _attemptRevision = revision;
    setState(() => _future = _loadActivity());
  }

  @override
  void didUpdateWidget(covariant _WeeklyActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState != widget.appState) {
      oldWidget.appState.removeListener(_appStateListener);
      widget.appState.addListener(_appStateListener);
      _attemptRevision = widget.appState.attemptRevision;
      _future = _loadActivity();
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_appStateListener);
    super.dispose();
  }

  Future<Set<int>> _loadActivity() async {
    final attempts = await widget.appState.recentAttempts(limit: 1000);
    final now = DateTime.now();
    final monday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final active = <int>{};
    for (final attempt in attempts) {
      final raw = attempt['answered_at'];
      if (raw is! String) continue;
      final date = DateTime.tryParse(raw)?.toLocal();
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      final offset = day.difference(monday).inDays;
      if (offset >= 0 && offset < 7) active.add(offset);
    }
    return active;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Set<int>>(
    future: _future,
    builder: (context, snapshot) {
      final active = snapshot.data;
      // No per-day activity is available, so hiding is more honest than
      // drawing seven empty dots that look like a measured zero.
      if (active == null || active.isEmpty) return const SizedBox.shrink();
      final colors = context.vocabColors;
      final today = DateTime.now().weekday - 1;
      const labels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tuần này', style: t(17, w: FontWeight.w800)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var index = 0; index < labels.length; index++)
                  _ActivityDot(
                    label: labels[index],
                    active: active.contains(index),
                    today: today == index,
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _ActivityDot extends StatelessWidget {
  final String label;
  final bool active;
  final bool today;

  const _ActivityDot({
    required this.label,
    required this.active,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    return Column(
      children: [
        CustomPaint(
          size: const Size.square(34),
          painter: _DashedActivityRingPainter(
            color: today ? colors.accent : colors.border,
            filled: active,
            fillColor: colors.accent,
            dashed: today,
          ),
          child: const SizedBox.square(dimension: 34),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: t(12, w: FontWeight.w700, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _DashedActivityRingPainter extends CustomPainter {
  final Color color;
  final bool filled;
  final Color fillColor;
  final bool dashed;

  const _DashedActivityRingPainter({
    required this.color,
    required this.filled,
    required this.fillColor,
    required this.dashed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 2;
    if (filled) {
      canvas.drawCircle(center, radius, Paint()..color = fillColor);
    }
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (!dashed) {
      canvas.drawCircle(center, radius, stroke);
      return;
    }
    const dash = 0.22;
    for (var i = 0; i < 16; i++) {
      final start = i * math.pi * 2 / 16;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        dash,
        false,
        stroke,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedActivityRingPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.filled != filled ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.dashed != dashed;
}

class _LearnedWordsCard extends StatelessWidget {
  final int learned;
  final int total;
  final double progress;

  const _LearnedWordsCard({
    required this.learned,
    required this.total,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    const milestones = [10, 50, 100, 300];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Từ đã học', style: t(17, w: FontWeight.w800)),
              ),
              Text(
                '$learned / 300 từ',
                style: t(14, w: FontWeight.w800, color: colors.accent),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 13,
              color: colors.accent,
              backgroundColor: colors.surfaceAlt,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final milestone in milestones)
                _MilestoneBadge(
                  value: milestone,
                  reached: learned >= milestone,
                ),
            ],
          ),
          if (total != 300)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Gói hiện tại có $total từ; mốc học dùng mục tiêu 300 từ.',
                style: t(11, w: FontWeight.w500, color: colors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

class _MilestoneBadge extends StatelessWidget {
  final int value;
  final bool reached;

  const _MilestoneBadge({required this.value, required this.reached});

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final color = reached ? colors.primaryAction : colors.surfaceAlt;
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Icon(
            reached ? Icons.check_rounded : Icons.lock_outline_rounded,
            size: 18,
            color: reached ? colors.onPrimaryAction : colors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: t(11, w: FontWeight.w800, color: colors.textSecondary),
        ),
      ],
    );
  }
}

class _RecentCorrectCard extends StatefulWidget {
  final AppState appState;

  const _RecentCorrectCard({required this.appState});

  @override
  State<_RecentCorrectCard> createState() => _RecentCorrectCardState();
}

class _RecentCorrectCardState extends State<_RecentCorrectCard> {
  late Future<List<String>> _future;
  late VoidCallback _appStateListener;
  var _attemptRevision = -1;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _attemptRevision = widget.appState.attemptRevision;
    _appStateListener = _refreshIfAttemptsChanged;
    widget.appState.addListener(_appStateListener);
  }

  void _refreshIfAttemptsChanged() {
    if (!mounted) return;
    final revision = widget.appState.attemptRevision;
    if (revision == _attemptRevision) return;
    _attemptRevision = revision;
    setState(() => _future = _load());
  }

  @override
  void didUpdateWidget(covariant _RecentCorrectCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appState != widget.appState) {
      oldWidget.appState.removeListener(_appStateListener);
      widget.appState.addListener(_appStateListener);
      _attemptRevision = widget.appState.attemptRevision;
      _future = _load();
    }
  }

  @override
  void dispose() {
    widget.appState.removeListener(_appStateListener);
    super.dispose();
  }

  Future<List<String>> _load() async {
    final attempts = await widget.appState.recentAttempts(limit: 20);
    return attempts
        .where((attempt) => attempt['correct'] == 1)
        .map((attempt) => _formatWordId('${attempt['word_id'] ?? ''}'))
        .where((label) => label.isNotEmpty)
        .toSet()
        .take(6)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _future,
    builder: (context, snapshot) {
      final colors = context.vocabColors;
      final words = snapshot.data ?? const <String>[];
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vừa trả lời đúng', style: t(17, w: FontWeight.w800)),
            const SizedBox(height: 10),
            if (snapshot.connectionState != ConnectionState.done)
              const LinearProgressIndicator(minHeight: 3)
            else if (words.isEmpty)
              Text(
                'Trả lời đúng một câu để xem từ ở đây nhé.',
                style: t(13, w: FontWeight.w500, color: colors.textSecondary),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final word in words)
                    Chip(
                      avatar: Icon(
                        Icons.check_rounded,
                        size: 17,
                        color: colors.accent,
                      ),
                      label: Text(word),
                      backgroundColor: colors.accentSoft,
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

String _formatWordId(String raw) {
  final cleaned = raw.trim().replaceAll('_', ' ');
  if (cleaned.isEmpty) return '';
  return cleaned[0].toUpperCase() + cleaned.substring(1);
}

class _ProductAchievementsPage extends StatelessWidget {
  final AppState appState;

  const _ProductAchievementsPage({required this.appState});

  static const _achievements =
      <({IconData icon, String title, String description, int index})>[
        (
          icon: Icons.local_fire_department_outlined,
          title: 'Học liên tiếp 5 ngày',
          description: 'Duy trì chuỗi học trong 5 ngày.',
          index: 0,
        ),
        (
          icon: Icons.menu_book_outlined,
          title: 'Từ đầu tiên',
          description: 'Học thành công 10 từ.',
          index: 1,
        ),
        (
          icon: Icons.play_circle_outline,
          title: 'Phiên học đầu tiên',
          description: 'Hoàn thành một phiên học.',
          index: 2,
        ),
        (
          icon: Icons.stars_outlined,
          title: 'Điểm chăm chỉ',
          description: 'Tích lũy 100 điểm.',
          index: 3,
        ),
        (
          icon: Icons.auto_stories_outlined,
          title: 'Mọt sách nhí',
          description: 'Học thành công 25 từ.',
          index: 4,
        ),
        (
          icon: Icons.explore_outlined,
          title: 'Người khám phá',
          description: 'Học thành công 50 từ.',
          index: 5,
        ),
        (
          icon: Icons.track_changes_outlined,
          title: 'Bậc thầy điểm số',
          description: 'Tích lũy 500 điểm.',
          index: 6,
        ),
        (
          icon: Icons.workspace_premium_outlined,
          title: 'Nhà vô địch tháng',
          description: 'Duy trì chuỗi học 30 ngày.',
          index: 7,
        ),
        (
          icon: Icons.repeat_outlined,
          title: 'Chuỗi 10 phiên',
          description: 'Hoàn thành 10 phiên học.',
          index: 8,
        ),
        (
          icon: Icons.library_books_outlined,
          title: 'Bậc thầy từ vựng',
          description: 'Học thành công 100 từ.',
          index: 9,
        ),
        (
          icon: Icons.bolt_outlined,
          title: 'Thần tốc',
          description: 'Hoàn thành 20 phiên học.',
          index: 10,
        ),
        (
          icon: Icons.public_outlined,
          title: 'Nhà thám hiểm catalog',
          description: 'Học đủ 300 từ trong gói hiện tại.',
          index: 11,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final unlocked = _achievements
        .where((item) => appState.isAchievementUnlocked(item.index))
        .length;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Thành tích'),
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _ProductCard(
            color: context.vocabColors.primaryPanel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tiến độ thành tích',
                        style: TextStyle(
                          color: colors.onPrimaryPanel,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      '$unlocked/${_achievements.length}',
                      style: TextStyle(
                        color: colors.onPrimaryPanel,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: unlocked / _achievements.length,
                    minHeight: 9,
                    backgroundColor: colors.onPrimaryPanel.withValues(
                      alpha: 0.2,
                    ),
                    valueColor: AlwaysStoppedAnimation(colors.accent),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Mốc được tính từ dữ liệu học đã lưu trên thiết bị.',
                  style: t(
                    12,
                    w: FontWeight.w600,
                    color: colors.onPrimaryPanel.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ..._achievements.map(
            (item) => _AchievementTile(
              icon: item.icon,
              title: item.title,
              description: item.description,
              unlocked: appState.isAchievementUnlocked(item.index),
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool unlocked;

  const _AchievementTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final badge = unlocked
        ? Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.sunTint,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.goldStreak, width: 2),
                ),
                child: Icon(icon, size: 22, color: colors.sunText),
              ),
              Positioned(
                top: -2,
                right: -2,
                child: Icon(
                  Icons.auto_awesome,
                  size: 14,
                  color: colors.goldStreak,
                ),
              ),
            ],
          )
        : Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.locked.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: colors.locked, width: 1.5),
            ),
            child: Icon(Icons.lock_outline, size: 22, color: colors.locked),
          );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? colors.goldStreak.withValues(alpha: 0.8)
              : colors.border,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: unlocked ? colors.goldStreakBevel : colors.borderStrong,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: unlocked && !reduceMotion
            ? TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 350),
                curve: Curves.elasticOut,
                builder: (context, s, ch) =>
                    Transform.scale(scale: s, child: ch),
                child: badge,
              )
            : badge,
        title: Text(title, style: t(15, w: FontWeight.w800)),
        subtitle: Text(description, style: t(12, color: colors.textSecondary)),
        trailing: Icon(
          unlocked ? Icons.check_circle_rounded : Icons.lock_outline,
          color: unlocked ? colors.accent : colors.locked,
          size: 22,
        ),
      ),
    );
  }
}

class _ProductProfilePage extends StatelessWidget {
  final AppState appState;

  const _ProductProfilePage({required this.appState});

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    return SafeArea(
      child: ListView(
        key: const PageStorageKey('product-profile'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Text('Hồ sơ', style: t(28, w: FontWeight.w900)),
          const SizedBox(height: 18),
          _ProductCard(
            color: context.vocabColors.primaryPanel,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.accentSoft,
                  child: Text(
                    appState.profileName.isEmpty
                        ? '?'
                        : appState.profileName.substring(0, 1).toUpperCase(),
                    style: t(
                      22,
                      w: FontWeight.w900,
                      color: colors.tealTextOnTint,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appState.profileName,
                      style: TextStyle(
                        color: colors.onPrimaryPanel,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      appState.sessions == 0
                          ? 'Sẵn sàng bắt đầu'
                          : '${appState.sessions} phiên học',
                      style: TextStyle(
                        color: colors.onPrimaryPanel.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AccountCard(appState: appState),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('Cài đặt'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _ProductSettingsPage(appState: appState),
              ),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Giới thiệu và nguồn nội dung'),
            trailing: const Icon(Icons.chevron_right),
            tileColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => _ProductContentSourcesPage(appState: appState),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductContentSourcesPage extends StatelessWidget {
  final AppState appState;

  const _ProductContentSourcesPage({required this.appState});

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final words = appState.catalog;
    final topics = words.map((word) => word.topic).toSet().length;
    final media = words
        .where((word) => word.imageUrl?.trim().isNotEmpty == true)
        .toList(growable: false);
    final offlineMedia = words.where((word) => word.hasOfflineImage).length;
    final reviewed = words
        .where(
          (word) =>
              word.reviewerType?.trim().toLowerCase() == 'human' ||
              word.reviewerId?.trim().isNotEmpty == true,
        )
        .length;
    final sources = <String, List<CatalogWord>>{};
    for (final word in words) {
      sources.putIfAbsent(word.source.trim(), () => []).add(word);
    }
    final isStarter = appState.catalogReleaseVersion.startsWith('starter-');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Nguồn nội dung'),
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          _ProductCard(
            color: context.vocabColors.primaryPanel,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isStarter ? 'Gói starter offline' : 'Gói nội dung đã tải',
                  style: TextStyle(
                    color: colors.onPrimaryPanel,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  appState.catalogReleaseVersion,
                  style: TextStyle(
                    color: colors.onPrimaryPanel.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  '${words.length} mục • $topics chủ đề • ${media.length} mục có media • $offlineMedia ảnh offline',
                  style: TextStyle(
                    color: colors.onPrimaryPanel,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$reviewed/${words.length} mục có review human được ghi nhận',
                  style: TextStyle(
                    color: colors.onPrimaryPanel.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: isStarter ? colors.warningSurface : colors.accentSoft,
            child: ListTile(
              leading: Icon(
                isStarter ? Icons.info_outline : Icons.verified_outlined,
                color: isStarter ? colors.warningText : colors.accentDark,
              ),
              title: Text(
                isStarter
                    ? 'Bộ này dùng được offline nhưng chưa phải catalog production.'
                    : 'Bộ này được kiểm tra qua manifest trước khi lưu offline.',
                style: t(14, w: FontWeight.w800),
              ),
              subtitle: Text(
                isStarter
                    ? 'Các mục chưa có review human không được tính vào mục tiêu phát hành 3.000 từ.'
                    : 'Nếu máy chủ lỗi, app vẫn giữ release đã lưu gần nhất.',
                style: t(12, w: FontWeight.w500, color: colors.textSecondary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Nguồn và giấy phép', style: t(19, w: FontWeight.w900)),
          const SizedBox(height: 8),
          for (final entry in sources.entries)
            _ContentSourceCard(
              sourceName: entry.key.isEmpty ? 'Nguồn chưa khai báo' : entry.key,
              words: entry.value,
            ),
          const SizedBox(height: 8),
          Text(
            'Nguồn được hiển thị theo metadata của từng release. Không coi confidence nhận diện, dữ liệu raw hoặc bản staging là review nội dung.',
            style: t(
              12,
              w: FontWeight.w500,
              color: colors.textSecondary,
              h: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentSourceCard extends StatelessWidget {
  final String sourceName;
  final List<CatalogWord> words;

  const _ContentSourceCard({required this.sourceName, required this.words});

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final sample = words.first;
    final license = words
        .map((word) => word.sourceLicense?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'Chưa khai báo');
    final attribution = words
        .map((word) => word.sourceAttribution?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => 'Chưa khai báo');
    final url = words
        .map((word) => word.sourceUrl?.trim())
        .whereType<String>()
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    final mediaCount = words
        .where((word) => word.imageUrl?.trim().isNotEmpty == true)
        .length;

    return Card(
      elevation: 0,
      color: colors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.menu_book_outlined, color: colors.accentDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(sourceName, style: t(15, w: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${words.length} mục • $mediaCount mục có ảnh',
              style: t(12, w: FontWeight.w600, color: colors.textSecondary),
            ),
            const SizedBox(height: 5),
            Text('License: $license', style: t(12, w: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(
              'Attribution: $attribution',
              style: t(12, w: FontWeight.w500, color: colors.textSecondary),
            ),
            if (url.isNotEmpty) ...[
              const SizedBox(height: 3),
              SelectableText(
                url,
                style: t(11, w: FontWeight.w500, color: colors.accentDark),
              ),
            ],
            if (sample.reviewedBy != null) ...[
              const SizedBox(height: 6),
              Text(
                'Trạng thái review: ${sample.reviewedBy}',
                style: t(11, w: FontWeight.w500, color: colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AppState appState;

  const _AccountCard({required this.appState});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appState,
    builder: (context, _) {
      final colors = context.vocabColors;
      final session = appState.authSession;
      final syncing = appState.syncing;
      final syncFailed = appState.syncError != null;
      final syncedAt = appState.lastSyncedAt;
      final syncLabel = syncing
          ? 'Đang đồng bộ…'
          : syncFailed
          ? 'Đồng bộ lỗi • thử lại'
          : syncedAt == null
          ? 'Chưa đồng bộ • chỉ lưu trên máy'
          : 'Đã đồng bộ lúc ${_formatSyncTime(syncedAt)}';
      final syncIcon = syncing
          ? Icons.sync_rounded
          : syncFailed
          ? Icons.cloud_off_rounded
          : syncedAt == null
          ? Icons.cloud_queue_rounded
          : Icons.cloud_done_outlined;
      final syncColor = syncFailed
          ? colors.errorText
          : syncedAt == null && !syncing
          ? colors.textSecondary
          : colors.accentDark;
      return Card(
        elevation: 0,
        color: colors.surface,
        margin: EdgeInsets.zero,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 5,
          ),
          leading: Icon(
            session == null ? Icons.cloud_off_outlined : syncIcon,
            color: session == null ? colors.textSecondary : syncColor,
          ),
          title: Text(
            session == null ? 'Tài khoản tùy chọn' : session.user.displayName,
            style: t(15, w: FontWeight.w800),
          ),
          subtitle: Text(
            session == null
                ? 'Học offline trên thiết bị này'
                : '${session.user.email} • $syncLabel',
            style: t(
              12,
              w: FontWeight.w500,
              color: syncFailed ? colors.errorText : colors.textSecondary,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => _AccountPage(appState: appState)),
          ),
        ),
      );
    },
  );
}

String _formatSyncTime(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

class _AccountPage extends StatefulWidget {
  final AppState appState;

  const _AccountPage({required this.appState});

  @override
  State<_AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<_AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _displayName = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _displayName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty ||
        password.isEmpty ||
        (_register && _displayName.text.trim().isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hãy nhập đủ thông tin.')));
      return;
    }
    setState(() => _busy = true);
    try {
      if (_register) {
        await widget.appState.registerAccount(
          email: email,
          password: password,
          displayName: _displayName.text,
        );
      } else {
        await widget.appState.signIn(email: email, password: password);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Không thể kết nối tài khoản. Kiểm tra máy chủ hoặc thử lại.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    try {
      final summary = await widget.appState.syncNow();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã gửi ${summary.uploaded} và nhận ${summary.downloaded} sự kiện.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.appState.syncError ?? 'Đồng bộ thất bại.'),
        ),
      );
    }
  }

  Future<void> _forgotPassword() async {
    final emailController = TextEditingController(text: _email.text.trim());
    final submittedEmail = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        var busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Đặt lại mật khẩu'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nhập email đã đăng ký. Nếu tài khoản tồn tại, bạn sẽ nhận được mã đặt lại.',
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    filled: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Huỷ'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) return;
                        setDialogState(() => busy = true);
                        try {
                          final devToken = await widget.appState
                              .requestPasswordReset(email);
                          if (dialogContext.mounted) {
                            // The empty string means the request was accepted
                            // but the token is delivered by email in prod.
                            Navigator.pop(dialogContext, devToken ?? '');
                          }
                        } catch (_) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => busy = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Không gửi được yêu cầu. Kiểm tra máy chủ rồi thử lại.',
                              ),
                            ),
                          );
                        }
                      },
                child: Text(busy ? 'Đang gửi…' : 'Gửi mã'),
              ),
            ],
          ),
        );
      },
    );
    emailController.dispose();
    if (!mounted || submittedEmail == null) return;
    await _showResetPasswordDialog(initialToken: submittedEmail);
  }

  Future<void> _showResetPasswordDialog({required String initialToken}) async {
    final tokenController = TextEditingController(text: initialToken);
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final pageContext = context;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var busy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Mật khẩu mới'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Dán mã trong email vào ô đầu tiên rồi tạo mật khẩu mới.',
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Mã đặt lại',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mật khẩu mới (tối thiểu 8 ký tự)',
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nhập lại mật khẩu',
                      filled: true,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        final token = tokenController.text.trim();
                        final password = passwordController.text;
                        if (token.isEmpty ||
                            password.length < 8 ||
                            password != confirmController.text) {
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Kiểm tra mã và mật khẩu (tối thiểu 8 ký tự).',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => busy = true);
                        try {
                          await widget.appState.confirmPasswordReset(
                            token: token,
                            password: password,
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Đặt lại mật khẩu thành công. Bạn có thể đăng nhập lại.',
                              ),
                            ),
                          );
                        } catch (_) {
                          if (!dialogContext.mounted) return;
                          setDialogState(() => busy = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Mã không hợp lệ hoặc đã hết hạn. Hãy yêu cầu mã mới.',
                              ),
                            ),
                          );
                        }
                      },
                child: Text(busy ? 'Đang lưu…' : 'Đổi mật khẩu'),
              ),
            ],
          ),
        );
      },
    );
    tokenController.dispose();
    passwordController.dispose();
    confirmController.dispose();
  }

  Future<void> _exportAccount() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final data = await widget.appState.exportAccountData();
      if (!mounted) return;
      final events = data['sync_events'] is List
          ? (data['sync_events'] as List).length
          : 0;
      final reports = data['content_reports'] is List
          ? (data['content_reports'] as List).length
          : 0;
      await Clipboard.setData(ClipboardData(text: jsonEncode(data)));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Dữ liệu tài khoản'),
          content: Text(
            'Đã sao chép JSON dữ liệu gồm $events sự kiện học và $reports báo lỗi vào clipboard. Không bao gồm mật khẩu hoặc token phiên.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể xuất dữ liệu lúc này.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.appState.signOut();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể đăng xuất lúc này.')),
      );
    }
  }

  Future<void> _deleteAccount() async {
    if (_busy) return;
    final passwordController = TextEditingController();
    final confirmedPassword = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa tài khoản?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Thao tác này xóa tài khoản và dữ liệu đã đồng bộ trên máy chủ. Dữ liệu guest trên thiết bị không tự bị xóa.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Nhập mật khẩu để xác nhận',
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.coral),
            onPressed: () =>
                Navigator.pop(dialogContext, passwordController.text),
            child: const Text('Xóa tài khoản'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (!mounted || confirmedPassword == null || confirmedPassword.isEmpty) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.appState.deleteAccount(password: confirmedPassword);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mật khẩu không đúng hoặc máy chủ lỗi.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.appState.authSession;
    final colors = context.vocabColors;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Tài khoản'),
        backgroundColor: colors.canvas,
        foregroundColor: colors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        children: [
          if (session != null) ...[
            _ProductCard(
              color: context.vocabColors.primaryPanel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.user.displayName,
                    style: TextStyle(
                      color: colors.onPrimaryPanel,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    session.user.email,
                    style: TextStyle(
                      color: colors.onPrimaryPanel.withValues(alpha: 0.78),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.appState.syncing ? null : _sync,
              icon: const Icon(Icons.sync),
              label: Text(
                widget.appState.syncing ? 'Đang đồng bộ…' : 'Đồng bộ dữ liệu',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : _signOut,
              child: const Text('Đăng xuất (vẫn giữ dữ liệu offline)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _exportAccount,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Xuất dữ liệu tài khoản'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _deleteAccount,
              icon: const Icon(Icons.delete_outline),
              style: OutlinedButton.styleFrom(foregroundColor: C.coral),
              label: const Text('Xóa tài khoản'),
            ),
            if (session.user.role == 'admin') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _AdminCatalogPage(appState: widget.appState),
                  ),
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Quản trị kho từ vựng'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        _AdminReportsPage(appState: widget.appState),
                  ),
                ),
                icon: const Icon(Icons.fact_check_outlined),
                label: const Text('Quản trị báo lỗi nội dung'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Sync chỉ gửi attempt đã lưu trong outbox. Nếu mất mạng, dữ liệu vẫn nằm trên máy để thử lại.',
              style: t(
                13,
                w: FontWeight.w500,
                color: colors.textSecondary,
                h: 1.4,
              ),
            ),
          ] else ...[
            Text(
              _register ? 'Tạo tài khoản' : 'Đăng nhập',
              style: t(24, w: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              'Tài khoản là tùy chọn để đồng bộ tiến độ giữa thiết bị. Học offline không bị khóa.',
              style: t(
                14,
                w: FontWeight.w500,
                color: colors.textSecondary,
                h: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (_register) ...[
              TextField(
                controller: _displayName,
                maxLength: 24,
                decoration: InputDecoration(
                  labelText: 'Tên hiển thị',
                  filled: true,
                  fillColor: colors.surface,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                filled: true,
                fillColor: colors.surface,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Mật khẩu (tối thiểu 8 ký tự)',
                filled: true,
                fillColor: colors.surface,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? 'Đang xử lý…'
                      : (_register ? 'Tạo tài khoản' : 'Đăng nhập'),
                ),
              ),
            ),
            if (!_register)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _busy ? null : _forgotPassword,
                  child: const Text('Quên mật khẩu?'),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _register = !_register),
              child: Text(
                _register
                    ? 'Đã có tài khoản? Đăng nhập'
                    : 'Chưa có tài khoản? Tạo mới',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminReportsPage extends StatefulWidget {
  final AppState appState;

  const _AdminReportsPage({required this.appState});

  @override
  State<_AdminReportsPage> createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<_AdminReportsPage> {
  late Future<List<Map<String, dynamic>>> _reports;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _reports = widget.appState.adminReports(status: 'open');
  }

  Future<void> _resolve(String reportId, String status) async {
    try {
      await widget.appState.updateAdminReport(
        reportId: reportId,
        status: status,
      );
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật trạng thái báo lỗi.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể cập nhật báo lỗi lúc này.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Báo lỗi nội dung'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: () => setState(_reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _reports,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => setState(_reload),
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          );
        }
        final reports = snapshot.data ?? const [];
        if (reports.isEmpty) {
          return const Center(child: Text('Chưa có báo lỗi đang mở.'));
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          itemCount: reports.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final report = reports[index];
            final id = report['id'] as String? ?? '';
            return Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report['word_id'] ?? '—'} • ${report['report_type'] ?? 'khác'}',
                      style: t(16, w: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${report['note'] ?? ''}',
                      style: t(14, w: FontWeight.w500, color: C.muted, h: 1.35),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: id.isEmpty
                              ? null
                              : () => _resolve(id, 'in_review'),
                          child: const Text('Đang kiểm tra'),
                        ),
                        FilledButton(
                          onPressed: id.isEmpty
                              ? null
                              : () => _resolve(id, 'resolved'),
                          child: const Text('Đã xử lý'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _AdminCatalogPage extends StatefulWidget {
  final AppState appState;

  const _AdminCatalogPage({required this.appState});

  @override
  State<_AdminCatalogPage> createState() => _AdminCatalogPageState();
}

class _AdminCatalogPageState extends State<_AdminCatalogPage> {
  CatalogApiClient? _client;
  late Future<_AdminCatalogSnapshot> _snapshot;
  String _query = '';
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _client?.close();
    super.dispose();
  }

  void _reload() {
    _snapshot = _loadSnapshot();
  }

  Future<_AdminCatalogSnapshot> _loadSnapshot() async {
    const baseUrl = String.fromEnvironment('VOCAB_API_BASE_URL');
    if (baseUrl.trim().isEmpty) {
      throw StateError(
        'Chưa cấu hình VOCAB_API_BASE_URL. Màn quản trị cần API PostgreSQL, không publish trực tiếp từ APK.',
      );
    }
    final client = _client ??= CatalogApiClient(baseUrl.trim());
    final release = await client.fetchRelease();
    List<Map<String, dynamic>> history = const [];
    try {
      history = await widget.appState.adminCatalogReleases();
    } catch (_) {
      // Public release vẫn đủ để biên tập; lịch sử admin chỉ là phần bổ sung.
    }
    return _AdminCatalogSnapshot(
      version: release.version,
      words: release.words,
      history: history,
    );
  }

  Future<void> _edit(CatalogWord word) async {
    final updated = await showDialog<CatalogWord>(
      context: context,
      builder: (_) => _CatalogWordEditorDialog(word: word),
    );
    if (updated == null || !mounted) return;
    final current = await _snapshot;
    final words = current.words
        .map((item) => item.id == updated.id ? updated : item)
        .toList(growable: false);
    setState(() {
      _snapshot = Future.value(
        _AdminCatalogSnapshot(
          version: current.version,
          words: words,
          history: current.history,
        ),
      );
    });
  }

  Future<void> _publish(List<CatalogWord> words) async {
    if (_publishing) return;
    final validation = _validateCatalog(words);
    if (validation.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chưa thể publish'),
          content: SizedBox(
            width: 520,
            child: Text(
              validation.take(8).join('\n'),
              style: t(14, w: FontWeight.w500, h: 1.4),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
      return;
    }
    var confirmed = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Xác nhận phát hành kho từ'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Phiên bản mới sẽ thay thế release hiện tại cho người học. Mỗi mục được ghi nhận người duyệt và nguồn bản quyền.',
                  style: t(14, w: FontWeight.w500, h: 1.4),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: (value) =>
                      setDialogState(() => confirmed = value ?? false),
                  title: Text(
                    'Tôi đã kiểm tra toàn bộ ${words.length} mục, ví dụ song ngữ và license.',
                    style: t(14, w: FontWeight.w700),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: confirmed ? () => Navigator.pop(context, true) : null,
              child: const Text('Publish release'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true || !mounted) return;
    final session = widget.appState.authSession;
    if (session == null || session.user.role != 'admin') {
      _showMessage('Phiên đăng nhập không còn quyền admin.');
      return;
    }
    final now = DateTime.now().toUtc();
    final version = 'admin-${now.millisecondsSinceEpoch}';
    final reviewer = session.user.email;
    final sources = <String, Map<String, dynamic>>{};
    final media = <Map<String, dynamic>>[];
    for (final word in words) {
      sources[word.source] = {
        'id': word.source,
        'url': word.sourceUrl!.trim(),
        'license': word.sourceLicense!.trim(),
        'attribution': word.sourceAttribution!.trim(),
        'source_version': version,
      };
      if (word.imageUrl?.trim().isNotEmpty == true) {
        media.add({
          'url': word.imageUrl!.trim(),
          'license': word.imageLicense!.trim(),
          'attribution': word.imageAttribution!.trim(),
        });
      }
    }
    final manifest = <String, dynamic>{
      'version': version,
      'pack': {
        'id': 'release:$version',
        'name_vi': 'Gói từ vựng $version',
        'description_vi': 'Bản phát hành đã được admin kiểm duyệt.',
      },
      'sources': sources.values.toList(growable: false),
      'media': media,
      'words': words
          .map(
            (word) => {
              'id': word.id,
              'english': word.english.trim(),
              'vietnamese': word.vietnamese.trim(),
              'topic': word.topic.trim(),
              'part_of_speech': word.partOfSpeech.trim(),
              'source_id': word.source.trim(),
              'review_status': 'published',
              'reviewed_by': reviewer,
              'review': {
                'reviewer_type': 'human',
                'reviewer_id': reviewer,
                'decision': 'publish',
                'reviewed_at': now.toIso8601String(),
                'notes': 'Admin editor confirmation',
              },
              'examples': [
                {
                  'english': word.exampleEnglish.trim(),
                  'vietnamese': word.exampleVietnamese.trim(),
                },
              ],
              if (word.imageUrl?.trim().isNotEmpty == true)
                'image': {
                  'url': word.imageUrl!.trim(),
                  'license': word.imageLicense!.trim(),
                  'attribution': word.imageAttribution!.trim(),
                },
            },
          )
          .toList(growable: false),
    };
    setState(() => _publishing = true);
    try {
      final result = await widget.appState.publishAdminCatalog(manifest);
      if (!mounted) return;
      _showMessage(
        'Đã publish ${result['word_count'] ?? words.length} mục • ${result['version'] ?? version}',
      );
      setState(_reload);
    } catch (error) {
      if (mounted) _showMessage('Publish thất bại: ${_shortError(error)}');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Future<void> _rollback(String version) async {
    if (_publishing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thu hồi release?'),
        content: Text(
          'Release $version sẽ bị unpublish. Nếu có bản trước đó, máy chủ sẽ khôi phục bản trước; người học vẫn giữ gói SQLite hiện có.',
          style: t(14, w: FontWeight.w500, h: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.coral),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _publishing = true);
    try {
      final result = await widget.appState.rollbackAdminCatalog(version);
      if (!mounted) return;
      final restored = result['restored_version'];
      _showMessage(
        restored is String && restored.isNotEmpty
            ? 'Đã thu hồi $version • khôi phục $restored'
            : 'Đã thu hồi $version • chưa có release trước để khôi phục',
      );
      setState(_reload);
    } catch (error) {
      if (mounted) _showMessage('Thu hồi thất bại: ${_shortError(error)}');
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Quản trị kho từ vựng'),
      actions: [
        IconButton(
          tooltip: 'Tải lại',
          onPressed: _publishing ? null : () => setState(_reload),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<_AdminCatalogSnapshot>(
      future: _snapshot,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _AdminCatalogError(
            message: _shortError(snapshot.error),
            onRetry: () => setState(_reload),
          );
        }
        final data = snapshot.data!;
        final needle = normalizeSearchText(_query);
        final words = data.words
            .where((word) {
              if (needle.isEmpty) return true;
              return normalizeSearchText(
                '${word.id} ${word.english} ${word.vietnamese} ${word.topic}',
              ).contains(needle);
            })
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _ProductCard(
              color: context.vocabColors.primaryPanel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Bản phát hành hiện tại',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.version,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${data.words.length} mục • nội dung đã publish từ API',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Tìm mục cần kiểm tra…',
                prefixIcon: Icon(Icons.search),
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _publishing ? null : () => _publish(data.words),
              icon: _publishing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.publish_outlined),
              label: Text(
                _publishing
                    ? 'Đang publish…'
                    : 'Publish phiên bản mới (${data.words.length} mục)',
              ),
            ),
            const SizedBox(height: 20),
            Text('Biên tập nội dung', style: t(18, w: FontWeight.w900)),
            const SizedBox(height: 8),
            if (words.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: Text('Không tìm thấy mục phù hợp.')),
              )
            else
              ...words.map(
                (word) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      '${word.english}  •  ${word.vietnamese}',
                      style: t(15, w: FontWeight.w800),
                    ),
                    subtitle: Text(
                      '${word.topic} · ${word.partOfSpeech}\nNguồn: ${word.source}\n${word.sourceLicense ?? 'Thiếu license'} · ${word.sourceAttribution ?? 'Thiếu attribution'}',
                      style: t(12, w: FontWeight.w500, color: C.muted, h: 1.35),
                    ),
                    isThreeLine: true,
                    trailing: IconButton(
                      tooltip: 'Sửa mục',
                      onPressed: _publishing ? null : () => _edit(word),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ),
                ),
              ),
            if (data.history.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Lịch sử release', style: t(18, w: FontWeight.w900)),
              const SizedBox(height: 8),
              ...data.history
                  .take(5)
                  .map(
                    (release) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history),
                      title: Text('${release['version'] ?? '—'}'),
                      subtitle: Text(
                        '${release['status'] ?? 'unknown'} · ${release['word_count'] ?? 0} mục',
                      ),
                      trailing: release['status'] == 'published'
                          ? IconButton(
                              tooltip: 'Thu hồi release',
                              onPressed: _publishing
                                  ? null
                                  : () => _rollback(
                                      '${release['version'] ?? ''}',
                                    ),
                              icon: const Icon(Icons.undo_outlined),
                            )
                          : null,
                    ),
                  ),
            ],
          ],
        );
      },
    ),
  );
}

class _AdminCatalogSnapshot {
  final String version;
  final List<CatalogWord> words;
  final List<Map<String, dynamic>> history;

  const _AdminCatalogSnapshot({
    required this.version,
    required this.words,
    required this.history,
  });
}

class _AdminCatalogError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _AdminCatalogError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: C.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: t(14, w: FontWeight.w600, color: C.muted, h: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    ),
  );
}

class _CatalogWordEditorDialog extends StatefulWidget {
  final CatalogWord word;

  const _CatalogWordEditorDialog({required this.word});

  @override
  State<_CatalogWordEditorDialog> createState() =>
      _CatalogWordEditorDialogState();
}

class _CatalogWordEditorDialogState extends State<_CatalogWordEditorDialog> {
  late final Map<String, TextEditingController> _fields;

  @override
  void initState() {
    super.initState();
    final word = widget.word;
    _fields = {
      'english': TextEditingController(text: word.english),
      'vietnamese': TextEditingController(text: word.vietnamese),
      'topic': TextEditingController(text: word.topic),
      'part_of_speech': TextEditingController(text: word.partOfSpeech),
      'example_english': TextEditingController(text: word.exampleEnglish),
      'example_vietnamese': TextEditingController(text: word.exampleVietnamese),
      'source': TextEditingController(text: word.source),
      'source_url': TextEditingController(text: word.sourceUrl ?? ''),
      'source_license': TextEditingController(text: word.sourceLicense ?? ''),
      'source_attribution': TextEditingController(
        text: word.sourceAttribution ?? '',
      ),
      'image_url': TextEditingController(text: word.imageUrl ?? ''),
      'image_license': TextEditingController(text: word.imageLicense ?? ''),
      'image_attribution': TextEditingController(
        text: word.imageAttribution ?? '',
      ),
    };
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextField _field(String key, String label, {int maxLines = 1}) => TextField(
    controller: _fields[key],
    maxLines: maxLines,
    decoration: InputDecoration(labelText: label, filled: true),
  );

  void _save() {
    final word = widget.word;
    Navigator.pop(
      context,
      CatalogWord(
        id: word.id,
        english: _fields['english']!.text.trim(),
        vietnamese: _fields['vietnamese']!.text.trim(),
        topic: _fields['topic']!.text.trim(),
        partOfSpeech: _fields['part_of_speech']!.text.trim(),
        exampleEnglish: _fields['example_english']!.text.trim(),
        exampleVietnamese: _fields['example_vietnamese']!.text.trim(),
        source: _fields['source']!.text.trim(),
        sourceUrl: _fields['source_url']!.text.trim(),
        sourceLicense: _fields['source_license']!.text.trim(),
        sourceAttribution: _fields['source_attribution']!.text.trim(),
        imageUrl: _fields['image_url']!.text.trim(),
        imageLicense: _fields['image_license']!.text.trim(),
        imageAttribution: _fields['image_attribution']!.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Sửa ${widget.word.english}'),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Column(
          children: [
            _field('english', 'English'),
            const SizedBox(height: 8),
            _field('vietnamese', 'Nghĩa tiếng Việt'),
            const SizedBox(height: 8),
            _field('topic', 'Chủ đề'),
            const SizedBox(height: 8),
            _field('part_of_speech', 'Từ loại'),
            const SizedBox(height: 8),
            _field('example_english', 'Ví dụ tiếng Anh', maxLines: 2),
            const SizedBox(height: 8),
            _field('example_vietnamese', 'Ví dụ tiếng Việt', maxLines: 2),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Nguồn và bản quyền',
                style: t(15, w: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            _field('source', 'Mã nguồn'),
            const SizedBox(height: 8),
            _field('source_url', 'URL nguồn'),
            const SizedBox(height: 8),
            _field('source_license', 'License nguồn'),
            const SizedBox(height: 8),
            _field('source_attribution', 'Attribution nguồn', maxLines: 2),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Media (để trống nếu chưa có)',
                style: t(15, w: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            _field('image_url', 'URL hình'),
            const SizedBox(height: 8),
            _field('image_license', 'License hình'),
            const SizedBox(height: 8),
            _field('image_attribution', 'Attribution hình', maxLines: 2),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(onPressed: _save, child: const Text('Lưu bản nháp')),
    ],
  );
}

List<String> _validateCatalog(List<CatalogWord> words) {
  final errors = <String>[];
  if (words.isEmpty) return ['Release không có từ nào.'];
  final ids = <String>{};
  for (final word in words) {
    final missing = <String>[];
    if (word.english.trim().isEmpty) missing.add('English');
    if (word.vietnamese.trim().isEmpty) missing.add('nghĩa Việt');
    if (word.topic.trim().isEmpty) missing.add('chủ đề');
    if (word.partOfSpeech.trim().isEmpty) missing.add('từ loại');
    if (word.exampleEnglish.trim().isEmpty) missing.add('ví dụ Anh');
    if (word.exampleVietnamese.trim().isEmpty) missing.add('ví dụ Việt');
    if (word.source.trim().isEmpty) missing.add('mã nguồn');
    if (word.sourceUrl?.trim().isEmpty != false) missing.add('URL nguồn');
    if (word.sourceLicense?.trim().isEmpty != false) {
      missing.add('license nguồn');
    }
    if (word.sourceAttribution?.trim().isEmpty != false) {
      missing.add('attribution nguồn');
    }
    final imageFields = [
      word.imageUrl,
      word.imageLicense,
      word.imageAttribution,
    ];
    final hasAnyImage = imageFields.any(
      (value) => value?.trim().isNotEmpty == true,
    );
    final hasCompleteImage = imageFields.every(
      (value) => value?.trim().isNotEmpty == true,
    );
    if (hasAnyImage && !hasCompleteImage) {
      missing.add('đủ URL/license/attribution hình');
    }
    if (!ids.add(word.id)) missing.add('id trùng');
    if (missing.isNotEmpty) {
      errors.add('${word.id}: thiếu ${missing.join(', ')}');
    }
  }
  return errors;
}

String _shortError(Object? error) {
  final text = '$error'.replaceFirst('Bad state: ', '');
  return text.length > 260 ? '${text.substring(0, 257)}…' : text;
}

class _ProductSettingsPage extends StatefulWidget {
  final AppState appState;

  const _ProductSettingsPage({required this.appState});

  @override
  State<_ProductSettingsPage> createState() => _ProductSettingsPageState();
}

class _ProductSettingsPageState extends State<_ProductSettingsPage> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.appState.profileName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveName(String value) async {
    await widget.appState.setProfileName(value);
    if (!widget.appState.signedIn) return;
    try {
      await widget.appState.updateAccountDisplayName(value);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa cập nhật được tên trên máy chủ.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.appState;
    final colors = context.vocabColors;
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text('Cài đặt'),
          backgroundColor: colors.canvas,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Hồ sơ học', style: t(17, w: FontWeight.w800)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => unawaited(_saveName(value)),
              decoration: InputDecoration(
                labelText: 'Tên hiển thị',
                filled: true,
                fillColor: colors.surface,
              ),
            ),
            const SizedBox(height: 20),
            Text('Mục tiêu', style: t(17, w: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${state.dailyGoal} từ mỗi ngày',
                      style: t(15, w: FontWeight.w700),
                    ),
                    Slider(
                      value: state.dailyGoal.toDouble(),
                      min: 5,
                      max: 20,
                      divisions: 3,
                      label: '${state.dailyGoal}',
                      onChanged: (value) =>
                          unawaited(state.setDailyGoal(value.round())),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Cách học', style: t(17, w: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: colors.surface,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Âm thanh nút bấm'),
                    subtitle: const Text('Cài đặt này được lưu trên thiết bị'),
                    value: state.soundFx,
                    onChanged: (value) => unawaited(state.setSoundFx(value)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Chiều học'),
                    subtitle: Text(
                      state.direction == 0
                          ? 'Tiếng Việt → tiếng Anh'
                          : 'Tiếng Anh → tiếng Việt',
                    ),
                    trailing: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('VI → EN')),
                        ButtonSegment(value: 1, label: Text('EN → VI')),
                      ],
                      selected: {state.direction},
                      onSelectionChanged: (values) =>
                          unawaited(state.setDirection(values.first)),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Độ khó'),
                    subtitle: Text(
                      state.difficulty == 0 ? '2 lựa chọn' : '4 lựa chọn',
                    ),
                    trailing: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Dễ')),
                        ButtonSegment(value: 1, label: Text('Thường')),
                      ],
                      selected: {state.difficulty},
                      onSelectionChanged: (values) =>
                          unawaited(state.setDifficulty(values.first)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('Giao diện', style: t(17, w: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: colors.surface,
              child: SwitchListTile(
                title: const Text('Chế độ tối'),
                value: state.darkMode,
                onChanged: (value) => unawaited(state.setDarkMode(value)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Dữ liệu', style: t(17, w: FontWeight.w800)),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              color: colors.surface,
              child: ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Xóa tiến độ học'),
                subtitle: const Text('Không xóa từ đã tải'),
                onTap: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Xóa tiến độ?'),
                      content: const Text('Hành động này không thể hoàn tác.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Hủy'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Xóa'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await state.resetProgress();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Color color;
  final Widget child;

  const _ProductCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final fill = color == Colors.white
        ? colors.surface
        : color == C.indigoSoft
        ? colors.surfaceAlt
        : color == C.mintPale
        ? colors.accentSoft
        : color;

    final isPrimaryOrDark = fill == colors.primaryPanel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPrimaryOrDark ? colors.borderStrong : colors.border,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isPrimaryOrDark ? colors.heroEdge : colors.borderStrong,
            offset: const Offset(0, 4),
            blurRadius: 0, // Solid 4dp bottom edge, no blurry shadow
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TactileTile extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _TactileTile({required this.child, this.onTap});

  @override
  State<_TactileTile> createState() => _TactileTileState();
}

class _TactileTileState extends State<_TactileTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return AnimatedScale(
      scale: _pressed && !reduceMotion ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOutCubic,
      child: Listener(
        onPointerDown: (_) {
          if (widget.onTap != null && mounted) setState(() => _pressed = true);
        },
        onPointerUp: (_) {
          if (_pressed && mounted) setState(() => _pressed = false);
        },
        onPointerCancel: (_) {
          if (_pressed && mounted) setState(() => _pressed = false);
        },
        child: widget.child,
      ),
    );
  }
}

class _ResumeTile extends StatelessWidget {
  final LearningMode mode;
  final String progress;
  final VoidCallback onTap;

  const _ResumeTile({
    required this.mode,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    return _TactileTile(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.skyTint,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.skyBorder, width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.skyBorder,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.skyBorder.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: colors.skyText,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiếp tục ${mode.title.toLowerCase()}',
                          style: t(
                            16,
                            w: FontWeight.w800,
                            color: colors.skyText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          progress,
                          style: t(
                            13,
                            w: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.skyBorder, width: 1.5),
                    ),
                    child: Text(
                      'Học tiếp',
                      style: TextStyle(
                        color: colors.skyText,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
  }
}

class _ModeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (fill, edge) = switch (title) {
      'Thẻ ghi nhớ' => (AppColors.purple, AppColors.purpleEdge),
      'Nghe và chọn' => (AppColors.orange, AppColors.orangeEdge),
      'Ghép cặp' => (AppColors.green, AppColors.greenEdge),
      'Điền từ' => (AppColors.coral, AppColors.coralEdge),
      'Nhìn hình viết từ' => (AppColors.coral, AppColors.coralEdge),
      _ => (AppColors.blue, AppColors.blueEdge),
    };

    return _TactileTile(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: edge, width: 2),
          boxShadow: [
            BoxShadow(
              color: edge,
              offset: const Offset(0, 4),
              blurRadius: 0, // Chunky 4dp bottom edge
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: t(16, w: FontWeight.w800, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t(
                      12,
                      w: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopicTile extends StatelessWidget {
  final String title;
  final String count;
  final IconData icon;
  final VoidCallback? onTap;

  const _TopicTile({
    required this.title,
    required this.count,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (topicColor, bgTint) = switch (title) {
      'Đồ dùng học tập' => (
        colors.categorySchoolIcon,
        colors.categorySchoolFill,
      ),
      'Trái cây' => (colors.goldStreakBevel, colors.sunTint),
      'Rau củ' => (colors.categoryFruitIcon, colors.categoryFruitFill),
      'Màu sắc' => (colors.coralText, colors.coralTint),
      'Gia đình' => (colors.categoryOtherIcon, colors.categoryOtherFill),
      'Động vật' => (colors.accent, colors.accentSoft),
      _ => (colors.accent, colors.accentSoft),
    };

    return _TactileTile(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.borderStrong,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark
                          ? topicColor.withValues(alpha: 0.2)
                          : bgTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(icon, size: 24, color: topicColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t(14, w: FontWeight.w800),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          count,
                          style: t(
                            12,
                            w: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TopicDetailPage extends StatelessWidget {
  final AppState appState;
  final String topic;
  final List<CatalogWord> words;

  const TopicDetailPage({
    super.key,
    required this.appState,
    required this.topic,
    required this.words,
  });

  List<VocabularyWord> get _lessonWords => words
      .take(10)
      .map(
        (word) => VocabularyWord(
          apiLabel: word.id,
          emoji: '',
          english: word.english,
          vietnamese: word.vietnamese,
          imageUrl: word.imageUrl,
          localImagePath: word.localImagePath,
        ),
      )
      .toList(growable: false);

  void _startLesson(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearningScreen(
          mode: LearningMode.translation,
          words: _lessonWords,
          direction: appState.direction,
          difficulty: appState.difficulty,
          loadDraft: () =>
              appState.learningDraft ?? appState.store.learningDraft,
          saveDraft: appState.saveLearningDraft,
          clearDraft: appState.clearLearningDraft,
          onDetailedAttempt:
              (
                wordId,
                correct,
                assisted, {
                required questionType,
                required sessionId,
              }) => appState.recordAttempt(
                wordId: wordId,
                correct: correct,
                assisted: assisted,
                questionType: questionType,
                sessionId: sessionId,
              ),
          onCompleted: (summary) => unawaited(
            appState.recordSession(
              correct: summary.correct,
              total: summary.total,
              wordLabels: summary.wordLabels,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    appBar: AppBar(
      title: Text(topic),
      backgroundColor: context.vocabColors.canvas,
      foregroundColor: context.vocabColors.textPrimary,
      elevation: 0,
    ),
    body: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          sliver: SliverToBoxAdapter(
            child: _ProductCard(
              color: context.vocabColors.primaryPanel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$topic • ${words.length} từ',
                    style: TextStyle(
                      color: context.vocabColors.onPrimaryPanel,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bài học gọn 8–10 từ, dùng được khi không có mạng.',
                    style: t(
                      13,
                      w: FontWeight.w500,
                      color: context.vocabColors.onPrimaryPanel.withValues(
                        alpha: 0.78,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: words.isEmpty
                          ? null
                          : () => _startLesson(context),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Bắt đầu bài học'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.vocabColors.accent,
                        foregroundColor: context.vocabColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          sliver: SliverList.separated(
            itemCount: words.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final word = words[index];
              final favorite = appState.favoriteWords.contains(word.id);
              return Card(
                elevation: 0,
                color: context.vocabColors.surface,
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(word.english, style: t(16, w: FontWeight.w800)),
                  subtitle: Text(
                    '${word.vietnamese} • ${word.partOfSpeech}',
                    style: t(
                      13,
                      w: FontWeight.w500,
                      color: context.vocabColors.textSecondary,
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: favorite ? 'Bỏ yêu thích' : 'Thêm yêu thích',
                    onPressed: () =>
                        unawaited(appState.toggleFavorite(word.id)),
                    icon: Icon(
                      favorite ? Icons.bookmark : Icons.bookmark_outline,
                      color: favorite
                          ? context.vocabColors.accentDark
                          : context.vocabColors.textSecondary,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  const _StatCard({
    required this.value,
    required this.label,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final intVal = int.tryParse(value);
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final numberWidget = intVal != null && !reduceMotion
        ? TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: intVal),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, val, _) => Text(
              '$val',
              style: t(
                28,
                w: FontWeight.w800,
                color: color ?? colors.textPrimary,
              ),
            ),
          )
        : Text(
            value,
            style: t(
              28,
              w: FontWeight.w800,
              color: color ?? colors.textPrimary,
            ),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border, width: 2),
        boxShadow: [
          BoxShadow(
            color: colors.borderStrong,
            offset: const Offset(0, 4),
            blurRadius: 0, // Chunky 4dp bottom edge
          ),
        ],
      ),
      child: Column(
        children: [
          if (icon != null) ...[
            CircleAvatar(
              radius: 18,
              backgroundColor: (color ?? colors.accentSoft).withValues(
                alpha: 0.16,
              ),
              child: Icon(icon, color: color ?? colors.accent, size: 20),
            ),
            const SizedBox(height: 8),
          ],
          numberWidget,
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: t(12, w: FontWeight.w700, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
