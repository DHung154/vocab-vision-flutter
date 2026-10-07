# Vocab Vision — bản đồ mã nguồn và giao diện

Ánh xạ **mã đang có** với màn hình/chức năng, không phải kế hoạch phát triển. Repo xuất bản app Flutter, runtime asset và kiểm thử; backend/infra, dữ liệu thu thập, kế hoạch, cache và APK không thuộc bản này.

## 1. Cây thư mục

```text
vocab-vision-flutter/
├── lib/
│   ├── main.dart                     Bootstrap, onboarding, theme, màn legacy
│   ├── app/product_shell.dart        Shell 5 tab và các màn sản phẩm
│   ├── features/
│   │   ├── recognition/              Camera/chọn ảnh và luồng nhận diện
│   │   └── space_words/              Minigame Phi đội từ vựng
│   ├── core/
│   │   ├── state/                    AppState: profile/catalog/progress/sync
│   │   ├── storage/                  SQLite, media cache, secure token bridge
│   │   ├── network/                  Client API tài khoản/catalog tùy chọn
│   │   ├── learning/                 Lịch ôn và bộ sưu tập
│   │   ├── text/                     Chuẩn hóa tìm kiếm
│   │   └── theme/                    Màu sáng/tối, nút và chuyển động UI
│   ├── mascot/                      Sprite Mây, phản hồi, overlay góc màn hình
│   ├── catalog_data.dart            Catalog học: 300 từ / 40 chủ đề
│   ├── vocabulary_data.dart         15 nhãn E4 và ánh xạ tiếng Việt
│   ├── learning_screen.dart         Sáu dạng bài luyện và kết quả buổi học
│   ├── inference_service.dart       Dart → Android inference channel
│   ├── detection_model.dart         Chuẩn hóa/kiểm tra payload và box
│   ├── box_geometry.dart            Chuyển tọa độ ảnh → vùng hiển thị
│   ├── result_screen.dart           Kết quả nhận diện và box
│   ├── research_results_data.dart   Snapshot số liệu thực nghiệm có nguồn
│   ├── research_results_screen.dart Bảng thực nghiệm E0/E1/E4
│   └── app_config.dart              Model demo và ngưỡng confidence
├── assets/
│   ├── catalog/e4/                  15 ảnh đồ dùng học tập
│   ├── mascot/may/                  PNG atlas/sprite và JSON animation
│   └── games/space_words/           Map, nền, atlas ship/boss, config, audio/
├── android/app/src/
│   ├── main/assets/e4.onnx          Model E4 offline
│   ├── main/kotlin/.../MainActivity.kt  ONNX, TTS, audio, Keystore
│   ├── main/res/                    Icon launcher và launch theme
│   ├── debug/                       Manifest môi trường phát triển
│   └── release/                     Stub integration_test cho build release
├── ios/, macos/, linux/, windows/, web/   Scaffold nền tảng Flutter
├── test/                            Unit/widget/regression test của app
├── integration_test/                Kiểm thử luồng Android và UI thực
├── pubspec.yaml / pubspec.lock      Dependency và khai báo asset
├── analysis_options.yaml            Lint Dart
├── README.md                        Cách chạy và giới hạn hiện tại
└── APP_MAP.md                       Tài liệu này
```

## 2. Giao diện → chức năng → nơi sửa

Các màn sản phẩm trong [product_shell.dart](lib/app/product_shell.dart) hiện chung thư viện Dart qua `part of '../main.dart'`; Camera cũng là `part`. Đây là cấu trúc thực tế, chưa phải mỗi màn một module độc lập. Màn legacy trong `main.dart` không phải entrypoint chính.

