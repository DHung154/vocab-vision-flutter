import 'dart:math';

import 'package:flutter/material.dart';

import 'may_mascot.dart';

enum MayFeedbackKind { greeting, correct, incorrect, complete }

/// One answer event per keyed question; rebuilds do not replay the event.
class MayAnswerFeedback extends StatefulWidget {
  const MayAnswerFeedback({super.key, required this.correct});
  final bool correct;
  @override
  State<MayAnswerFeedback> createState() => _MayAnswerFeedbackState();
}

class _MayAnswerFeedbackState extends State<MayAnswerFeedback> {
  final _controller = MayFeedbackController();
  @override
  void initState() {
    super.initState();
    if (widget.correct) {
      _controller.playCorrect();
    } else {
      _controller.playIncorrect();
    }
  }

  @override
  Widget build(BuildContext context) => MayFeedback(
    controller: _controller,
    size: 64,
    showSpeechBubble: false,
    reduceMotion: MediaQuery.disableAnimationsOf(context),
  );
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class MayFeedbackEvent {
  const MayFeedbackEvent({required this.id, required this.kind, this.message});

  final int id;
  final MayFeedbackKind kind;
  final String? message;
}

class MayFeedbackController extends ChangeNotifier {
  int _nextId = 0;
  MayFeedbackEvent? _event;

  MayFeedbackEvent? get event => _event;

  void playGreeting({String? message}) {
    _emit(
      MayFeedbackKind.greeting,
      message: message ?? 'Xin chào! Học cùng Mây nhé!',
    );
  }

  void playCorrect({String? message}) {
    _emit(MayFeedbackKind.correct, message: message);
  }

  void playIncorrect({String? message}) {
    _emit(
      MayFeedbackKind.incorrect,
      message: message ?? 'Không sao, mình thử lại nhé!',
    );
  }

  void playComplete({String? message}) {
    _emit(
      MayFeedbackKind.complete,
      message: message ?? 'Hoàn thành rồi! Em giỏi lắm!',
    );
  }

  void clear() {
    if (_event == null) return;
    _event = null;
    notifyListeners();
  }

  void clearIf(int id) {
    if (_event?.id == id) {
      clear();
    }
  }

  void _emit(MayFeedbackKind kind, {String? message}) {
    _event = MayFeedbackEvent(id: ++_nextId, kind: kind, message: message);
    notifyListeners();
  }
}

class MayFeedback extends StatefulWidget {
  const MayFeedback({
    super.key,
    required this.controller,
    this.size = 180,
    this.visible = true,
    this.reduceMotion = false,
    this.onEventCompleted,
    this.showSpeechBubble = true,
  });

  final MayFeedbackController controller;
  final double size;
  final bool visible;
  final bool reduceMotion;
  final ValueChanged<MayFeedbackEvent>? onEventCompleted;
  final bool showSpeechBubble;

