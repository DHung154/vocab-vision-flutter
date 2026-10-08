# Tối ưu hiệu năng Vocab Vision — bản 1.0.2+3

Ngày thực hiện: 07/10/2026. Dự án: `D:\code\vocab-vision-flutter`.

## Những phần đã cải thiện

### Tìm kiếm từ vựng

- Chuẩn hóa chữ tiếng Việt một lần khi danh mục được nạp hoặc thay đổi, thay vì làm lại cho từng từ ở mỗi lượt tìm kiếm và mỗi lần dựng màn hình.
- Bảng chuyển đổi dấu được tạo một lần và dùng lại.
- Danh sách chủ đề được tính cùng chỉ mục tìm kiếm. Danh mục cung cấp cùng một đối tượng chỉ đọc cho đến khi dữ liệu thay đổi, giúp tránh tạo lại chỉ mục không cần thiết.
- Giữ thứ tự kết quả, tìm kiếm không dấu, bộ lọc chủ đề và từ yêu thích.

### Bộ nhớ dùng để hiển thị ảnh

- Ảnh xem trước từ camera/thư viện, ảnh trên màn kết quả và ảnh từ vựng được giải mã theo kích thước khung hiển thị và mật độ điểm ảnh.
- Gom kích thước giải mã theo bước 64 pixel để các khung gần bằng nhau có thể dùng chung ảnh trong bộ nhớ đệm; giới hạn mỗi chiều ở 2.048 pixel.
- Giữ tỷ lệ ảnh, không phóng to ảnh nhỏ trong bước giải mã. Tệp ảnh gốc và ảnh đầu vào mô hình nhận diện vẫn được giữ nguyên.
- Logo cũng được giải mã ở kích thước phù hợp với màn mở ứng dụng.

### Hoạt ảnh và màn mở ứng dụng

- Tạm dừng ticker của giao diện phía sau màn logo, rồi bật lại khi chuyển cảnh hoàn tất.
- Tách vùng vẽ giao diện bên dưới bằng `RepaintBoundary`.
- Tính sẵn đường viền hữu cơ của hiệu ứng màu, tránh tính lại các hàm lượng giác ở mỗi khung hình.
- Linh vật chỉ phụ thuộc vào thông tin giảm chuyển động cần thiết của `MediaQuery`.
- Giữ trải nghiệm đã thống nhất: logo xuất hiện, màu phủ toàn màn hình, rồi cả logo và lớp màu trượt lên trên. Thời lượng khoảng 3 giây là chủ đích của thiết kế.

## Kết quả đo

### Tìm kiếm trên máy tính

Bài đo dùng 300 từ có sẵn lặp 10 lần thành 3.000 mục, chạy 100 truy vấn. Cả ba cách đều trả về tổng cộng 3.300 kết quả trùng khớp.

| Cách xử lý | Tổng thời gian |
| --- | ---: |
| Trước tối ưu: chuẩn hóa toàn bộ từ ở mỗi truy vấn | 2.483,245 ms |
| Chỉ cải thiện hàm chuẩn hóa, chưa dùng chỉ mục | 292,615 ms |
| Dùng chỉ mục, bao gồm thời gian tạo chỉ mục | 45,859 ms |

Trong kết quả cuối, tạo chỉ mục mất 14,104 ms. Tổng thời gian bài đo giảm khoảng 98,2%. Đây là một lần đo workload Dart trên máy tính, **không phải số đo FPS hay thời gian mở toàn bộ ứng dụng trên điện thoại**. Gói từ thực tế lớn hơn hoặc truy vấn khác có thể cho kết quả khác.

Mã chạy lại: `tool/benchmark_search.dart`. Kết quả gốc lưu tại `build/qa-performance/baseline-search.json`, `normalized-search.json` và `indexed-search.json`.

```powershell
& 'D:\download\flutter\flutter\bin\dart.bat' run tool/benchmark_search.dart --indexed
```

### Giải mã ảnh

Kiểm thử tạo ảnh 4.000 × 3.000 pixel, hiển thị trong khung 480 × 360 pixel logic với DPR 2:

