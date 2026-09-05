# KẾ HOẠCH SỬA VÀ NÂNG CẤP VOCAB APP VIP/PRO

> Tài liệu triển khai dành cho model Luna. Đọc toàn bộ tài liệu trước khi sửa code.
> Thực hiện đúng thứ tự phase, không làm đồng thời nhiều phase và không bỏ qua bước kiểm tra.

## 1. Mục tiêu sản phẩm

Biến project Flutter hiện tại từ giao diện demo thành ứng dụng học 15 từ vựng
đồ dùng học tập có thể sử dụng thật, gồm:

- Giao diện responsive, không bị bottom navigation che nội dung.
- Danh sách và chi tiết từ vựng Anh–Việt.
- Bốn chế độ học hoạt động thật.
- Ôn tập theo lịch và lưu tiến độ trên thiết bị.
- Camera/chọn ảnh nhận diện vật thể qua API hiện có.
- Thành tích, streak, XP và hồ sơ lấy từ dữ liệu thật.
- Nền tảng đủ sạch để bổ sung tài khoản, đồng bộ cloud và gói Pro sau này.

Không triển khai thanh toán giả, leaderboard giả hoặc dữ liệu AI giả.

## 2. Hiện trạng cần lưu ý

- Phần lớn UI đang nằm trong `lib/main.dart` và dùng dữ liệu hard-code.
- Khung app đang cố định `width: 375`, `height: 812`.
- Bottom navigation dùng `Stack` + `Positioned(bottom: 0)`, có thể che nội dung.
- Danh sách từ, tiến độ, XP, streak và thành tích đang là dữ liệu minh họa.
- Luồng nhận diện đã có các file:
  - `lib/app_config.dart`
  - `lib/detection_model.dart`
  - `lib/inference_service.dart`
  - `lib/result_screen.dart`
- API nhận diện dùng HTTP và IP LAN, cần giữ khả năng cấu hình.
- Dependencies hiện có: `image_picker`, `http`.

## 3. Nguyên tắc triển khai bắt buộc

1. Giữ nguyên bảng màu và tinh thần giao diện hiện tại.
2. Không viết lại toàn bộ project trong một lần.
3. Mỗi phase phải build/test thành công trước khi sang phase tiếp theo.
4. Không để dữ liệu nghiệp vụ mới nằm trực tiếp trong widget.
5. Không thêm state-management framework ở giai đoạn đầu; dùng
   `ChangeNotifier`, `ValueNotifier` hoặc state cục bộ của Flutter.
6. Chỉ thêm dependency khi standard library/Flutter SDK không đáp ứng được.
7. Không đổi contract JSON của API nhận diện hiện tại.
8. Không xóa test cũ để làm test pass.
9. Không hiển thị kết quả nhận diện giả khi API lỗi hoặc không có detection.
10. Mọi text người dùng nhìn thấy phải bằng tiếng Việt rõ ràng.

## 4. Thứ tự triển khai tổng thể

```text
Phase 0: Baseline và bảo vệ hành vi hiện tại
    ↓
Phase 1: Sửa layout responsive và navigation
    ↓
Phase 2: Tách cấu trúc code tối thiểu
    ↓
Phase 3: Dữ liệu từ vựng + lưu tiến độ offline
    ↓
Phase 4: Bốn chế độ học hoạt động thật
    ↓
Phase 5: Ôn tập thông minh + streak + XP + thành tích
    ↓
Phase 6: Camera AI thành một luồng học hoàn chỉnh
    ↓
Phase 7: Nâng cấp trải nghiệm Pro
    ↓
Phase 8: Kiểm thử, hiệu năng, bảo mật và phát hành
```

---

## PHASE 0 — Baseline và bảo vệ hành vi hiện tại

### Công việc

1. Chạy và ghi nhận kết quả:

   ```powershell
   flutter pub get
   dart format --output=none --set-exit-if-changed lib test
   flutter analyze
   flutter test
   flutter build apk --debug
   ```

2. Nếu test hiện tại fail, xác định rõ test lỗi do code hay do test đã cũ.
3. Chụp/ghi nhận các màn hình hiện có: Trang chủ, Từ vựng, Camera,
   Thành tích, Hồ sơ, Cài đặt và Bản đồ học tập.
4. Không thay đổi logic ở phase này, ngoại trừ lỗi làm project không build.

### Hoàn thành khi

- Có baseline rõ ràng.
- APK debug build được.
- Không có thay đổi giao diện ngoài ý muốn.

---

## PHASE 1 — Sửa layout responsive và navigation

### Vấn đề gốc

