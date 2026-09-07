import 'vocabulary_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cấu hình tập trung — model offline, ngưỡng confidence, bản đồ từ vựng
// ─────────────────────────────────────────────────────────────────────────────

/// Ngưỡng confidence — dưới giá trị này sẽ ghi "Độ tin cậy thấp".
const minConfidenceThreshold = 0.3;

class DemoModelOption {
  final String id;
  final String label;

  const DemoModelOption(this.id, this.label);
}

/// Danh sách chỉ chứa các checkpoint đã xác minh, không thay thế model ngầm.
const demoModelOptions = <DemoModelOption>[
  DemoModelOption('e4', 'YOLO26-S — E4 (nhóm đề xuất)'),
];
const defaultDemoModelId = 'e4';

/// Bản đồ 15 nhãn Anh–Việt duy nhất. Không lặp lại ở màn hình khác.
final vocabularyVi = <String, String>{
  for (final word in vocabularyWords) word.apiLabel: word.vietnamese,
};

/// Tra bản dịch tiếng Việt, fallback nếu nhãn lạ.
String vietnameseName(String label) =>
    vocabularyVi[label.toLowerCase().replaceAll(' ', '_')] ??
    'Chưa có bản dịch';
