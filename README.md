# Ứng dụng học từ vựng đồ dùng học tập

Ứng dụng Flutter demo cho đề tài nhận diện 15 loại đồ dùng học tập.

## Chức năng hiện có

- Trang chủ và tiến độ học minh họa.
- Danh sách 15 nhãn Anh–Việt đúng với dataset nghiên cứu.
- Màn hình camera mô phỏng luồng nhận diện.
- Thành tích, hồ sơ, cài đặt và bản đồ học tập.

Màn hình camera hiện ghi rõ `Chế độ demo • chưa nối mô hình`. Các kết quả mẫu
không phải dự đoán của YOLO.

Đặc tả để triển khai camera thật và màn hình kết quả nằm trong
`KE_HOACH_CAMERA_CHO_AI_KHAC.md`.

## Chạy ứng dụng

```cmd
cd /d E:\KLTN\APP\vocab_app_flutter
flutter pub get
flutter run -d chrome
```

Hoặc chạy trên Windows:

```cmd
flutter run -d windows
```

## Kiểm tra

```cmd
flutter analyze
flutter test
flutter build web
```

## Bước tiếp theo

Chỉ nối inference thật sau khi đã chọn checkpoint YOLO cuối cùng. Khi đó cần
thêm chọn ảnh/camera, tiền xử lý 512×512, suy luận và ánh xạ 15 nhãn Anh–Việt.
