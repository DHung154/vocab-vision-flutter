// ─────────────────────────────────────────────────────────────────────────────
// Màn hình kết quả nhận diện — bounding box, Anh–Việt, confidence
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_config.dart';
import 'box_geometry.dart';
import 'catalog_data.dart';
import 'core/theme/app_theme.dart';
import 'detection_model.dart';

/// Palette màu cho bounding box và chấm trạng thái theo độ tin cậy
Color _confidenceColor(double confidence) {
  if (confidence >= 0.70) return AppColors.primaryTeal;
  if (confidence >= 0.50) return AppColors.sunFill;
  return AppColors.coralFill;
}

// ─── Result Screen ───────────────────────────────────────────────────────────
class ResultScreen extends StatefulWidget {
  final File imageFile;
  final DetectionResult result;
  final List<CatalogWord> catalog;
  final bool Function(CatalogWord word)? isFavorite;
  final Future<void> Function(CatalogWord word)? onToggleFavorite;
  final void Function(CatalogWord word)? onLearnWord;

  const ResultScreen({
    super.key,
    required this.imageFile,
    required this.result,
    this.catalog = const [],
    this.isFavorite,
    this.onToggleFavorite,
    this.onLearnWord,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  int _selectedIndex = 0;
  bool _technicalExpanded = false;

  File get imageFile => widget.imageFile;
  DetectionResult get result => widget.result;
  List<CatalogWord> get catalog => widget.catalog;

  @override
  Widget build(BuildContext context) {
    final sorted = List<Detection>.from(result.detections)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));

    final selectedIndex = sorted.isEmpty
        ? 0
        : _selectedIndex.clamp(0, sorted.length - 1);

    return Scaffold(
      backgroundColor: context.vocabColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: context.vocabColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Kết quả nhận diện',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: sorted.isEmpty
          ? _buildEmpty(context)
          : _buildResult(context, sorted, selectedIndex),
    );
  }

