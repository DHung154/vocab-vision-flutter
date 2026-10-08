# Bổ sung hình minh họa — Vocab Vision 1.0.3+4

Ngày thực hiện: 07/10/2026.

Gói offline có 300 từ nhưng trước đây chỉ 15 từ thuộc bộ nhận diện E4 có ảnh. Đã bổ sung **285 hình minh họa**, đưa mức bao phủ lên **300/300 từ** trong cả thẻ Khám phá và phần chi tiết từ.

## Nội dung hình

- Hình màu cho trái cây, động vật, đồ dùng, địa điểm, nghề nghiệp, phương tiện và các chủ đề còn lại.
- Minh họa riêng cho màu sắc, số đếm, hình dạng, ngày trong tuần, thời gian và các khái niệm không thể diễn đạt tốt bằng một ảnh vật thể.
- Các lịch “Yesterday / Today / Tomorrow” biểu diễn quan hệ giữa ba ngày; ngày ghi trên hình là ví dụ minh họa, không phải ngày thực tế của thiết bị.
- Tư thế ngồi/nhảy và cảnh lớp học, đường phố, hồ/sông được dựng riêng để thể hiện nghĩa của từ.
- Giữ 15 ảnh E4 có sẵn. Chỉ thêm hình cho các từ thiếu ảnh.

Mỗi hình mới có kích thước **640 × 400 pixel**. Tổng dữ liệu PNG mới khoảng **3,6 MB**; app tải hình từ assets và tiếp tục giải mã theo kích thước hiển thị để hạn chế bộ nhớ. Không cần mạng để xem hình.

## Nguồn và giấy phép

Sử dụng các vector từ **OpenMoji 16.0.0**, kết hợp bố cục và **62 minh họa vector riêng** của Vocab Vision. Các hình mới được cung cấp theo **CC BY-SA 4.0**. Phần chi tiết từ hiển thị nguồn và giấy phép ảnh; không gán thêm người duyệt hay trạng thái xuất bản không có thật.

- [OpenMoji — mã nguồn và yêu cầu ghi nguồn](https://github.com/hfg-gmuend/openmoji)
- [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/)
- Danh sách từng hình, mã vector gốc, tác giả và nguồn: `assets/catalog/illustrations/manifest.json`.
- Văn bản giấy phép: `assets/catalog/illustrations/LICENSE.txt`.
- SVG của từng bố cục: `assets/catalog/illustration_sources/`.

Đây là bộ minh họa màu, không phải 285 ảnh chụp thật. Các nội dung đã có ảnh chụp E4 vẫn dùng ảnh hiện có.

## Cập nhật gói từ trên điện thoại

Gói starter được tăng phiên bản thành `starter-2026-10-media4`. Khi mở bản app mới, ứng dụng tự cập nhật gói starter cũ trong cơ sở dữ liệu để các hình xuất hiện ngay; không cần xóa dữ liệu ứng dụng.

Giữ nguyên ID từ, nội dung song ngữ, ví dụ và dữ liệu học tập. Gói từ tải từ máy chủ có phiên bản riêng được giữ nguyên và không bị gói starter ghi đè.

## Kiểm tra

- **123 kiểm thử vượt qua**.
- `flutter analyze --no-pub`: không có vấn đề.
- Kiểm tra đủ 285 hình trong bundle, giải mã thực tế từng PNG và xác nhận kích thước 640 × 400.
- Kiểm tra manifest khớp chính xác các ID từ cần ảnh, kèm giấy phép và ghi nguồn.
- Kiểm tra nâng cấp starter cũ và giữ nguyên gói tải từ máy chủ.
- Đã xem toàn bộ 10 bảng tổng hợp hình; chỉnh lại tư thế ngồi, cảnh thức dậy và hướng mũi tên đóng cửa.

Nhật ký và bảng tổng hợp hình nằm trong `build/qa-catalog/`.

## Bàn giao trên điện thoại

- Build release thành công; APK khoảng **157 MB**, tại `build/app/outputs/flutter-apk/app-release.apk`.
- Đã cài **1.0.3**, versionCode **4**, trên vivo V2352A bằng chế độ cập nhật.
- Gói starter trên thiết bị tự chuyển sang phiên bản tháng 10; ảnh Apple, Ant và Airport hiển thị ngay trên thẻ Khám phá.
- Đã tìm và mở chi tiết Afternoon, xác nhận hình mới hiển thị ở cả hai nơi.
- Hồ sơ `hiragana`, tiến độ 1/10 từ và chuỗi 1 ngày vẫn được giữ.
- Không thấy lỗi `FATAL EXCEPTION`, `E/flutter`, `Unable to load asset` hoặc `Unhandled Exception` trong log tiến trình ở lượt kiểm tra này.

Ảnh chụp thiết bị: `build/qa-catalog/updated-explore.png`, `updated-search.png` và `updated-detail.png`. Để ứng dụng ở màn Khám phá, đã xóa truy vấn tìm kiếm thử.

## Tái tạo assets

```powershell
npm install --prefix build/catalog-media/render --no-audit --no-fund openmoji@16.0.0 @resvg/resvg-js@2.6.2
& 'D:\download\flutter\flutter\bin\dart.bat' run tool/export_catalog.dart
node tool/prepare_catalog_illustrations.cjs
& 'D:\download\flutter\flutter\bin\dart.bat' format lib/core/media/starter_illustrations.dart
node tool/preview_catalog_illustrations.cjs
```

Các gói Node chỉ phục vụ tạo assets, không trở thành phụ thuộc chạy của ứng dụng Flutter.
