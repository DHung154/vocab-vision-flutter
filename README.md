# Vocab Vision

Ứng dụng Flutter học từ vựng tiếng Anh cho trẻ em Việt Nam, offline-first trên Android: bài luyện, nhận diện đồ dùng học tập E4, mascot Mây và minigame **Phi đội từ vựng**.

👉 **[Bản đồ thư mục, màn hình và chức năng — APP_MAP.md](APP_MAP.md)**

## Chạy app

Yêu cầu Flutter hỗ trợ Dart 3.10+, Android SDK và JDK 17. Bản hiện tại được kiểm tra với Flutter 3.38.7. Flutter chuẩn bị Gradle wrapper/cấu hình SDK cục bộ khi build; không đưa đường dẫn SDK cá nhân lên Git.

```sh
git clone https://github.com/DHung154/vocab-vision-flutter.git
cd vocab-vision-flutter
flutter pub get
flutter run
```

```sh
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

APK nằm trong `build/app/outputs/flutter-apk/`. Không lưu APK, cache, database người dùng hoặc khóa ký trong repo.

## Chức năng hiện tại

- 5 tab: Trang chủ, Khám phá, Nhận diện, Tiến độ, Hồ sơ; vuốt chuyển tab và quay lại.
- Catalog starter **300 từ / 40 chủ đề**, 15 ảnh đồ dùng học tập; không phải gói 3.000 từ/1.000 media.
- Flashcard, Nghe & chọn, Ghép cặp, Điền từ, Dịch từ, Nhìn hình viết từ; lịch ôn, bộ sưu tập và lưu bài đang học.
- E4 **YOLO26-S — SA-InterpIoU affine + EMA** chạy bằng ONNX Runtime trên Android, không cần Wi-Fi hay server nhận diện.
- Mây có sprite animation và phản hồi đúng/sai; giao diện sáng/tối.
- Game phi thuyền 6 màn, boss di chuyển/xúc tu/laser, nhặt đạn theo từ, nhạc và hiệu ứng, lưu sao tốt nhất.

Guest chạy offline. Đăng nhập, tải catalog và đồng bộ là tùy chọn, cần server riêng:

```sh
flutter run --dart-define=VOCAB_API_BASE_URL=https://your-api.example
```

Repo **chỉ chứa app và kiểm thử app**, không chứa backend, Docker, dữ liệu cào, kế hoạch hoặc huấn luyện. Android native cung cấp nhận diện/TTS/âm thanh/secure storage; các nền tảng còn lại có scaffold Flutter nhưng chưa được xác minh tương đương Android. Web chưa hỗ trợ do luồng `dart:io` hiện tại.

## Model và kết quả nghiên cứu

Model đóng gói: `android/app/src/main/assets/e4.onnx`, SHA-256:

```text
0256115F2E4339527B665C0FD22ED5C4961AAC2539B7889BB9AC297588A61E66
```

Input `[1,3,512,512]`, output `[1,300,6]`, 15 class ID cố định. Checkpoint huấn luyện `best.pt` không cần để chạy APK và không nằm trong repo app; không bị di chuyển hoặc xóa.

Bảng thực nghiệm là snapshot trong `lib/research_results_data.dart`, ghi nguồn và giao thức đánh giá gốc. Confidence từng box không phải AP/mAP; điểm game không phải độ chính xác E4. Latency demo được đo trên thiết bị đang chạy.

## Trước khi phát hành

Đây là bản đồ án/demo, không phải tuyên bố production-ready. Release hiện ký debug; cần khóa riêng trước khi phát hành. Nguồn ảnh/nhạc ghi trong [APP_MAP.md](APP_MAP.md#nguồn-asset-và-phạm-vi-sử-dụng); cần xác minh quyền phân phối trước khi phát hành công khai. Kiểm thử thiết bị, TalkBack và đồng bộ hai thiết bị cần QA riêng, không suy ra từ unit/widget test.
