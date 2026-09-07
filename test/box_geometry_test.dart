import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:giao_dien/box_geometry.dart';

void main() {
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
