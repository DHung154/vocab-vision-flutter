import 'dart:math' as math;
import 'dart:ui';

/// Đổi box pixel trên ảnh gốc sang canvas giữ nguyên tỉ lệ của ảnh hiển thị.
Rect scaleBoxToCanvas({
  required List<double> box,
  required double imageWidth,
  required double imageHeight,
  required Size canvasSize,
}) {
  if (box.length != 4 || imageWidth <= 0 || imageHeight <= 0) {
    return Rect.zero;
  }
  final scaleX = canvasSize.width / imageWidth;
  final scaleY = canvasSize.height / imageHeight;
  return Rect.fromLTRB(
    (box[0] * scaleX).clamp(0.0, canvasSize.width),
    (box[1] * scaleY).clamp(0.0, canvasSize.height),
    (box[2] * scaleX).clamp(0.0, canvasSize.width),
    (box[3] * scaleY).clamp(0.0, canvasSize.height),
  );
}

/// Đặt nhãn trong canvas để tên lớp dài không tràn khỏi ảnh.
Rect labelRectForBox(Rect box, Size textSize, Size canvasSize) {
  final width = math.min(textSize.width + 10, canvasSize.width);
  final left = box.left
      .clamp(0.0, math.max(0.0, canvasSize.width - width))
      .toDouble();
  final top = math.max(box.top - textSize.height - 6, 0.0);
  return Rect.fromLTWH(left, top, width, textSize.height + 6);
}
