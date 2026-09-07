# Vocab Vision Flutter

Ứng dụng Flutter demo khóa luận nhận diện 15 loại đồ dùng học tập bằng
`YOLO26-S — E4 (nhóm đề xuất)`.

## Nhận diện offline

- Ảnh từ camera hoặc thư viện được xử lý trực tiếp trên thiết bị Android.
- Không cần Wi-Fi, địa chỉ IP hay FastAPI để nhận diện.
- Runtime ONNX được nạp một lần rồi tái sử dụng trong vòng đời ứng dụng.
- App giữ nguyên class ID, vẽ box sau khi hoàn tác letterbox và chỉ lọc theo
  ngưỡng confidence của demo; không tự xóa các box giao nhau.
- Màn `Kết quả thực nghiệm E4` đọc bản chụp số liệu đã xác minh được đóng gói
  trong app. Backend trong thư mục `backend` chỉ còn là công cụ kiểm chứng tùy
  chọn, không phải thành phần cần để chạy APK.

Inference offline hiện được cài cho Android qua ONNX Runtime. Giao diện vẫn có
thể biên dịch trên nền tảng khác, nhưng nút nhận diện cần Android.

## Chạy ứng dụng

```powershell
cd E:\KLTN\APP\vocab_app_flutter
flutter pub get
flutter run
```

Không cần mở server và không cần truyền `INFERENCE_BASE_URL`.

## Mô hình

- Checkpoint nguồn (không bị di chuyển/chỉnh sửa):
  `E:\KLTN\runs\E4_balanced_seed0\weights\best.pt`
- SHA-256 checkpoint nguồn:
  `5791196A7575B9061B4E3D86C48A0E9AE56B17493CD968A85B4B74B08B65EB63`
- Model Android được xuất riêng:
  `android\app\src\main\assets\e4.onnx`
- SHA-256 model Android:
  `0256115F2E4339527B665C0FD22ED5C4961AAC2539B7889BB9AC297588A61E66`
- Input/output đã xác minh: `[1,3,512,512]` → `[1,300,6]`, 15 lớp.

## Nguồn kết quả nghiên cứu

- Ba seed E0/E4: `E:\KLTN\outputs\yolo_seed_test_fixed\summary.csv`
- E1 seed 0: bảng kết quả kiểm thử đã khóa trong
  `E:\KLTN\analysis\fair_rewrite_teacher_notes_20260825\source_content.txt`

Confidence trên một box không phải AP/mAP. Ảnh người dùng không có ground truth
không được dùng để tính AP, Precision hoặc Recall. Latency trong kết quả demo là
thời gian thực đo trên chính thiết bị Android đang chạy app.

## Kiểm tra

```powershell
flutter analyze
flutter test
flutter build apk --debug
python -m backend.smoke_test
```
