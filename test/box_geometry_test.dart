import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:giao_dien/box_geometry.dart';

void main() {
  test('contain tính đúng vùng ảnh khi có letterbox', () {
    final imageRect = containImageRect(
      imageSize: const Size(1000, 500),
      canvasSize: const Size(300, 300),
    );

    expect(imageRect, const Rect.fromLTRB(0, 75, 300, 225));
  });

  test('scale box đặt tọa độ vào vùng ảnh contain, không vào nền thừa', () {
    final imageRect = containImageRect(
      imageSize: const Size(1000, 500),
      canvasSize: const Size(300, 300),
    );
    final rect = scaleBoxToCanvas(
      box: const [100, 100, 900, 400],
      imageWidth: 1000,
      imageHeight: 500,
      canvasSize: const Size(300, 300),
      imageRect: imageRect,
    );

    expect(rect, const Rect.fromLTRB(30, 105, 270, 195));
  });

  test('hit test ưu tiên box vẽ sau khi các box giao nhau', () {
    final index = hitTestBox(
      point: const Offset(120, 120),
      boxes: const [
        [20, 20, 180, 180],
        [100, 100, 160, 160],
      ],
      imageWidth: 200,
      imageHeight: 200,
      canvasSize: const Size(200, 200),
    );

    expect(index, 1);
    expect(
      hitTestBox(
        point: const Offset(195, 195),
        boxes: const [
          [20, 20, 180, 180],
        ],
        imageWidth: 200,
        imageHeight: 200,
        canvasSize: const Size(200, 200),
      ),
      isNull,
    );
  });

  test('scale box giữ đúng tọa độ khi đổi kích thước', () {
    final rect = scaleBoxToCanvas(
      box: const [100, 50, 900, 450],
      imageWidth: 1000,
      imageHeight: 500,
      canvasSize: const Size(300, 150),
    );

    expect(rect, const Rect.fromLTRB(30, 15, 270, 135));
  });

  test('scale box chặn tọa độ vượt ngoài canvas', () {
    final rect = scaleBoxToCanvas(
      box: const [-10, -20, 120, 140],
      imageWidth: 100,
      imageHeight: 100,
      canvasSize: const Size(200, 200),
    );

    expect(rect, const Rect.fromLTRB(0, 0, 200, 200));
  });
}
