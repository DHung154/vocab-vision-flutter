// Tests cho detection model và vocabulary map.
import 'package:flutter_test/flutter_test.dart';

import 'package:giao_dien/app_config.dart';
import 'package:giao_dien/detection_model.dart';

void main() {
  // ─── 1. Parse JSON 1 detection ──────────────────────────────────────────────
  test('Parse JSON một detection đúng label, confidence, box', () {
    final json = <String, dynamic>{
      'image_width': 512,
      'image_height': 512,
      'detections': [
        {
          'class_id': 11,
          'label': 'pencil',
          'confidence': 0.924,
          'box': [120.0, 85.0, 310.0, 420.0],
        },
      ],
    };

    final result = DetectionResult.fromJson(json);

    expect(result.imageWidth, 512);
    expect(result.imageHeight, 512);
    expect(result.detections.length, 1);

    final d = result.detections.first;
    expect(d.classId, 11);
    expect(d.label, 'pencil');
    expect(d.confidence, closeTo(0.924, 0.001));
    expect(d.box, [120.0, 85.0, 310.0, 420.0]);
  });

  // ─── 2. Parse nhiều detection, chọn confidence cao nhất ─────────────────────
  test('Parse nhiều detection rồi chọn confidence cao nhất', () {
    final json = <String, dynamic>{
      'image_width': 640,
      'image_height': 480,
      'detections': [
        {
          'class_id': 1,
          'label': 'backpack',
          'confidence': 0.87,
          'box': [10.0, 20.0, 100.0, 200.0],
        },
        {
          'class_id': 11,
          'label': 'pencil',
          'confidence': 0.95,
          'box': [120.0, 85.0, 310.0, 420.0],
        },
        {
          'class_id': 9,
          'label': 'notebook',
          'confidence': 0.89,
          'box': [50.0, 50.0, 200.0, 300.0],
        },
      ],
    };

    final result = DetectionResult.fromJson(json);

    expect(result.detections.length, 3);
    expect(result.topDetection, isNotNull);
    expect(result.topDetection!.label, 'pencil');
    expect(result.topDetection!.confidence, closeTo(0.95, 0.001));
  });

  // ─── 3. Detections rỗng ─────────────────────────────────────────────────────
  test('Detections rỗng trả về danh sách trống', () {
    final json = <String, dynamic>{
      'image_width': 512,
      'image_height': 512,
      'detections': <dynamic>[],
    };

    final result = DetectionResult.fromJson(json);

    expect(result.detections, isEmpty);
    expect(result.topDetection, isNull);
  });

  // ─── 4. Nhãn không có trong map tiếng Việt ──────────────────────────────────
  test('Nhãn lạ không có trong vocabularyVi trả "Chưa có bản dịch"', () {
    // Nhãn có trong map
    expect(vietnameseName('pencil'), 'Bút chì');
    expect(vietnameseName('ruler'), 'Thước kẻ');
    expect(vietnameseName('backpack'), 'Ba lô');
    expect(vietnameseName('scissors'), 'Kéo');

    // Nhãn lạ — fallback
    expect(vietnameseName('unknown_object'), 'Chưa có bản dịch');
    expect(vietnameseName('xyz_abc'), 'Chưa có bản dịch');
    expect(vietnameseName('laptop'), 'Chưa có bản dịch');
  });

  // ─── 5. JSON sai cấu trúc ném FormatException ──────────────────────────────
  test('JSON sai cấu trúc ném FormatException', () {
    // Thiếu field bắt buộc
    expect(
      () => DetectionResult.fromJson({'foo': 'bar'}),
      throwsA(isA<FormatException>()),
    );

    // Box không đủ 4 phần tử
    expect(
      () => Detection.fromJson({
        'class_id': 1,
        'label': 'pencil',
        'confidence': 0.9,
        'box': [1.0, 2.0],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