`Shell` đang đặt màn hình và bottom navigation chung trong `Stack`. Navigation
được đặt tuyệt đối ở đáy nên che nội dung. Container 375×812 làm app không thích
ứng tốt với màn hình khác nhau.

### Công việc

1. Bỏ chiều rộng/chiều cao cố định của app trên điện thoại.
2. Dùng `SafeArea` để tránh status bar, camera cutout và gesture bar.
3. Đưa bottom navigation vào vùng layout riêng của `Scaffold` hoặc bố cục
   `Column` gồm `Expanded(body)` và navigation.
4. Nếu cần giữ giao diện mô phỏng điện thoại trên desktop/web:
   - Chỉ dùng `ConstrainedBox(maxWidth: 480)`.
   - Không cố định chiều cao.
5. Mỗi màn hình cuộn phải có bottom padding đúng bằng navigation + safe area.
6. Grid chế độ học:
   - Điện thoại nhỏ: 2 cột nếu đủ chỗ, 1 cột nếu text bị chật.
   - Tablet/web: giới hạn chiều rộng nội dung, không kéo card quá rộng.
7. Kiểm tra `textScaleFactor` lớn để không overflow chữ.
8. Giữ nút Camera nổi ở giữa và vùng bấm tối thiểu 48×48.

### Test cần có

- Widget test ở viewport 320×568: không có overflow exception.
- Widget test ở viewport 375×812: navigation không che card cuối.
- Widget test ở viewport 800×1200: nội dung được giới hạn chiều rộng hợp lý.
- Cuộn đến cuối HomeScreen thấy đủ cả bốn chế độ học.

### Hoàn thành khi

- Không còn sọc vàng/đen overflow.
- Card cuối không bị navigation che.
- App dùng được trên màn hình nhỏ, emulator hiện tại và tablet.

---

## PHASE 2 — Tách cấu trúc code tối thiểu

Không tạo Clean Architecture nhiều tầng. Chỉ tách theo tính năng để
`main.dart` không tiếp tục phình to.

### Cấu trúc đích

```text
lib/
  main.dart
  app.dart
  core/
    app_colors.dart
    app_theme.dart
    app_config.dart
  models/
    vocabulary_word.dart
    learning_progress.dart
    detection.dart
  data/
    vocabulary_seed.dart
    progress_store.dart
  services/
    inference_service.dart
  screens/
    home_screen.dart
    vocabulary_screen.dart
    word_detail_screen.dart
    camera_screen.dart
    result_screen.dart
    achievements_screen.dart
    profile_screen.dart
    settings_screen.dart
    learning_map_screen.dart
  learning/
    flashcard_screen.dart
    matching_screen.dart
    fill_word_screen.dart
    listening_screen.dart
  widgets/
    bottom_cutout_nav.dart
```

### Quy tắc

- `main.dart` chỉ gọi `runApp`.
- Không đổi giao diện trong lúc di chuyển code.
- Dùng import package nhất quán.
- Chỉ tạo file khi nó có trách nhiệm rõ ràng.
- Model detection hiện có được di chuyển, không viết lại không cần thiết.

### Hoàn thành khi

- `main.dart` ngắn và không chứa screen lớn.
- Toàn bộ test cũ vẫn pass.
- Không có duplicate model, màu sắc hoặc map dịch Anh–Việt.

---

## PHASE 3 — Dữ liệu từ vựng và lưu tiến độ offline

### Model `VocabularyWord`

Các trường tối thiểu:

```text
id
english
vietnamese
emoji hoặc assetKey
category
exampleEnglish
exampleVietnamese
pronunciation
difficulty
```

Dùng đúng 15 nhãn dataset trong `vocabularyVi`. Tạo một nguồn dữ liệu duy nhất;
mọi màn hình phải đọc từ nguồn này.

### Model tiến độ

Mỗi từ lưu:

```text
wordId
correctCount
wrongCount
mastery (0..1)
reviewStage
nextReviewAt
lastReviewedAt
isFavorite
```

Tiến độ người dùng:

```text
xp
currentStreak
longestStreak
lastStudyDate
totalSessions
totalCorrectAnswers
```

### Lưu trữ

Ưu tiên một dependency nhỏ hỗ trợ Android/iOS/web như `shared_preferences` cho
giai đoạn 15 từ. Lưu JSON có version schema. Không dùng SQLite/Drift khi dữ liệu
chỉ có 15 từ và một hồ sơ cục bộ.

`ProgressStore` phải có:

- `load()`
- `save()`
- `reset()`
- fallback an toàn khi JSON hỏng
- migration theo `schemaVersion`

### Từ vựng