  @override
  State<MayFeedback> createState() => _MayFeedbackState();
}

class _MayFeedbackState extends State<MayFeedback>
    with SingleTickerProviderStateMixin {
  static const List<String> _praises = <String>[
    'Đúng rồi!',
    'Giỏi quá!',
    'Tuyệt vời!',
    'Em làm được rồi!',
  ];

  final Random _random = Random();
  late final AnimationController _effectController;
  static final List<MayAnimation> _correctBag = <MayAnimation>[];

  MayFeedbackEvent? _activeEvent;
  MayAnimation _activeAnimation = MayAnimation.idle;
  int _replayId = 0;
  String? _bubbleText;
  bool _showBubble = false;

  @override
  void initState() {
    super.initState();
    _effectController = AnimationController(vsync: this);
    widget.controller.addListener(_onControllerChanged);
    if (_correctBag.isEmpty) _refillCorrectBag();
    _onControllerChanged();
  }

  @override
  void didUpdateWidget(covariant MayFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  void _refillCorrectBag() {
    _correctBag
      ..clear()
      ..addAll(const <MayAnimation>[
        MayAnimation.correctJump,
        MayAnimation.correctThumbs,
        MayAnimation.correctClap,
        MayAnimation.correctVictory,
        MayAnimation.memeSurprised,
        MayAnimation.memeLaugh,
      ])
      ..shuffle(_random);
  }

  MayAnimation _takeNextCorrectAnimation() {
    if (_correctBag.isEmpty) {
      _refillCorrectBag();
    }
    return _correctBag.removeLast();
  }

  void _onControllerChanged() {
    final next = widget.controller.event;
    if (next == null) {
      if (mounted && _activeEvent != null) {
        setState(() {
          _activeEvent = null;
          _showBubble = false;
        });
      }
      return;
    }
    if (_activeEvent?.id == next.id) return;

    final animation = _pickAnimation(next);
    final text = _pickMessage(next);
    _effectController
      ..stop()
      ..duration = _durationFor(next.kind)
      ..forward(from: 0);

    setState(() {
      _activeEvent = next;
      _activeAnimation = animation;
      _bubbleText = text;
      _showBubble = true;
      _replayId++;
    });
  }

  MayAnimation _pickAnimation(MayFeedbackEvent event) {
    switch (event.kind) {
      case MayFeedbackKind.greeting:
        return MayAnimation.greetWave;
      case MayFeedbackKind.correct:
        return _takeNextCorrectAnimation();
      case MayFeedbackKind.incorrect:
        return _random.nextBool()
            ? MayAnimation.incorrectEncourage
            : MayAnimation.memePout;
      case MayFeedbackKind.complete:
        return MayAnimation.completeCelebrate;
    }
  }

  String _pickMessage(MayFeedbackEvent event) {
    if (event.message != null && event.message!.trim().isNotEmpty) {
      return event.message!;
    }
    switch (event.kind) {
      case MayFeedbackKind.greeting:
        return 'Xin chào! Học cùng Mây nhé!';
      case MayFeedbackKind.correct:
        return _praises[_random.nextInt(_praises.length)];
      case MayFeedbackKind.incorrect:
        return 'Không sao, mình thử lại nhé!';
      case MayFeedbackKind.complete:
        return 'Hoàn thành rồi! Em giỏi lắm!';
    }
  }

  Duration _durationFor(MayFeedbackKind kind) {
    switch (kind) {
      case MayFeedbackKind.greeting:
        return const Duration(milliseconds: 1600);
      case MayFeedbackKind.correct:
        return const Duration(milliseconds: 1500);
      case MayFeedbackKind.incorrect:
        return const Duration(milliseconds: 1800);
      case MayFeedbackKind.complete:
        return const Duration(milliseconds: 2400);
    }
  }

  void _handleClipCompleted(MayAnimation _) {
    final finished = _activeEvent;
    if (finished == null) return;
    widget.onEventCompleted?.call(finished);
    widget.controller.clearIf(finished.id);
    if (mounted) {
      setState(() {
        _showBubble = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();
    final active = _activeEvent;
    return SizedBox(
      width: widget.size * 1.5,
      height: widget.size * 1.55,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          if (active != null && !widget.reduceMotion)
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _MayFeedbackEffectPainter(
                      kind: active.kind,
                      progress: _effectController,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            child: MayMascot(
              animation: active == null ? MayAnimation.idle : _activeAnimation,
              replayId: _replayId,
              size: widget.size,
              reduceMotion: widget.reduceMotion,
              autoReturnToIdle: true,
              onCompleted: _handleClipCompleted,
            ),
          ),
          if (widget.showSpeechBubble &&
              active != null &&
              _bubbleText != null &&
              _showBubble)
            Positioned(
              top: 0,
              left: 8,
              right: 8,
              child: _MaySpeechBubble(text: _bubbleText!),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _effectController.dispose();
    super.dispose();
  }
}

class _MaySpeechBubble extends StatelessWidget {
  const _MaySpeechBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: text,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFB8D8F8), width: 2),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2B4C73),
                ),
              ),
            ),
            Positioned(
              bottom: -10,
              left: 26,
              child: Transform.rotate(
                angle: 0.25,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFB8D8F8),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MayFeedbackEffectPainter extends CustomPainter {
  _MayFeedbackEffectPainter({required this.kind, required this.progress})
    : super(repaint: progress);

  final MayFeedbackKind kind;
  final Animation<double> progress;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value.clamp(0.0, 1.0);
    switch (kind) {
      case MayFeedbackKind.correct:
        _paintCorrect(canvas, size, p);
        break;
      case MayFeedbackKind.incorrect:
        _paintIncorrect(canvas, size, p);
        break;
      case MayFeedbackKind.complete:
        _paintComplete(canvas, size, p);
        break;
      case MayFeedbackKind.greeting:
        _paintGreeting(canvas, size, p);
        break;
    }
  }

  void _paintCorrect(Canvas canvas, Size size, double p) {
    final paint = Paint()
      ..color = Colors.amber.withValues(alpha: (1 - p * 0.5).clamp(0.3, 1.0));
    final stars = <Offset>[
      Offset(size.width * 0.22, size.height * (0.62 - 0.18 * p)),
      Offset(size.width * 0.32, size.height * (0.42 - 0.10 * p)),
      Offset(size.width * 0.70, size.height * (0.44 - 0.14 * p)),
      Offset(size.width * 0.82, size.height * (0.64 - 0.18 * p)),
      Offset(size.width * 0.56, size.height * (0.30 - 0.08 * p)),
    ];
    for (var i = 0; i < stars.length; i++) {
      final radius = 9 + (i % 2) * 3.0 + 4 * sin(pi * p);
      _drawStar(canvas, stars[i], radius, paint);
    }
  }

  void _paintIncorrect(Canvas canvas, Size size, double p) {
    if (p > 0.52) return;
    final opacity = (1 - p / 0.52).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = const Color(0xFF7EDBFF).withValues(alpha: opacity);
    final left = Offset(
      size.width * 0.45,
      size.height * (0.58 + 0.12 * p / 0.52),
    );
    final right = Offset(
      size.width * 0.56,
      size.height * (0.60 + 0.12 * p / 0.52),
    );
    _drawDrop(canvas, left, 8, paint);
    if (p > 0.14) {
      _drawDrop(canvas, right, 7, paint);
    }
  }

  void _paintComplete(Canvas canvas, Size size, double p) {
    _paintCorrect(canvas, size, p * 0.8);
    final colors = <Color>[
      Colors.amber,
      Colors.cyan,
      Colors.pinkAccent,
      Colors.greenAccent,
    ];
    for (var i = 0; i < 28; i++) {
      final fx = (i % 7) / 6.0;
      final fy = (i ~/ 7) / 3.0;
      final dx = size.width * (0.12 + fx * 0.76);
      final dy =
          size.height * (0.08 + fy * 0.16 + p * 0.52 + sin((p + i) * pi) * 8);
      final rect = Rect.fromCenter(
        center: Offset(dx, dy),
        width: 6,
        height: 10,
      );
      final paint = Paint()
        ..color = colors[i % colors.length].withValues(
          alpha: (1 - p).clamp(0.1, 1.0),
        );
      canvas.save();
      canvas.translate(rect.center.dx, rect.center.dy);
      canvas.rotate((i * 17) * pi / 180);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: rect.width,
          height: rect.height,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _paintGreeting(Canvas canvas, Size size, double p) {
    final paint = Paint()
      ..color = const Color(
        0xFF9AD2FF,
      ).withValues(alpha: (1 - p * 0.8).clamp(0.15, 0.8));
    canvas.drawCircle(
      Offset(size.width * 0.32, size.height * 0.34),
      5 + 5 * sin(pi * p),
      paint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.68, size.height * 0.28),
      4 + 4 * sin(pi * p),
      paint,
    );
  }

  void _drawDrop(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path()
      ..moveTo(center.dx, center.dy - size)
      ..quadraticBezierTo(
        center.dx + size,
        center.dy - size * 0.2,
        center.dx,
        center.dy + size,
      )
      ..quadraticBezierTo(
        center.dx - size,
        center.dy - size * 0.2,
        center.dx,
        center.dy - size,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (var i = 0; i < 5; i++) {
      final outerAngle = -pi / 2 + i * 2 * pi / 5;
      final innerAngle = outerAngle + pi / 5;
      final outer = Offset(
        center.dx + cos(outerAngle) * radius,
        center.dy + sin(outerAngle) * radius,
      );
      final inner = Offset(
        center.dx + cos(innerAngle) * radius * 0.45,
        center.dy + sin(innerAngle) * radius * 0.45,
      );
      if (i == 0) {
        path.moveTo(outer.dx, outer.dy);
      } else {
        path.lineTo(outer.dx, outer.dy);
      }
      path.lineTo(inner.dx, inner.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MayFeedbackEffectPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.progress != progress;
  }
}
