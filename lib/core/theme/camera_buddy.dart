import 'package:flutter/material.dart';

import 'app_theme.dart';

enum CameraBuddyExpression {
  idle,
  happy,
  oops,
  guiding,
  waving,
}

/// A playful original round "Camera Buddy" mascot drawn entirely with Canvas shapes.
/// Features a rounded camera body in Teal, cute ears, and a big central lens eye
/// with lively expressions in Teal and Sun.
class CameraBuddyMascot extends StatelessWidget {
  final double size;
  final CameraBuddyExpression expression;
  final String? semanticLabel;

  const CameraBuddyMascot({
    super.key,
    this.size = 56.0,
    this.expression = CameraBuddyExpression.idle,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.vocabColors;
    final label = semanticLabel ?? switch (expression) {
      CameraBuddyExpression.idle => 'Camera Buddy',
      CameraBuddyExpression.happy => 'Camera Buddy vui vẻ',
      CameraBuddyExpression.oops => 'Camera Buddy tiếc nuối',
      CameraBuddyExpression.guiding => 'Camera Buddy gợi ý',
      CameraBuddyExpression.waving => 'Camera Buddy vẫy chào',
    };

    return Semantics(
      label: label,
      image: true,
      child: CustomPaint(
        size: Size(size, size),
        painter: _CameraBuddyPainter(
          expression: expression,
          colors: colors,
        ),
      ),
    );
  }
}

class _CameraBuddyPainter extends CustomPainter {
  final CameraBuddyExpression expression;
  final VocabColors colors;

