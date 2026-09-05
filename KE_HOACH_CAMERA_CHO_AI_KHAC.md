# Đặc tả triển khai camera và màn hình kết quả nhận diện

## 1. Phạm vi công việc

Chỉ triển khai luồng camera và kết quả nhận diện trong dự án Flutter tại:

```text
E:\KLTN\APP\vocab_app_flutter
```

Không thiết kế lại Trang chủ, Từ vựng, Bản đồ học tập, Thành tích, Hồ sơ hoặc
Cài đặt. Không thay đổi bảng màu toàn ứng dụng. Không xóa hai file ZIP gốc.

Luồng bắt buộc:

```text
Mở Camera → Chụp/chọn ảnh → Xem trước → Gửi nhận diện
→ Màn hình kết quả Anh–Việt → Chụp lại
```

## 2. Yêu cầu camera

Ưu tiên `image_picker` vì ứng dụng chỉ cần chụp một ảnh, không cần nhận diện
video thời gian thực.

```yaml
dependencies:
  image_picker: ^1.1.2
  http: ^1.2.2
```

Màn hình camera phải có:

- Nút chụp ảnh bằng camera thiết bị.
- Nút chọn ảnh từ thư viện.
- Trạng thái khi người dùng từ chối quyền camera.
- Ảnh xem trước sau khi chụp.
- Hai lựa chọn `Chụp lại` và `Sử dụng ảnh này`.
- Loading khi đang gửi ảnh; khóa nút để tránh gửi hai lần.

Không hiển thị bounding box hoặc nhãn giả trước khi API trả kết quả.

## 3. API nhận diện

Ứng dụng gửi ảnh multipart tới một URL cấu hình tập trung, ví dụ:

```dart
const inferenceUrl = 'http://192.168.1.10:8000/predict';
```

Không rải URL ở nhiều widget. Timeout đề xuất: 30 giây.

JSON đầu ra thống nhất:

```json
{
  "image_width": 512,
  "image_height": 512,
  "detections": [
    {
      "class_id": 11,
      "label": "pencil",
      "confidence": 0.924,
      "box": [120.0, 85.0, 310.0, 420.0]
    }
  ]
}
```

`box` có thứ tự `[x1, y1, x2, y2]` theo kích thước ảnh mà API báo về.

## 4. Ánh xạ 15 nhãn Anh–Việt

Dùng duy nhất một map, không lặp lại bản dịch ở nhiều màn hình:

```dart
const vocabularyVi = {
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
```

Nếu API trả nhãn lạ, hiển thị chính nhãn đó và `Chưa có bản dịch`; không làm
app crash.

## 5. Màn hình kết quả

Tạo màn hình riêng, không chèn kết quả nhỏ trực tiếp lên camera.

Thành phần bắt buộc:

1. App bar có nút quay lại.
2. Ảnh vừa chụp với bounding box đúng tỉ lệ.
3. Thẻ kết quả chính của detection có confidence cao nhất.
4. Tên tiếng Anh nổi bật.
5. Tên tiếng Việt ngay bên dưới.
6. Confidence hiển thị một chữ số thập phân, ví dụ `92,4%`.
7. Danh sách các vật thể khác nếu ảnh có nhiều detection.
8. Nút `Chụp vật khác` quay lại luồng camera.

Màu bounding box của từng detection phải khớp với chấm màu trong danh sách.

## 6. Trạng thái lỗi

Phải xử lý riêng:

- Người dùng hủy camera/thư viện: ở lại màn hình hiện tại.
- Không có mạng hoặc sai IP API: thông báo không kết nối được máy nhận diện.
- API trả mã lỗi: hiển thị thông báo và nút thử lại.
- `detections` rỗng: thông báo chưa tìm thấy đồ dùng học tập; không tự tạo nhãn.
- JSON sai cấu trúc: thông báo dữ liệu trả về không hợp lệ.
- Confidence thấp hơn ngưỡng cấu hình: vẫn có thể hiển thị nhưng ghi `Độ tin cậy thấp`.

## 7. Quyền hệ điều hành

Cập nhật quyền camera/ảnh cho Android và iOS theo hướng dẫn chính thức của
`image_picker`. Không yêu cầu microphone hoặc vị trí.

## 8. Kiểm thử bắt buộc

Giữ test hiện có và bổ sung test nhỏ cho:

- Parse JSON một detection.
- Parse nhiều detection rồi chọn confidence cao nhất.
- `detections` rỗng.
- Nhãn không tồn tại trong map tiếng Việt.
- Màn hình kết quả hiển thị cả tiếng Anh và tiếng Việt.

Chạy trước khi bàn giao:

```cmd
dart format lib test
flutter analyze
flutter test
```

## 9. Điều kiện hoàn thành

- Không còn kết quả nhận diện mô phỏng trong chế độ chạy thật.
- Chụp hoặc chọn ảnh được trên thiết bị mục tiêu.
- Có loading và không gửi trùng request.
- Màn hình kết quả hiển thị đúng Anh–Việt, confidence và bounding box.
- Không phát hiện được vật thể vẫn có thông báo rõ ràng.
- `flutter test` PASS.

## 10. Không làm trong nhiệm vụ này

- Không thêm đăng nhập hoặc cloud database.
- Không nhận diện video thời gian thực.
- Không chuyển mô hình `.pt` sang TFLite/ONNX.
- Không sửa kiến trúc YOLO hoặc checkpoint.
- Không thay giao diện các tab ngoài Camera/Kết quả.