  // ─── Không phát hiện vật thể ──────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CameraBuddyMascot(
            size: 80,
            expression: CameraBuddyExpression.oops,
          ),
          const SizedBox(height: 20),
          const Text(
            'Chưa tìm thấy đồ dùng học tập',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hãy thử chụp lại với ánh sáng tốt hơn\nhoặc đưa vật thể gần camera hơn nhé!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.secondaryInk,
            ),
          ),
          const SizedBox(height: 20),
          _runtimeCard(),
          const SizedBox(height: 24),
          _actionButton(context, 'Chụp lại', Icons.camera_alt_rounded),
        ],
      ),
    ),
  );

  // ─── Có kết quả ───────────────────────────────────────────────────────────
  Widget _buildResult(
    BuildContext context,
    List<Detection> detections,
    int selectedIndex,
  ) {
    final selected = detections[selectedIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        children: [
          // Ảnh + bounding box
          _ImageWithBoxes(
            imageFile: imageFile,
            detections: detections,
            imageWidth: result.imageWidth,
            imageHeight: result.imageHeight,
            selectedIndex: selectedIndex,
            onBoxTap: (index) => setState(() => _selectedIndex = index),
          ),
          const SizedBox(height: 12),
          _runtimeCard(),
          const SizedBox(height: 20),

          // Thẻ kết quả chính
          _topCard(selected, selectedIndex),
          if (_catalogWord(selected) != null) ...[
            const SizedBox(height: 12),
            _catalogAction(context, _catalogWord(selected)!),
          ],
          const SizedBox(height: 16),

          // Danh sách các vật thể khác
          if (detections.length > 1) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                  'Các vật thể khác',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ),
            ),
            for (int i = 0; i < detections.length; i++)
              if (i != selectedIndex)
                _otherItem(
                  detections[i],
                  i,
                  onTap: () => setState(() => _selectedIndex = i),
                ),
          ],

          const SizedBox(height: 20),
          _actionButton(context, 'Chụp vật khác', Icons.camera_alt_rounded),
        ],
      ),
    );
  }

  Widget _runtimeCard() {
    final latency = result.latencyMs == null
        ? 'Chưa có số đo'
        : '${result.latencyMs!.toStringAsFixed(1)} ms';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardEdge,
            offset: Offset(0, 3),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _technicalExpanded = !_technicalExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: AppColors.secondaryInk,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Thông tin kỹ thuật',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _technicalExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: AppColors.secondaryInk,
                      ),
                    ),
                  ],
                ),
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: _technicalExpanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.modelLabel.isEmpty
                                      ? 'Mô hình nhận diện'
                                      : result.modelLabel,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Latency thực đo: $latency • thiết bị: ${result.device ?? 'không rõ'}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryInk,
                                  ),
                                ),
                                if (result.latencyScope != null) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Phạm vi đo: ${result.latencyScope}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondaryInk,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 3),
                                const Text(
                                  'Confidence của box không phải AP/mAP hay độ chính xác của mô hình.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryInk,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  CatalogWord? _catalogWord(Detection detection) {
    final id = detection.label.trim().toLowerCase();
    for (final word in catalog) {
      if (word.id.toLowerCase() == id) return word;
    }
    return null;
  }

  Widget _catalogAction(BuildContext context, CatalogWord word) {
    final favorite = widget.isFavorite?.call(word) ?? false;
    var saved = favorite;
    return ChunkyCard(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.english,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    word.vietnamese,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    word.exampleEnglish,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    word.exampleVietnamese,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nguồn: ${word.source}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.onLearnWord != null)
                    PlayfulButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        widget.onLearnWord!(word);
                      },
                      text: 'Học từ này',
                      icon: Icons.play_arrow_rounded,
                      variant: PlayfulButtonVariant.primary,
                      height: 52,
                    ),
                  if (widget.onToggleFavorite != null) ...[
                    const SizedBox(height: 10),
                    PlayfulButton(
                      onPressed: () async {
                        await widget.onToggleFavorite!(word);
                        if (sheetContext.mounted) {
                          setSheetState(() => saved = !saved);
                        }
                      },
                      text: saved ? 'Đã lưu từ này' : 'Lưu vào từ yêu thích',
                      icon: saved
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      variant: saved
                          ? PlayfulButtonVariant.gold
                          : PlayfulButtonVariant.neutral,
                      height: 50,
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.primaryTealTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: AppColors.primaryTealDark,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Học thêm về ${word.english}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '${word.vietnamese} • ${word.topic}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            favorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            color: favorite
                ? AppColors.sunFill
                : AppColors.secondaryInk,
          ),
        ],
      ),
    );
  }

  // ─── Thẻ kết quả chính ────────────────────────────────────────────────────
  Widget _topCard(Detection d, int colorIndex) {
    final viName = vietnameseName(d.label);
    final confPercent = d.confidence * 100;
    final confText =
        '${confPercent.toStringAsFixed(1).replaceAll('.', ',')}%';

    final Color confBg;
    final Color confFg;
    final Color confEdge;
    final IconData confIcon;
    final String confTier;
    final String? confHint;
    final bool isLow;

    if (d.confidence >= 0.70) {
      confBg = AppColors.primaryTealTint;
      confFg = AppColors.primaryTealDark;
      confEdge = AppColors.primaryTealEdge;
      confIcon = Icons.check_circle_rounded;
      confTier = 'Độ tin cậy cao';
      confHint = null;
      isLow = false;
    } else if (d.confidence >= 0.50) {
      confBg = AppColors.sunTint;
      confFg = AppColors.textOnSun;
      confEdge = AppColors.sunEdge;
      confIcon = Icons.check_circle_outline_rounded;
      confTier = 'Khá chắc';
      confHint = null;
      isLow = false;
    } else {
      confBg = AppColors.coralTint;
      confFg = AppColors.coralDark;
      confEdge = AppColors.coralEdge;
      confIcon = Icons.warning_amber_rounded;
      confTier = 'Độ tin cậy thấp';
      confHint = 'Thử chụp gần hơn nhé!';
      isLow = true;
    }

    return ChunkyCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _confidenceColor(d.confidence),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Kết quả đang chọn',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondaryInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tên tiếng Anh — nổi bật 28sp 800
          Text(
            d.label.replaceAll('_', ' ').toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),

          // Tên tiếng Việt — 18sp 700 secondary ink
          const SizedBox(height: 4),
          Text(
            viName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.secondaryInk,
            ),
          ),
          const SizedBox(height: 14),

          // Confidence Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: confBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: confEdge, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(confIcon, size: 18, color: confFg),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '$confText • $confTier',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: confFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLow && confHint != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CameraBuddyMascot(
                  size: 28,
                  expression: CameraBuddyExpression.guiding,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    confHint,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.secondaryInk,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Item vật thể khác ────────────────────────────────────────────────────
  Widget _otherItem(
    Detection d,
    int colorIndex, {
    required VoidCallback onTap,
  }) {
    final viName = vietnameseName(d.label);
    final confPercent = d.confidence * 100;
    final confText =
        '${confPercent.toStringAsFixed(1).replaceAll('.', ',')}%';
    final boxColor = _confidenceColor(d.confidence);

    final Color badgeBg;
    final Color badgeFg;
    final Color badgeEdge;
    final IconData? badgeIcon;

    if (d.confidence >= 0.70) {
      badgeBg = AppColors.primaryTealTint;
      badgeFg = AppColors.primaryTealDark;
      badgeEdge = AppColors.primaryTealEdge;
      badgeIcon = Icons.check_circle_rounded;
    } else if (d.confidence >= 0.50) {
      badgeBg = AppColors.sunTint;
      badgeFg = AppColors.textOnSun;
      badgeEdge = AppColors.sunEdge;
      badgeIcon = Icons.check_circle_outline_rounded;
    } else {
      badgeBg = AppColors.coralTint;
      badgeFg = AppColors.coralDark;
      badgeEdge = AppColors.coralEdge;
      badgeIcon = Icons.warning_amber_rounded;
    }

    return ChunkyCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      child: Row(
        children: [
          // Chấm màu khớp bounding box
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: boxColor,
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
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  viName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.secondaryInk,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeEdge, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  badgeIcon,
                  size: 14,
                  color: badgeFg,
                ),
                const SizedBox(width: 4),
                Text(
                  confText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: badgeFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Nút hành động ────────────────────────────────────────────────────────
  Widget _actionButton(BuildContext context, String label, IconData icon) {
    return PlayfulButton(
      onPressed: () => Navigator.pop(context),
      text: label,
      icon: icon,
      variant: PlayfulButtonVariant.primary,
      height: 52,
    );
  }
}

// ─── Ảnh + Bounding Box ──────────────────────────────────────────────────────
class _ImageWithBoxes extends StatelessWidget {
  final File imageFile;
  final List<Detection> detections;
  final int imageWidth;
  final int imageHeight;
  final int selectedIndex;
  final ValueChanged<int> onBoxTap;

  const _ImageWithBoxes({
    required this.imageFile,
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    required this.selectedIndex,
    required this.onBoxTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final renderW = constraints.maxWidth;
          final aspectRatio = imageWidth > 0 && imageHeight > 0
              ? imageWidth / imageHeight
              : 1.0;
          final renderH = renderW / aspectRatio;
          final canvasSize = Size(renderW, renderH);
          final imageRect = containImageRect(
            imageSize: Size(imageWidth.toDouble(), imageHeight.toDouble()),
            canvasSize: canvasSize,
          );

          return SizedBox(
            width: renderW,
            height: renderH,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) {
                final index = hitTestBox(
                  point: details.localPosition,
                  boxes: detections.map((d) => d.box).toList(growable: false),
                  imageWidth: imageWidth.toDouble(),
                  imageHeight: imageHeight.toDouble(),
                  canvasSize: canvasSize,
                  imageRect: imageRect,
                );
                if (index != null) onBoxTap(index);
              },
              child: Stack(
                children: [
                  // Nền letterbox rõ ràng để box không bị lệch khi aspect ratio
                  // của ảnh và khung hiển thị khác nhau.
                  const Positioned.fill(child: ColoredBox(color: Colors.black12)),
                  // Ảnh gốc; contain giữ toàn bộ ảnh, không crop vật thể.
                  Positioned.fill(
                    child: Image.file(imageFile, fit: BoxFit.contain),
                  ),
                  // Bounding boxes
                  CustomPaint(
                    size: canvasSize,
                    painter: _BoundingBoxPainter(
                      detections: detections,
                      imageWidth: imageWidth.toDouble(),
                      imageHeight: imageHeight.toDouble(),
                      imageRect: imageRect,
                      selectedIndex: selectedIndex,
                    ),
                  ),
                ],
              ),
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
  final Rect imageRect;
  final int selectedIndex;

  _BoundingBoxPainter({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    required this.imageRect,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (imageWidth <= 0 || imageHeight <= 0) return;

    for (int i = 0; i < detections.length; i++) {
      final d = detections[i];
      final color = _confidenceColor(d.confidence);
      final isSelected = i == selectedIndex;
      final rect = scaleBoxToCanvas(
        box: d.box,
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        canvasSize: size,
        imageRect: imageRect,
      );
      if (rect.isEmpty) continue;

      // Fill bán trong suốt
      canvas.drawRect(
        rect,
        Paint()
          ..color = color.withValues(alpha: isSelected ? 0.22 : 0.12)
          ..style = PaintingStyle.fill,
      );

      // Viền 3dp màu theo confidence (3.5dp nếu đang chọn)
      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 3.5 : 3.0,
      );

      // Góc vuông nhấn mạnh
      _drawCorners(canvas, rect, color, isSelected ? 18 : 14);

      // Nhãn trên box: Nền Bar #0F1A21 100% đặc, chữ trắng bold
      final label = d.label.replaceAll('_', ' ');
      final confText = '${(d.confidence * 100).toStringAsFixed(1)}%';
      final textSpan = TextSpan(
        text: '$label $confText',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr)
        ..layout();

      // Nền nhãn: Bar #0F1A21 100% đặc
      final labelRect = labelRectForBox(rect, tp.size, size);
      canvas.drawRRect(
        RRect.fromRectAndRadius(labelRect, const Radius.circular(5)),
        Paint()
          ..color = AppColors.bar
          ..style = PaintingStyle.fill,
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
      detections != old.detections ||
      imageWidth != old.imageWidth ||
      imageHeight != old.imageHeight ||
      imageRect != old.imageRect ||
      selectedIndex != old.selectedIndex;
}
