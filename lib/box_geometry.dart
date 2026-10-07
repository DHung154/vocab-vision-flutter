import 'dart:math' as math;
import 'dart:ui';

/// Vùng mà ảnh thật chiếm trên canvas khi dùng [BoxFit.contain].
///
/// Bounding box phải được đặt trong vùng này thay vì toàn bộ canvas. Điều đó
/// giữ đúng tọa độ khi widget có letterbox (ví dụ ảnh dọc nằm trong khung
/// ngang) và tránh box trôi vào phần nền thừa.
Rect containImageRect({required Size imageSize, required Size canvasSize}) {
  if (imageSize.width <= 0 ||
      imageSize.height <= 0 ||
      canvasSize.width <= 0 ||
      canvasSize.height <= 0) {
    return Rect.zero;
  }

  final scale = math.min(
    canvasSize.width / imageSize.width,
    canvasSize.height / imageSize.height,
  );
  final width = imageSize.width * scale;
  final height = imageSize.height * scale;
  return Rect.fromLTWH(
    (canvasSize.width - width) / 2,
    (canvasSize.height - height) / 2,
    width,
    height,
  );
}

/// Đổi box pixel trên ảnh gốc sang canvas giữ nguyên tỉ lệ của ảnh hiển thị.
Rect scaleBoxToCanvas({
  required List<double> box,
  required double imageWidth,
  required double imageHeight,
  required Size canvasSize,
  Rect? imageRect,
}) {
  if (box.length != 4 || imageWidth <= 0 || imageHeight <= 0) {
    return Rect.zero;
  }

  final target = imageRect ?? Offset.zero & canvasSize;
  if (target.width <= 0 || target.height <= 0) return Rect.zero;

  final scaleX = target.width / imageWidth;
  final scaleY = target.height / imageHeight;
  return Rect.fromLTRB(
    (target.left + box[0] * scaleX).clamp(target.left, target.right).toDouble(),
    (target.top + box[1] * scaleY).clamp(target.top, target.bottom).toDouble(),
    (target.left + box[2] * scaleX).clamp(target.left, target.right).toDouble(),
    (target.top + box[3] * scaleY).clamp(target.top, target.bottom).toDouble(),
  );
}

/// Tìm box ở trên cùng tại một điểm chạm trên canvas.
///
/// Duyệt ngược theo thứ tự vẽ để khi hai box giao nhau, box được vẽ sau
/// cùng (và đang nằm trên) nhận sự kiện chạm.
int? hitTestBox({
  required Offset point,
  required List<List<double>> boxes,
  required double imageWidth,
  required double imageHeight,
  required Size canvasSize,
  Rect? imageRect,
}) {
  for (var i = boxes.length - 1; i >= 0; i--) {
    final rect = scaleBoxToCanvas(
      box: boxes[i],
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      canvasSize: canvasSize,
      imageRect: imageRect,
    );
    if (!rect.isEmpty && rect.contains(point)) return i;
  }
  return null;
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