- Danh sách 15 từ thật.
- Tìm kiếm theo tiếng Anh và tiếng Việt.
- Lọc: tất cả, chưa học, đang học, đã thuộc, yêu thích.
- Mở trang chi tiết từ.
- Chi tiết có Anh–Việt, phát âm dạng text, ví dụ và trạng thái học.
- Không tải ảnh internet ngẫu nhiên; tiếp tục dùng emoji cho đến khi có bộ asset
  thống nhất.

### Hoàn thành khi

- Tắt/mở app không mất tiến độ.
- Không còn số XP, streak hoặc tiến độ hard-code.
- Reset dữ liệu hoạt động và có xác nhận.

---

## PHASE 4 — Bốn chế độ học hoạt động thật

Tạo một `LearningSession` dùng chung để tránh mỗi trò tự tính điểm theo cách
khác nhau.

### Luật session chung

- Input: danh sách từ, loại bài học, số câu.
- Mặc định 10 câu hoặc toàn bộ từ nếu ít hơn 10.
- Không lặp cùng đáp án liên tiếp nếu còn lựa chọn khác.
- Mỗi câu chỉ được chấm một lần.
- Kết thúc trả về: số đúng, số sai, XP nhận được, danh sách từ cần ôn lại.
- Không cộng XP khi người dùng bấm lại hoặc quay lại màn hình kết quả.

### 4.1 Flashcard

- Hiển thị mặt trước tiếng Anh/emoji.
- Chạm để lật xem tiếng Việt và ví dụ.
- Hai nút `Chưa nhớ` và `Đã nhớ`.
- Có tiến trình câu hiện tại/tổng số.

### 4.2 Ghép hình

- Hiển thị 3–4 emoji/thẻ và 3–4 từ.
- Người dùng chọn một hình rồi chọn từ tương ứng.
- Phản hồi đúng/sai rõ ràng.
- Mobile không bắt buộc kéo thả thật; cơ chế chọn-cặp ổn định được ưu tiên.

### 4.3 Điền từ

- Cho tiếng Việt/emoji và từ tiếng Anh bị khuyết.
- Chấp nhận không phân biệt hoa thường và bỏ khoảng trắng đầu/cuối.
- Có gợi ý từng ký tự, nhưng dùng gợi ý làm giảm XP câu đó.
- Hiện đáp án đúng sau khi trả lời sai.

### 4.4 Nghe và chọn

- Dùng text-to-speech nếu thêm được một package ổn định.
- Phát từ tiếng Anh, người dùng chọn đúng nghĩa/hình.
- Có nút nghe lại.
- Nếu TTS lỗi, hiển thị thông báo và cho phép bỏ qua câu; không crash.

### Màn hình kết quả session

- Điểm số và phần trăm đúng.
- XP nhận được.
- Danh sách từ trả lời sai.
- Nút `Ôn lại từ sai` và `Về trang chủ`.

### Test cần có

- Một câu không thể cộng điểm hai lần.
- Chuẩn hóa đáp án điền từ.
- Session kết thúc đúng số câu.
- Từ sai được cập nhật tiến độ.

---

## PHASE 5 — Ôn tập thông minh, streak, XP và thành tích

### Lịch ôn tập đơn giản

Không triển khai thuật toán quá phức tạp. Dùng các mốc:

```text
Sai          → ôn lại trong session hoặc ngày hiện tại
Stage 0 đúng → +1 ngày
Stage 1 đúng → +3 ngày
Stage 2 đúng → +7 ngày
Stage 3 đúng → +14 ngày
Stage 4 đúng → +30 ngày
```

- Trả lời sai giảm stage một cấp, tối thiểu 0.
- `Ôn hôm nay` lấy các từ có `nextReviewAt <= hiện tại`.
- Nếu không có từ đến hạn, gợi ý học từ chưa học.

### XP

Quy tắc duy nhất:

```text
Đúng lần đầu: +10 XP
Dùng gợi ý: +5 XP
Sai: +0 XP
Hoàn thành session: +20 XP
Nhận diện camera thành công và lưu từ: +5 XP
```

### Streak

- Một ngày được tính khi hoàn thành ít nhất một session.
- Học cùng ngày không tăng thêm streak.
- Bỏ một ngày làm streak về 1 khi học lại.
- Dùng ngày địa phương; viết test quanh mốc nửa đêm.

### Thành tích thật

- Từ đầu tiên.
- Hoàn thành session đầu tiên.
- 7 ngày liên tiếp.
- Đạt 100, 500 và 1000 XP.
- Thuộc 5, 10 và 15 từ.
- Nhận diện đủ 5 loại vật thể khác nhau.