| Màn / vị trí | Chức năng | File/class chính |
|---|---|---|
| Khởi động / onboarding | Nạp local, thiết lập tên và mục tiêu ban đầu | [main.dart](lib/main.dart): `VocabApp`, `OnboardingScreen` |
| Thanh điều hướng | 5 tab, PageView vuốt chuyển; back về Home, tại Home nhấn back hai lần để thoát | [product_shell.dart](lib/app/product_shell.dart): `ProductShell`, `_ProductBottomNavigation` |
| Trang chủ | Mục tiêu ngày, lịch ôn, tiếp tục bài, chọn dạng học, vào Sân chơi của Mây | `_ProductHomePage` |
| Khám phá | Tìm Anh/Việt, lọc chủ đề, danh sách/grid từ, yêu thích, tải catalog tùy chọn | `_ProductVocabularyPage`; [search_normalizer.dart](lib/core/text/search_normalizer.dart) |
| Chủ đề / bộ sưu tập | Học theo chủ đề, tạo/sửa bộ từ cá nhân, mở bài luyện | `TopicDetailPage`, `_ProductCollectionsPage`, `_CollectionDetailPage`; [vocabulary_collection.dart](lib/core/learning/vocabulary_collection.dart) |
| Bài học | Flashcard, Ghép cặp, Điền từ, Nghe & chọn, Dịch từ, Nhìn hình viết từ; phản hồi, draft và attempt | [learning_screen.dart](lib/learning_screen.dart): `LearningScreen`, `LearningMode` |
| Nhận diện | Camera/thư viện ảnh, lựa chọn E4, inference native; không gửi ảnh cho server nhận diện | [camera_screen.dart](lib/features/recognition/camera_screen.dart): `CameraScreen` |
| Kết quả nhận diện | Box, nhãn Anh/Việt, confidence, latency/phạm vi đo; mở từ để học | [result_screen.dart](lib/result_screen.dart), [box_geometry.dart](lib/box_geometry.dart) |
| Tiến độ | Từ đã học, hoạt động tuần, buổi học gần đây, lịch ôn và thành tích | `_ProductProgressPage`, `_ProductAchievementsPage`; [review_scheduler.dart](lib/core/learning/review_scheduler.dart) |
| Kết quả thực nghiệm E4 | Tách seed 0 và mean/sample std 3 seed; E0 cơ sở, E1 InterpIoU cố định, E4 affine + EMA | [research_results_screen.dart](lib/research_results_screen.dart), [research_results_data.dart](lib/research_results_data.dart) |
| Hồ sơ | Người học, tài khoản tùy chọn, cài đặt và nguồn nội dung | `_ProductProfilePage` |
| Cài đặt | Sáng/tối, màu chủ đạo, âm thanh và thiết lập học | `_ProductSettingsPage`; [app_theme.dart](lib/core/theme/app_theme.dart) |
| Nguồn nội dung | Metadata gói từ/media và nguồn lưu trong catalog | `_ProductContentSourcesPage`; [catalog_data.dart](lib/catalog_data.dart) |
| Tài khoản (online) | Đăng ký/đăng nhập, quên mật khẩu, sync, xuất/xóa tài khoản; cần API | `_AccountPage`; [account_api_client.dart](lib/core/network/account_api_client.dart) |
| Quản trị (online, theo quyền) | Báo cáo nội dung, quản lý catalog; không phải server nhúng | `_AdminReportsPage`, `_AdminCatalogPage`, `_CatalogWordEditorDialog` |
| Sân chơi của Mây | Chọn tàu/âm thanh, bản đồ 6 màn, hướng dẫn, vào trận | [space_words_page.dart](lib/features/space_words/space_words_page.dart): `SpaceWordsPage` |
| Trận phi thuyền / boss | Kéo né, chọn/nhặt đạn theo từ, nghe, chiến đấu, pause, kết quả/chơi lại | [space_game_screen.dart](lib/features/space_words/space_game_screen.dart): `SpaceGameScreen` |

Một số tùy chọn như nhắc nhở được lưu trong state; có toggle không đồng nghĩa đã có dịch vụ thông báo nền production.

## 3. Luồng dữ liệu và offline

```text
main → VocabApp → AppState.load → onboarding hoặc ProductShell
UI học/game → recordAttempt → LocalAppStore → tiến độ/lịch ôn/outbox
Catalog starter hoặc pack tải về → CatalogDatabase → Khám phá/bài học/game
Camera/ảnh → InferenceService → Android E4 channel → payload → ResultScreen
```

