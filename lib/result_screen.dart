// ─────────────────────────────────────────────────────────────────────────────
// Màn hình kết quả nhận diện — bounding box, Anh–Việt, confidence
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'detection_model.dart';
import 'main.dart' show C, t;

/// Palette màu cho bounding box — khớp với chấm màu trong danh sách.
const _boxColors = <Color>[
  C.mint,
  C.coral,
  C.indigo,
  C.amber,
  C.orange,
  C.lavender,
  C.purple,
];

Color _colorForIndex(int i) => _boxColors[i % _boxColors.length];

// ─── Result Screen ───────────────────────────────────────────────────────────
class ResultScreen extends StatelessWidget {
  final File imageFile;
  final DetectionResult result;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<Detection>.from(result.detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final top = sorted.isNotEmpty ? sorted.first : null;
    final others = sorted.length > 1 ? sorted.sublist(1) : <Detection>[];

    return Scaffold(
      backgroundColor: const Color(0xFFDDFCF5),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        foregroundColor: C.navy,
        elevation: 0,
        title: Text('Kết quả nhận diện', style: t(18, w: FontWeight.w800)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: sorted.isEmpty
          ? _buildEmpty(context)
          : _buildResult(context, top!, others),
    );
  }

  // ─── Không phát hiện vật thể ──────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 72, color: C.muted),
          const SizedBox(height: 16),
          Text(
            'Chưa tìm thấy đồ dùng học tập',
            textAlign: TextAlign.center,
            style: t(18, w: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Hãy thử chụp lại với ánh sáng tốt hơn\nhoặc đưa vật thể gần camera hơn.',
            textAlign: TextAlign.center,
            style: t(13, w: FontWeight.w500, color: C.muted),
          ),
          const SizedBox(height: 24),
          _actionButton(context, 'Chụp lại', Icons.camera_alt_rounded),
        ],
      ),
    ),
  );

  // ─── Có kết quả ───────────────────────────────────────────────────────────
  Widget _buildResult(
    BuildContext context,
    Detection top,
    List<Detection> others,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          // Ảnh + bounding box
          _ImageWithBoxes(
            imageFile: imageFile,
            detections: [top, ...others],
            imageWidth: result.imageWidth,
            imageHeight: result.imageHeight,
          ),
          const SizedBox(height: 20),

          // Thẻ kết quả chính
          _topCard(top, 0),
          const SizedBox(height: 12),

          // Danh sách các vật thể khác
          if (others.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Các vật thể khác',
                  style: t(14, w: FontWeight.w700, color: C.muted),
                ),
              ),
            ),
            for (int i = 0; i < others.length; i++)
              _otherItem(others[i], i + 1),
          ],

          const SizedBox(height: 20),
          _actionButton(context, 'Chụp vật khác', Icons.camera_alt_rounded),
        ],
      ),
    );
  }

  // ─── Thẻ kết quả chính ────────────────────────────────────────────────────
  Widget _topCard(Detection d, int colorIndex) {
    final viName = vietnameseName(d.label);
    final confText =
        '${(d.confidence * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
    final isLow = d.confidence < minConfidenceThreshold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _colorForIndex(colorIndex).withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _colorForIndex(colorIndex).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Chấm màu + "Kết quả chính"
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _colorForIndex(colorIndex),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Kết quả chính',
                style: t(12, w: FontWeight.w700, color: C.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tên tiếng Anh — nổi bật
          Text(
            d.label.replaceAll('_', ' ').toUpperCase(),
            style: t(28, w: FontWeight.w900),
          ),

          // Tên tiếng Việt
          Text(
            viName,
            style: t(18, w: FontWeight.w700, color: C.indigo),
          ),
          const SizedBox(height: 8),

          // Confidence
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: isLow ? C.coralSoft : C.mintPale,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isLow ? Icons.warning_rounded : Icons.check_circle_rounded,
                  size: 16,
                  color: isLow ? C.coral : C.mint,
                ),
                const SizedBox(width: 6),
                Text(
                  isLow
                      ? '$confText • Độ tin cậy thấp'
                      : 'Độ tin cậy: $confText',
                  style: t(
                    13,
                    w: FontWeight.w700,
                    color: isLow ? C.coral : C.navy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Item vật thể khác ────────────────────────────────────────────────────
  Widget _otherItem(Detection d, int colorIndex) {
    final viName = vietnameseName(d.label);
    final confText =
        '${(d.confidence * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
    final isLow = d.confidence < minConfidenceThreshold;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        children: [
          // Chấm màu khớp bounding box
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _colorForIndex(colorIndex),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.label.replaceAll('_', ' '),
                  style: t(15, w: FontWeight.w800),
                ),
                Text(
                  viName,
                  style: t(12, w: FontWeight.w600, color: C.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isLow ? C.coralSoft : C.mintPale,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              isLow ? '$confText ⚠' : confText,
              style: t(12, w: FontWeight.w700, color: isLow ? C.coral : C.navy),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Nút hành động ────────────────────────────────────────────────────────
  Widget _actionButton(BuildContext context, String label, IconData icon) =>
      SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: C.mint,
            foregroundColor: C.navy,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          icon: Icon(icon, size: 22),
          label: Text(label, style: t(15, w: FontWeight.w800)),
        ),
      );
}

// ─── Ảnh + Bounding Box ──────────────────────────────────────────────────────
class _ImageWithBoxes extends StatelessWidget {
  final File imageFile;
  final List<Detection> detections;
  final int imageWidth;
  final int imageHeight;

  const _ImageWithBoxes({
    required this.imageFile,
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final renderW = constraints.maxWidth;
          final aspectRatio = imageWidth > 0 && imageHeight > 0
              ? imageWidth / imageHeight
              : 1.0;
          final renderH = renderW / aspectRatio;

          return SizedBox(
            width: renderW,
            height: renderH,
            child: Stack(
              children: [
                // Ảnh gốc
                Positioned.fill(
                  child: Image.file(imageFile, fit: BoxFit.cover),
                ),
                // Bounding boxes
                CustomPaint(
                  size: Size(renderW, renderH),
                  painter: _BoundingBoxPainter(
                    detections: detections,
                    imageWidth: imageWidth.toDouble(),
                    imageHeight: imageHeight.toDouble(),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Bounding Box Painter ────────────────────────────────────────────────────
class _BoundingBoxPainter extends CustomPainter {
  final List<Detection> detections;
  final double imageWidth;
  final double imageHeight;

  _BoundingBoxPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    final scaleX = size.width / imageWidth;
    final scaleY = size.height / imageHeight;

    for (int i = 0; i < detections.length; i++) {
      final d = detections[i];
      final color = _colorForIndex(i);
      final rect = Rect.fromLTRB(
        d.box[0] * scaleX,
        d.box[1] * scaleY,
        d.box[2] * scaleX,
        d.box[3] * scaleY,
      );

      // Fill bán trong suốt
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: 0.12)
          ..style = PaintingStyle.fill,
      );

      // Viền
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );

      // Góc vuông nhấn mạnh
      _drawCorners(canvas, rect, color, 14);

      // Nhãn trên box
      final label = d.label.replaceAll('_', ' ');
      final confText = '${(d.confidence * 100).toStringAsFixed(1)}%';
      final textSpan = TextSpan(
        text: '$label $confText',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 3),
          ],
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();

      // Nền nhãn
      final labelRect = Rect.fromLTWH(
        rect.left,
        math.max(rect.top - tp.height - 6, 0),
        tp.width + 10,
        tp.height + 6,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
        Paint()..color = color.withValues(alpha: 0.85),
      );
      tp.paint(canvas, Offset(labelRect.left + 5, labelRect.top + 3));
    }
  }

  void _drawCorners(Canvas c, Rect r, Color color, double len) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    // Top-left
    c.drawLine(r.topLeft, Offset(r.left + len, r.top), p);
    c.drawLine(r.topLeft, Offset(r.left, r.top + len), p);
    // Top-right
    c.drawLine(r.topRight, Offset(r.right - len, r.top), p);
    c.drawLine(r.topRight, Offset(r.right, r.top + len), p);
    // Bottom-left
    c.drawLine(r.bottomLeft, Offset(r.left + len, r.bottom), p);
    c.drawLine(r.bottomLeft, Offset(r.left, r.bottom - len), p);
    // Bottom-right
    c.drawLine(r.bottomRight, Offset(r.right - len, r.bottom), p);
    c.drawLine(r.bottomRight, Offset(r.right, r.bottom - len), p);
  }

  @override
  bool shouldRepaint(covariant _BoundingBoxPainter old) =>
      detections != old.detections;
}