Không mở khóa thành tích bằng dữ liệu hard-code.

### Trang chủ

- Tiến độ hôm nay lấy từ số câu đã học/mục tiêu ngày.
- `Ôn hôm nay` lấy từ lịch ôn thật.
- Header lấy XP và streak thật.
- Chạm nhanh vào Từ vựng/Ôn tập/Thành tích phải chuyển đúng tab hoặc màn hình.

---

## PHASE 6 — Camera AI thành luồng học hoàn chỉnh

Giữ contract và xử lý lỗi hiện có trong `InferenceService`.

### Luồng chuẩn

```text
Camera hoặc thư viện
→ xem trước
→ gửi API
→ kết quả bounding box
→ chọn một detection
→ xem từ vựng Anh–Việt
→ lưu vào danh sách vừa khám phá
→ học nhanh bằng flashcard
```

### Công việc

1. URL API không được hard-code theo một IP production duy nhất.
   - Cho phép truyền bằng `--dart-define=INFERENCE_URL=...`.
   - Giữ fallback development có cảnh báo rõ ràng.
2. Kiểm tra MIME/extension và giới hạn kích thước ảnh trước khi upload.
3. Có loading, retry và chống gửi request hai lần.
4. Hủy camera/thư viện không được xem là lỗi.
5. API lỗi, timeout, JSON lỗi và detection rỗng phải có UI riêng.
6. Bounding box phải khớp tỉ lệ khi ảnh dùng `BoxFit.contain`.
7. Detection lạ dùng `Chưa có bản dịch`, không crash.
8. Lưu lịch sử tối đa 50 lần nhận diện trên thiết bị:
   - thời gian
   - nhãn
   - confidence
   - không lưu ảnh vĩnh viễn mặc định
9. Từ nhận diện được có thể mở trang chi tiết hoặc bắt đầu flashcard.

### Bảo mật

- Production phải dùng HTTPS.
- Không log toàn bộ ảnh hoặc dữ liệu riêng tư.
- Không yêu cầu microphone/vị trí.
- Nêu rõ ảnh được gửi tới máy chủ nhận diện trước lần dùng đầu tiên.

### Hoàn thành khi

- Camera không còn là tính năng tách rời mà cập nhật tiến độ học thật.
- Không có nhãn/kết quả mô phỏng trong luồng thật.
- Test parse JSON và test bounding box pass.

---

## PHASE 7 — Trải nghiệm VIP/PRO

Chỉ triển khai sau khi Phase 0–6 ổn định. Trước mắt xây feature gating và màn
hình giới thiệu; thanh toán thật là phase riêng cần tài khoản store.

### Phân chia Free và Pro đề xuất

| Tính năng | Free | Pro |
|---|---:|---:|
| 15 từ vựng cơ bản | Có | Có |
| 4 chế độ học | Có | Có |
| Ôn tập thông minh | Có | Có |
| Camera AI | 5 lượt/ngày | Không giới hạn hợp lý |
| Mục tiêu học tùy chỉnh | 1 mục tiêu | Nhiều mục tiêu |
| Thống kê 7 ngày | Có | Có |
| Thống kê 30/90 ngày | Không | Có |
| Bộ từ mở rộng | Không | Có |
| Xuất/nhập tiến độ | Không | Có |
| Quảng cáo | Không thêm ở MVP | Không |

### Tính năng Pro nên có

1. Dashboard thống kê:
   - thời gian học
   - độ chính xác
   - từ mạnh/yếu
   - streak
   - biểu đồ 7/30/90 ngày
2. Mục tiêu cá nhân: số phút, số câu hoặc số từ mỗi ngày.
3. Bộ từ theo chủ đề: lớp học, gia đình, đồ ăn, động vật.
4. Chế độ luyện từ yếu tự động.
5. Backup/sync nhiều thiết bị khi đã có backend.
6. Nhắc lịch học theo giờ người dùng chọn.

### Chưa làm ngay

- Chatbot AI tự do.
- Mạng xã hội hoặc nhắn tin.
- Leaderboard online.
- Video recognition thời gian thực.
- Marketplace nội dung.

Các tính năng này tốn backend, moderation hoặc chi phí inference nhưng chưa
tăng trực tiếp chất lượng học của phiên bản hiện tại.

### Thanh toán thật

Chỉ triển khai khi có:

- Google Play Console/Apple Developer account.
- Product ID chính thức.
- Chính sách quyền riêng tư và điều khoản sử dụng.
- Backend hoặc cơ chế xác minh entitlement phù hợp.
- Restore purchases và test sandbox.