  _CameraBuddyPainter({
    required this.expression,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final scale = w / 100.0;

    // Palette
    const mascotBody = AppColors.mascotBody;
    const mascotOutline = AppColors.mascotOutline;
    final sunFill = colors.goldStreak;
    final sunEdge = colors.goldStreakBevel;
    final ink = colors.textPrimary;
    const white = Colors.white;
    final coral = colors.errorText;

    final paintBody = Paint()..color = mascotBody..style = PaintingStyle.fill;
    final paintOutline = Paint()..color = mascotOutline..style = PaintingStyle.fill;
    final paintOutlineStroke = Paint()
      ..color = mascotOutline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * scale;
    final paintSun = Paint()..color = sunFill..style = PaintingStyle.fill;
    final paintSunEdge = Paint()..color = sunEdge..style = PaintingStyle.fill;
    final paintInk = Paint()..color = ink..style = PaintingStyle.fill;
    final paintWhite = Paint()..color = white..style = PaintingStyle.fill;

    // 1. Two small rounded ears on top
    // Left ear
    final leftEarCenter = Offset(24 * scale, 20 * scale);
    canvas.drawCircle(leftEarCenter, 10 * scale, paintOutline);
    canvas.drawCircle(leftEarCenter, 8.5 * scale, paintBody);
    canvas.drawCircle(leftEarCenter, 4.5 * scale, paintSun);

    // Right ear
    final rightEarCenter = Offset(76 * scale, 20 * scale);
    canvas.drawCircle(rightEarCenter, 10 * scale, paintOutline);
    canvas.drawCircle(rightEarCenter, 8.5 * scale, paintBody);
    canvas.drawCircle(rightEarCenter, 4.5 * scale, paintSun);

    // 2. Rounded Body (chunky with 4dp bottom edge)
    final bodyRect = Rect.fromLTWH(10 * scale, 18 * scale, 80 * scale, 74 * scale);
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(26 * scale));

    // Bottom edge shadow
    final edgeRect = Rect.fromLTWH(10 * scale, 22 * scale, 80 * scale, 74 * scale);
    final edgeRRect = RRect.fromRectAndRadius(edgeRect, Radius.circular(26 * scale));
    canvas.drawRRect(edgeRRect, paintOutline);

    // Main body
    canvas.drawRRect(bodyRRect, paintBody);
    canvas.drawRRect(bodyRRect, paintOutlineStroke);

    // Subtle top body highlight
    final highlightRect = Rect.fromLTWH(16 * scale, 21 * scale, 68 * scale, 16 * scale);
    final highlightRRect = RRect.fromRectAndRadius(highlightRect, Radius.circular(12 * scale));
    canvas.drawRRect(
      highlightRRect,
      Paint()
        ..color = white.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill,
    );

    // Top flash/shutter button
    final buttonRect = Rect.fromLTWH(62 * scale, 12 * scale, 16 * scale, 8 * scale);
    final buttonRRect = RRect.fromRectAndRadius(buttonRect, Radius.circular(4 * scale));
    canvas.drawRRect(buttonRRect, paintSunEdge);
    final buttonFaceRect = Rect.fromLTWH(62 * scale, 11 * scale, 16 * scale, 7 * scale);
    canvas.drawRRect(
      RRect.fromRectAndRadius(buttonFaceRect, Radius.circular(4 * scale)),
      paintSun,
    );

    // Small sensor dot on left
    canvas.drawCircle(Offset(28 * scale, 30 * scale), 3 * scale, paintSun);

    // 3. Central Lens (Big Expressive Eye)
    final lensCenter = Offset(50 * scale, 54 * scale);
    final lensRadius = 24 * scale;

    // Outer lens bezel (Sun)
    canvas.drawCircle(lensCenter, lensRadius + 2 * scale, paintSunEdge);
    canvas.drawCircle(lensCenter, lensRadius, paintSun);

    // Inner dark lens ring
    canvas.drawCircle(lensCenter, lensRadius - 4 * scale, paintInk);

    // Lens glass
    final glassRadius = lensRadius - 7 * scale;
    canvas.drawCircle(
      lensCenter,
      glassRadius,
      Paint()..color = const Color(0xFF074840)..style = PaintingStyle.fill,
    );

    // Small white highlight on the lens
    canvas.drawCircle(
      Offset(lensCenter.dx - 8 * scale, lensCenter.dy - 8 * scale),
      2.5 * scale,
      paintWhite,
    );

    // 4. Expression within the eye / lens
    switch (expression) {
      case CameraBuddyExpression.happy:
        // Eye curved arch ^ (happy)
        final eyePath = Path();
        eyePath.moveTo(lensCenter.dx - 10 * scale, lensCenter.dy + 3 * scale);
        eyePath.quadraticBezierTo(
          lensCenter.dx,
          lensCenter.dy - 12 * scale,
          lensCenter.dx + 10 * scale,
          lensCenter.dy + 3 * scale,
        );
        canvas.drawPath(
          eyePath,
          Paint()
            ..color = white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3.5 * scale
            ..strokeCap = StrokeCap.round,
        );
        // Star sparkle in eye
        canvas.drawCircle(Offset(lensCenter.dx + 6 * scale, lensCenter.dy - 6 * scale), 2 * scale, paintSun);
        // Rosy blush cheeks outside lens
        final blushPaint = Paint()
          ..color = coral.withValues(alpha: 0.6)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(22 * scale, 64 * scale), 4.5 * scale, blushPaint);
        canvas.drawCircle(Offset(78 * scale, 64 * scale), 4.5 * scale, blushPaint);
        // Happy smile mouth below lens
        final mouthPath = Path();
        mouthPath.moveTo(44 * scale, 81 * scale);
        mouthPath.quadraticBezierTo(50 * scale, 86 * scale, 56 * scale, 81 * scale);
        canvas.drawPath(
          mouthPath,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * scale
            ..strokeCap = StrokeCap.round,
        );

      case CameraBuddyExpression.oops:
        // Worried pupil shifted and small
        canvas.drawCircle(Offset(lensCenter.dx - 2 * scale, lensCenter.dy - 2 * scale), 6 * scale, paintWhite);
        canvas.drawCircle(Offset(lensCenter.dx - 2 * scale, lensCenter.dy - 2 * scale), 3.5 * scale, paintInk);
        // Teardrop / sweat bead on upper right
        final dropPath = Path();
        dropPath.moveTo(76 * scale, 34 * scale);
        dropPath.quadraticBezierTo(82 * scale, 42 * scale, 76 * scale, 46 * scale);
        dropPath.quadraticBezierTo(70 * scale, 42 * scale, 76 * scale, 34 * scale);
        canvas.drawPath(
          dropPath,
          Paint()..color = const Color(0xFF8CC8EC)..style = PaintingStyle.fill,
        );
        // Wavy mouth
        final mouthPath = Path();
        mouthPath.moveTo(43 * scale, 82 * scale);
        mouthPath.quadraticBezierTo(46 * scale, 79 * scale, 50 * scale, 82 * scale);
        mouthPath.quadraticBezierTo(54 * scale, 85 * scale, 57 * scale, 82 * scale);
        canvas.drawPath(
          mouthPath,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * scale
            ..strokeCap = StrokeCap.round,
        );

      case CameraBuddyExpression.guiding:
        // Big curious eye with upper catchlight and pointer hint
        canvas.drawCircle(lensCenter, 8 * scale, paintSun);
        canvas.drawCircle(Offset(lensCenter.dx + 2 * scale, lensCenter.dy - 2 * scale), 4.5 * scale, paintWhite);
        canvas.drawCircle(Offset(lensCenter.dx - 3 * scale, lensCenter.dy + 3 * scale), 2 * scale, paintWhite);
        // Small gentle smile
        final mouthPath = Path();
        mouthPath.moveTo(46 * scale, 81 * scale);
        mouthPath.quadraticBezierTo(50 * scale, 84 * scale, 54 * scale, 81 * scale);
        canvas.drawPath(
          mouthPath,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * scale
            ..strokeCap = StrokeCap.round,
        );

      case CameraBuddyExpression.waving:
      case CameraBuddyExpression.idle:
        // Friendly open big eye with bright catchlights
        canvas.drawCircle(Offset(lensCenter.dx - 1 * scale, lensCenter.dy - 1 * scale), 7 * scale, paintSun);
        // Main catchlight
        canvas.drawCircle(Offset(lensCenter.dx - 4 * scale, lensCenter.dy - 4 * scale), 3.5 * scale, paintWhite);
        // Secondary catchlight
        canvas.drawCircle(Offset(lensCenter.dx + 4 * scale, lensCenter.dy + 4 * scale), 1.8 * scale, paintWhite);
        // Gentle friendly mouth
        final mouthPath = Path();
        mouthPath.moveTo(45 * scale, 81 * scale);
        mouthPath.quadraticBezierTo(50 * scale, 85 * scale, 55 * scale, 81 * scale);
        canvas.drawPath(
          mouthPath,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5 * scale
            ..strokeCap = StrokeCap.round,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _CameraBuddyPainter old) =>
      expression != old.expression || colors != old.colors;
}
