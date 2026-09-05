// ─────────────────────────────────────────────────────────────────────────────
// Cấu hình tập trung — URL API, timeout, ngưỡng confidence, bản đồ từ vựng
// ─────────────────────────────────────────────────────────────────────────────

/// URL duy nhất gửi ảnh nhận diện. Thay đổi tại đây khi đổi IP/server.
const inferenceUrl = 'http://192.168.1.10:8000/predict';

/// Timeout gửi ảnh (giây).
const inferenceTimeoutSeconds = 30;

/// Ngưỡng confidence — dưới giá trị này sẽ ghi "Độ tin cậy thấp".
const minConfidenceThreshold = 0.3;

/// Bản đồ 15 nhãn Anh–Việt duy nhất. Không lặp lại ở màn hình khác.
const vocabularyVi = <String, String>{
  'abacus': 'Bàn tính',
  'backpack': 'Ba lô',
  'chalk': 'Phấn',
  'chalkboard': 'Bảng phấn',
  'crayon': 'Bút sáp màu',
  'cup': 'Cốc',
  'eraser': 'Cục tẩy',
  'glue_stick': 'Hồ khô',
  'kids_chair': 'Ghế trẻ em',
  'notebook': 'Vở',
  'paintbrush': 'Cọ vẽ',
  'pencil': 'Bút chì',
  'pencil_sharpener': 'Gọt bút chì',
  'ruler': 'Thước kẻ',
  'scissors': 'Kéo',
};

/// Tra bản dịch tiếng Việt, fallback nếu nhãn lạ.
String vietnameseName(String label) =>
    vocabularyVi[label.toLowerCase()] ?? 'Chưa có bản dịch';
