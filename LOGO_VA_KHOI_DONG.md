# Logo và màn mở đầu Vocab Vision

## Bản thực hiện

- Logo: sách mở tạo chữ V, trang xanh dương và xanh ngọc, ống kính nhận diện, điểm nhấn sao vàng.
- Logo gốc có nền trong suốt: `assets/brand/vocab_vision_logo.png`.
- Nền giấy: `#FFF8ED`; màu phủ: `#155BB5`.
- 0–0,4 giây: giữ logo ở tâm, nối với logo khởi động Android.
- 0,4–1,4 giây: màu lan rộng bằng đường biên hữu cơ từ tâm logo.
- 1,4–2,3 giây: giữ logo và tên ứng dụng trên nền màu.
- 2,3–3,0 giây: cả lớp mở đầu trượt lên; không giảm độ đậm, không thu nhỏ logo. Giao diện đích đứng yên bên dưới.
- Nếu dữ liệu chưa sẵn sàng, giữ màn logo và thông báo chuẩn bị; kéo màn sau khi giao diện đích đã dựng.
- Khi giảm chuyển động: giữ logo tĩnh ít nhất 350 ms rồi chuyển trực tiếp khi dữ liệu sẵn sàng.
- Màn mở đầu chạy khi khởi tạo ứng dụng, không chạy lại khi trở về từ nền.

## Tạo logo

Logo được tạo bằng công cụ imagegen tích hợp, không dùng API/CLI bên ngoài. Prompt:

> Use case: logo-brand. Create ONE production app logo mark for Vocab Vision, an Android app for children learning English by recognizing school objects. A bold, minimal, rounded open book whose two pages form the letter V, with a small clear camera lens / recognition detail integrated into the upper right page and one small golden sparkle. Friendly modern educational identity; polished flat vector-like shapes, clean thick contours, crisp at launcher icon size. Main colors royal blue #2A7BE4, turquoise #19B7A2, warm gold #FFC83D, a few white page details if needed. Standalone centered symbol on a genuinely transparent background; square composition with about 12% clear padding around symbol. No lettering, no words, no app icon rounded square background, no mockup, no gradients, no drop shadows, no photorealism, no watermark, no additional alternatives. The colored logo must remain recognizable on both a pale ivory background and a deep royal-blue background.

`tool/prepare_brand_assets.ps1` đóng gói hình gốc thành icon Android theo mật độ, icon thích ứng và logo khởi động. Logo gốc giữ nguyên; script chỉ thay đổi kích thước và khoảng đệm.

## Các điểm triển khai

- `lib/app/launch_experience.dart`: hai bộ điều khiển thời gian cho lan màu và kéo màn, đồng thời chặn thao tác với giao diện bên dưới trong lúc mở đầu.
- `lib/main.dart`: bọc luồng khởi động Android; giữ luồng onboarding/trang chủ hiện có.
- Android resources: logo khởi động cùng nền giấy trong cả chế độ sáng/tối; icon Android thích ứng.
- `MainActivity.kt`: bỏ fade mặc định của màn logo hệ thống Android 12+ theo hướng dẫn Flutter để nối với khung hình Flutter.
- Khung hình Flutter đầu tiên được giữ đến khi logo giải mã xong; font và màu thanh trạng thái theo theme ứng dụng sau chuyển cảnh.
- Phiên bản ứng dụng: `1.0.1+2`.

## Tham khảo kỹ thuật

- [Khởi động Android trong Flutter](https://docs.flutter.dev/platform-integration/android/splash-screen)
- [AnimationController](https://api.flutter.dev/flutter/animation/AnimationController-class.html)

Kết quả kiểm thử và bản quay điện thoại nằm trong `build/qa-launch/`.

Đã cài bản release `1.0.1+2` lên vivo V2352A ngày 07/10/2026. Toàn bộ 113 bài kiểm tra đạt. Dữ liệu học được giữ nguyên và quay về từ nền không phát lại màn mở đầu.
