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
      return Detection(
        classId: (json['class_id'] as num).toInt(),
        label: json['label'] as String,
        confidence: (json['confidence'] as num).toDouble(),
        box: rawBox.map((n) => n.toDouble()).toList(),
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('Detection JSON không hợp lệ: $e');
    }
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
  factory DetectionResult.fromJson(Map<String, dynamic> json) {
    try {
      final rawDetections = json['detections'] as List? ?? [];
      return DetectionResult(
        imageWidth: (json['image_width'] as num).toInt(),
        imageHeight: (json['image_height'] as num).toInt(),
        detections: rawDetections
            .map((d) => Detection.fromJson(Map<String, dynamic>.from(d as Map)))
            .toList(),
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