- [app_state.dart](lib/core/state/app_state.dart): điều phối state, tải catalog, lưu bài/attempt, tài khoản và sync tùy chọn.
- [local_app_store.dart](lib/core/storage/local_app_store.dart): Android SQLite `vocab_app_state.db` lưu profile, settings, progress, collections, draft, review/outbox và game. Import SharedPreferences cũ; desktop/test có fallback SharedPreferences.
- [catalog_database.dart](lib/core/storage/catalog_database.dart): SQLite `vocab_catalog.db`, phiên bản và từ; thay pack bằng transaction. ID catalog độc lập với class ID E4.
- [catalog_media_cache.dart](lib/core/storage/catalog_media_cache.dart): tải/cache media khi có API, hủy tải; cache người dùng không đưa vào Git.
- [secure_token_store.dart](lib/core/storage/secure_token_store.dart): Android Keystore bridge cho session; không đặt token thật trong code.
- [network/](lib/core/network/): HTTP client của app, **không phải backend**. Mặc định không có URL server. Bật bằng `--dart-define=VOCAB_API_BASE_URL=https://...`; cần API riêng cho account/sync/catalog online.

Guest, starter catalog, học, game và E4 chạy local. Nghe cần giọng tiếng Anh offline đã cài trên Android; thiếu giọng thì báo/fallback theo màn, không hứa TTS hoạt động trên mọi máy.

## 4. E4 và kết quả nghiên cứu

Native: [MainActivity.kt](android/app/src/main/kotlin/com/example/giao_dien/MainActivity.kt).

| Channel | Trách nhiệm |
|---|---|
| `vocab_vision/e4` | Hash model, nạp/reuse OrtSession, decode/letterbox ảnh, inference, hoàn tác tọa độ |
| `vocab_vision/tts` | Kiểm tra giọng offline, đọc/dừng từ tiếng Anh |
| `vocab_vision/game_audio` | MediaPlayer nhạc, SoundPool SFX, pause/stop, ducking khi TTS |
| `vocab_vision/secure_storage` | Đọc/ghi/xóa session mã hóa bằng Android Keystore |

Runtime là [e4.onnx](android/app/src/main/assets/e4.onnx), không thay bằng model khác. 15 class ID giữ nguyên trong [vocabulary_data.dart](lib/vocabulary_data.dart); kho học rộng hơn nằm ở `catalog_data.dart`. Ngưỡng demo nằm trong `app_config.dart`; không xóa box chỉ vì giao nhau.

SHA-256 ONNX: `0256115F2E4339527B665C0FD22ED5C4961AAC2539B7889BB9AC297588A61E66`.
Checkpoint nguồn ngoài repo: `E:\KLTN\runs\E4_balanced_seed0\weights\best.pt`; không cần cho build, không bị di chuyển/xóa. Input `[1,3,512,512]`, output `[1,300,6]`.

Số liệu nghiên cứu là snapshot Dart, không đọc CSV lúc mở app. `research_results_data.dart` ghi nguồn `summary.csv` E0/E4, bảng E1 seed 0 và evaluator. Tách seed 0 với mean 3 seed/std mẫu (n−1); chênh lệch chuyển sang **điểm phần trăm**. Không tính AP/mAP cho ảnh không có ground truth. Điểm game/confidence không phải độ chính xác E4; latency demo cần đọc cùng phạm vi đo và thiết bị thực.

## 5. Game và mascot

| File | Nội dung |
|---|---|
| [space_data.dart](lib/features/space_words/space_data.dart) | Validate config, từ theo ID catalog, result/progress/sao và nhạc boss hiếm 1/3 mỗi lần chơi |
| [space_engine.dart](lib/features/space_words/space_engine.dart) | Fixed-step, spawn/move/collision, đạn hướng vị trí tàu lúc bắn, boss/xúc tu/laser và pickup |
| [space_sprites.dart](lib/features/space_words/space_sprites.dart) | Cắt atlas theo rect config, render sprite/nút/panel |
| [game_config.json](assets/games/space_words/game_config.json) | 6 màn, chủ đề/ID từ, vị trí map, sprite rect, physics/audio |
| [may_mascot.dart](lib/mascot/may_mascot.dart) | Cache/render animation; atlas full-body thường, atlas bust cho meme |
| [may_feedback.dart](lib/mascot/may_feedback.dart) | Phản hồi đúng/sai/hoàn thành, hiệu ứng và bubble |
| [may_corner_overlay.dart](lib/mascot/may_corner_overlay.dart) | Overlay góc Home/Khám phá, reduce-motion và tránh route/keyboard |
| [expressions_v3.json](assets/mascot/may/expressions_v3.json) | Mapping clip → atlas/frame/FPS/pose |