| Chỉ số | Trước | Sau |
| --- | ---: | ---: |
| Kích thước ảnh giải mã | 4.000 × 3.000 | 960 × 720 |
| Bộ nhớ pixel RGBA tính theo 4 byte/pixel | 48.000.000 byte | 2.764.800 byte |

Giảm **94,24% bộ nhớ pixel của ảnh trong tình huống này**. Đây là kết quả kích thước ảnh giải mã thực tế trong kiểm thử, không phải mức giảm tổng RAM của ứng dụng. Tỷ lệ ảnh không thay đổi và ảnh nhỏ không bị phóng to. Kết quả lưu tại `build/qa-performance/image-decoding.json`.

## Kiểm tra và trạng thái bàn giao

- `flutter test`: **119 kiểm thử vượt qua**, gồm tìm kiếm, Unicode/emoji, kích thước ảnh giải mã, màn logo và các chức năng hiện có.
- `flutter analyze --no-pub`: **không có lỗi hoặc cảnh báo phân tích mã**.
- Phiên bản ứng dụng: **1.0.2**, mã bản dựng **3**, APK cho **Android arm64**.
- Build release thành công; APK nằm tại `build/app/outputs/flutter-apk/app-release.apk`, dung lượng khoảng **153,5 MB**. Cảnh báo công cụ Android về phiên bản SDK XML không làm build thất bại.
- Đã cập nhật **1.0.2+3** lên điện thoại vivo V2352A vào ngày **07/10/2026**, sau khi người dùng kết nối lại và yêu cầu cài đặt. Cài bằng chế độ cập nhật, giữ dữ liệu hiện có.

Kiểm tra nhanh trên điện thoại: mở ứng dụng thành công; hồ sơ `hiragana`, tiến độ 1/10 từ và chuỗi 1 ngày vẫn được giữ. Màn Khám phá hiển thị 300 từ; cuộn danh sách và tìm `pencil` hoạt động, trả về Pencil và Pencil sharpener cùng ảnh. Không thấy `FATAL EXCEPTION`, `E/flutter` hoặc `Unhandled Exception` trong log của tiến trình ở lượt kiểm tra này.

Ảnh chụp và nhật ký lưu tại `build/qa-performance/updated-home.png`, `updated-catalog.png`, `updated-search.png` và `updated-phone-logcat.log`.

Đã lấy thêm một mẫu RAM PSS trên thiết bị theo cùng thao tác mở app, vào danh mục và cuộn ba lượt lên/ba lượt xuống:

| Trạng thái | Bản 1.0.1 (KB) | Bản 1.0.2 (KB) |
| --- | ---: | ---: |
| Trang chủ | 158.509 | 156.349 |
| Danh mục | 191.301 | 202.802 |
| Sau cuộn | 180.038 | 184.522 |

Tổng RAM không giảm đồng đều trong lượt lấy mẫu này. Các mẫu đơn chịu ảnh hưởng của bộ nhớ đệm, GPU và thời điểm thu gom bộ nhớ; chúng không đủ để kết luận tổng RAM giảm. Lợi ích 94,24% ở trên chỉ áp dụng cho bộ nhớ pixel của ảnh thử nghiệm. Chưa đưa ra kết luận về FPS hoặc tốc độ suy luận E4. Thời gian mở Activity do Android báo ở lượt này là 508 ms; không dùng một lượt đo để kết luận tốc độ khởi động cải thiện.

Chưa kiểm tra ảnh lớn từ thư viện trong lượt cập nhật này. Khi đến trình chọn ảnh, người dùng sẽ tự chọn ảnh như đã yêu cầu.

## Tệp chính

- `lib/core/text/catalog_search_index.dart`: chỉ mục tìm kiếm.
- `lib/core/text/search_normalizer.dart`: chuẩn hóa văn bản.
- `lib/core/media/display_image.dart`: giải mã ảnh cho hiển thị.
- `lib/app/launch_experience.dart`: tối ưu vẽ và hoạt ảnh lúc mở app.
- `build/qa-performance/tests.log`, `analyze.log`, `build-release.log`: nhật ký kiểm tra.

Tham khảo kỹ thuật: [Flutter — Performance best practices](https://docs.flutter.dev/perf/best-practices), [Flutter — ResizeImage](https://api.flutter.dev/flutter/painting/ResizeImage-class.html).
