// ─────────────────────────────────────────────────────────────────────────────
// Models cho kết quả nhận diện từ API YOLO
// ─────────────────────────────────────────────────────────────────────────────

/// Một vật thể được phát hiện trong ảnh.
class Detection {
  final int classId;
  final String label;
  final double confidence;

  /// Bounding box theo thứ tự [x1, y1, x2, y2] (pixel trên ảnh gốc).
  final List<double> box;

  const Detection({
    required this.classId,
    required this.label,
    required this.confidence,
    required this.box,
  });

  /// Parse một detection từ JSON map. Ném [FormatException] nếu sai cấu trúc.
  factory Detection.fromJson(Map<String, dynamic> json) {
    try {
      final rawBox = (json['box'] as List).cast<num>();
      if (rawBox.length != 4) {
        throw const FormatException('box phải có đúng 4 phần tử');
      }
      final classId = (json['class_id'] as num).toInt();
      if (classId < 0 || classId >= 15) {
        throw FormatException('class_id ngoài phạm vi 15 lớp: $classId');
      }
      final confidence = (json['confidence'] as num).toDouble();
      if (!confidence.isFinite || confidence < 0 || confidence > 1) {
        throw const FormatException('confidence phải nằm trong [0, 1]');
      }
      if (rawBox.any((value) => !value.isFinite)) {
        throw const FormatException('box chứa tọa độ không hữu hạn');
      }
      if (rawBox[2] <= rawBox[0] || rawBox[3] <= rawBox[1]) {
        throw const FormatException(
          'box phải có chiều rộng và chiều cao lớn hơn 0',
        );
      }
      final label = json['label'] as String;
      if (label.trim().isEmpty) {
        throw const FormatException('label không được để trống');
      }
      return Detection(
        classId: classId,
        label: label,
        confidence: confidence,
        box: rawBox.map((n) => n.toDouble()).toList(),
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Detection JSON không hợp lệ: $e');
    }
  }

  /// Platform channels use dynamically typed maps. Normalize the map before
  /// handing it to the strict JSON parser so Android codecs cannot surface a
  /// raw `_Map<Object?, Object?>` cast error to the user.
  factory Detection.fromPlatform(Object? value) {
    return Detection.fromJson(_stringKeyedMap(value, label: 'detection'));
  }
}

/// Kết quả nhận diện toàn bộ ảnh.
class DetectionResult {
  final int imageWidth;
  final int imageHeight;
  final List<Detection> detections;
  final String modelId;
  final String modelLabel;
  final double? latencyMs;
  final String? device;
  final String? latencyScope;

  const DetectionResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.detections,
    this.modelId = '',
    this.modelLabel = '',
    this.latencyMs,
    this.device,
    this.latencyScope,
  });

  /// Parse kết quả từ JSON map. Ném [FormatException] nếu sai cấu trúc.
  factory DetectionResult.fromJson(Object? raw) {
    try {
      final json = _stringKeyedMap(raw, label: 'DetectionResult');
      final rawDetections = json['detections'] as List? ?? [];
      final imageWidth = (json['image_width'] as num).toInt();
      final imageHeight = (json['image_height'] as num).toInt();
      if (imageWidth <= 0 || imageHeight <= 0) {
        throw const FormatException(
          'image_width và image_height phải lớn hơn 0',
        );
      }
      return DetectionResult(
        imageWidth: imageWidth,
        imageHeight: imageHeight,
        detections: rawDetections.map(Detection.fromPlatform).toList(),
        modelId: json['model_id'] as String? ?? '',
        modelLabel: json['model_label'] as String? ?? '',
        latencyMs: (json['latency_ms'] as num?)?.toDouble(),
        device: json['device'] as String?,
        latencyScope: json['latency_scope'] as String?,
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('DetectionResult JSON không hợp lệ: $e');
    }
  }

  /// Detection có confidence cao nhất, hoặc null nếu rỗng.
  Detection? get topDetection {
    if (detections.isEmpty) return null;
    return detections.reduce((a, b) => a.confidence >= b.confidence ? a : b);
  }
}

Map<String, dynamic> _stringKeyedMap(Object? value, {required String label}) {
  if (value is! Map) {
    throw FormatException('$label phải là một object JSON');
  }
  final output = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$label chứa key không phải chuỗi');
    }
    output[entry.key as String] = entry.value;
  }
  return output;
}