Boss đổi ngẫu nhiên nghe–chọn hoặc pickup theo phase. Đạn rơi từ trên vùng chơi, cách tối thiểu 4 giây và không chồng wave đang rơi; nhặt đúng tích lũy hỏa lực. Chọn sai khóa tất cả đáp án 5 giây. Sao lấy kết quả tốt nhất khi chơi lại, không giữ mãi lần đầu. Pause/ra nền dừng gameplay/audio; back về map. Regression test nằm trong `test/space_words_test.dart`.

## 6. Chạy và kiểm thử

Xem [README.md](README.md) để clone/build. Cấu hình hiện tại: Flutter 3.38.7, Dart 3.10+, Gradle 9.1.0, AGP 9.0.1, Kotlin 2.3.20, ONNX Runtime Android 1.23.2. Không có bước huấn luyện.

```sh
flutter pub get
flutter analyze
flutter test
flutter run
flutter build apk --debug --target-platform android-arm64
```

- `test/`: state/storage, catalog/API client với dữ liệu test, search/review, box/payload, UI/theme/accessibility, mascot và game.
- `integration_test/`: navigation/learning, catalog offline, E4 native, Camera; `visual_qa_hold_test.dart` giữ Home để quan sát UI.
- Ví dụ `flutter test integration_test/e4_offline_test.dart -d <device-id>` cần Android/model bundled. Integration test có thể lưu attempt/trạng thái trong app test: dùng thiết bị/profile test. Unit test không chứng minh luồng thiết bị thật.
- Android native là nền tảng triển khai. Scaffold iOS/desktop không đồng nghĩa ONNX/TTS/game audio/Keystore đã port; web chưa hỗ trợ vì `dart:io`.
- Release đang ký debug cho demo; cần khóa riêng trước khi phân phối. Không commit keystore hay SDK path cá nhân.

## Nguồn asset và phạm vi sử dụng

- 15 ảnh E4: **school-objects v1, provided by a Roboflow user**, nguồn `https://universe.roboflow.com/schoolobjectsv1/school-objects-8qfiv`, catalog ghi **CC BY 4.0** (`https://creativecommons.org/licenses/by/4.0/`). Ảnh chọn/cắt cho demo; human publication review còn chờ, không tính là 1.000 media production.
- Art game/atlas/map/Mây được tạo/cung cấp trong quá trình làm demo. Không gán license mở cho toàn repo khi chưa xác minh từng nguồn.
- Audio do chủ dự án cung cấp, tên nguồn ở bảng dưới. Có MP3/WAV không tự chứng minh quyền tái phân phối, đặc biệt bản remix. Không tải/rip YouTube. Cần kiểm tra license/attribution trước khi phát hành công khai/app store.

| Runtime `assets/games/space_words/audio/` | File gốc / nguồn cung cấp |
|---|---|
| `music_game.mp3` | `xtremefreddy-game-music-loop-19-153393.mp3` — Pixabay, Game Music Loop 19 |
| `music_boss.mp3` | `alperomeresin-the-final-boss-battle-158700.mp3` — Pixabay, The Final Boss Battle |
| `music_boss_rare.mp3` | `deck1-megalovania-trap-remix-292774.mp3` — remix chủ dự án cung cấp |
| `laser.mp3` | `dragon-studio-laser-sfx-570449.mp3` |
| `boss_explosion.wav` | `mixkit-8-bit-bomb-explosion-2811.wav` |
| `explosion.wav` | `mixkit-arcade-game-explosion-1699.wav` |
| `win.wav` | `mixkit-unlock-new-item-game-notification-254.wav` |
| `pickup.wav` | `mixkit-retro-game-notification-212.wav` |
| `game_over.wav` | `mixkit-arcade-retro-game-over-213.wav` |

Tài liệu không khẳng định full production runtime, sync hai thiết bị, TalkBack hoặc mọi UI đã được kiểm chứng trên thiết bị thật; cần QA độc lập.