Không dùng boolean local đơn giản làm quyền Pro trong production.

---

## PHASE 8 — Chất lượng và phát hành

### Kiểm thử

- Unit test model, lưu dữ liệu, XP, streak và lịch ôn.
- Widget test navigation, responsive layout, learning session và trạng thái lỗi.
- Integration test luồng:
  - mở app → học flashcard → nhận XP → mở lại app vẫn còn tiến độ
  - chọn ảnh → API mock → kết quả → lưu từ
- Test offline và server không phản hồi.

### Accessibility

- Tap target tối thiểu 48×48.
- Màu chữ đạt độ tương phản đọc được.
- Có semantic label cho icon không có chữ.
- Không phụ thuộc duy nhất vào màu để báo đúng/sai.
- Hỗ trợ text scale ít nhất 1.3.

### Hiệu năng

- Không rebuild toàn bộ Shell khi chỉ thay progress nhỏ.
- Không decode ảnh camera nhiều lần.
- Resize/compress ảnh trước upload nếu ảnh quá lớn.
- Danh sách dùng builder khi dữ liệu mở rộng.

### Release

- Đổi package/application ID khỏi `com.example`.
- Tên app, icon và splash screen chính thức.
- Version/build number đúng.
- Cấu hình release signing.
- Tắt log debug và kiểm tra URL production.
- `flutter analyze`, `flutter test`, APK/AAB release đều pass.

---

## 5. Thứ tự commit đề xuất

Mỗi commit phải độc lập và build được:

1. `test: capture current app baseline`
2. `fix: make shell and bottom navigation responsive`
3. `refactor: split monolithic main file by feature`
4. `feat: add vocabulary domain model and local seed data`
5. `feat: persist learning progress locally`
6. `feat: implement flashcard learning session`
7. `feat: implement matching and fill-word modes`
8. `feat: implement listening mode`
9. `feat: add spaced review xp and streak logic`
10. `feat: drive home and achievements from real progress`
11. `feat: connect camera detections to vocabulary learning`
12. `test: cover core learning and camera flows`
13. `chore: prepare production release configuration`

Không gom toàn bộ phase thành một commit khổng lồ.

## 6. Checklist cho Luna sau mỗi phase

1. Liệt kê file đã sửa/tạo.
2. Chạy format trên đúng file đã chạm.
3. Chạy `flutter analyze`.
4. Chạy `flutter test`.
5. Nếu thay Android config, chạy `flutter build apk --debug`.
6. Báo rõ test nào pass/fail; không nói “đã xong” khi chưa chạy kiểm tra.
7. Không tự sửa ngoài phạm vi phase đang làm.
8. Nếu phát hiện dữ liệu người dùng hoặc thay đổi chưa liên quan, phải giữ nguyên.

## 7. Definition of Done toàn dự án

Dự án chỉ được xem là hoàn thành khi:

- UI không overflow và không bị navigation che ở các kích thước mục tiêu.
- 15 từ có một nguồn dữ liệu duy nhất.
- Cả bốn chế độ học hoạt động với dữ liệu thật.
- Tiến độ, XP, streak và thành tích được lưu và tính đúng.
- Ôn hôm nay lấy theo lịch ôn, không hard-code.
- Camera dùng API thật, xử lý đầy đủ loading/error/empty result.
- Kết quả camera có thể chuyển thành hoạt động học.
- Không mất tiến độ sau khi khởi động lại app.
- Không có entitlement Pro giả trong bản production.
- `dart format`, `flutter analyze`, `flutter test` và build release đều pass.

## 8. Prompt ngắn để giao việc cho Luna

Sử dụng prompt sau cùng với file kế hoạch này:

```text
Đọc toàn bộ KE_HOACH_NANG_CAP_VIP_PRO_CHO_LUNA.md và code hiện tại trước khi
thay đổi. Chỉ triển khai phase được chỉ định, theo đúng thứ tự công việc và tiêu
chí hoàn thành. Giữ nguyên thay đổi không liên quan của người dùng. Không thêm
kiến trúc hoặc dependency ngoài kế hoạch nếu chưa chứng minh cần thiết. Sau khi
code, chạy format, flutter analyze, flutter test và build phù hợp; báo chính xác
kết quả cùng danh sách file đã thay đổi.
```

Prompt bắt đầu đề xuất:

```text
Triển khai Phase 0 và Phase 1 trong
KE_HOACH_NANG_CAP_VIP_PRO_CHO_LUNA.md. Dừng lại sau khi Phase 1 đạt toàn bộ tiêu
chí hoàn thành; chưa làm Phase 2 trở đi.
```
