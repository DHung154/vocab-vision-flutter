# Sửa light mode / dark mode ở kết quả nhận diện

Ngày: 08/10/2026 · Phiên bản: 1.0.4+5

## Nguyên nhân

Nền màn hình và thẻ đã đổi theo theme, nhưng chữ, biểu tượng, nhãn độ tin cậy và một số nền vẫn lấy màu cố định từ bảng màu dark mode. Vì vậy light mode có chữ trắng trên nền trắng và bảng chi tiết nền tối. Nhãn độ tin cậy trung bình cũng có cặp màu chữ/nền khó đọc.

## Đã sửa

- Tiêu đề, tên đồ vật tiếng Anh/Việt, danh sách đồ vật và phần “Học thêm” dùng màu của theme hiện tại.
- Ba mức độ tin cậy dùng cặp màu nền/chữ riêng cho light mode và dark mode.
- Bảng chi tiết từ vựng lấy nền từ theme, đồng thời cập nhật chữ và nút lưu yêu thích khi theme thay đổi.
- Thẻ thông tin kỹ thuật và thông báo không tìm thấy đồ vật theo đúng theme.
- Nút trung tính và nút bị vô hiệu hóa trong `PlayfulButton` dùng màu theo theme.

Nhãn vẽ trực tiếp trên ảnh vẫn dùng nền tối với chữ trắng để dễ đọc trên ảnh có nhiều màu.

## Kiểm tra

- `flutter analyze --no-pub`: không có vấn đề.
- `flutter test --no-pub --reporter expanded`: 128 bài kiểm tra đạt.
- Có 5 bài kiểm tra mới cho hai theme, ba mức độ tin cậy, bảng chi tiết, trạng thái không có kết quả và đổi theme khi bảng chi tiết đang mở. Màu chữ được kiểm tra tỷ lệ tương phản tối thiểu 4.5:1 trong các trường hợp này.
- Ảnh kiểm tra widget lưu ở `build/qa-result-theme/`. Các ảnh này sử dụng phông chữ mặc định của môi trường kiểm thử Flutter.

## Bản Android

- APK release arm64 tạo thành công: `build/app/outputs/flutter-apk/app-release.apk` (157 MB).
- Cài đè thành công trên điện thoại vivo đã kết nối; xác minh `versionName=1.0.4`, `versionCode=5`.
- Ứng dụng mở được sau khi cập nhật, hồ sơ hiragana và chuỗi học vẫn còn.
- Kiểm tra kết quả nhận diện ở hai theme bằng widget test. Sau khi cập nhật chưa chọn lại ảnh trên điện thoại; người dùng tự chọn ảnh theo yêu cầu trước đó.
